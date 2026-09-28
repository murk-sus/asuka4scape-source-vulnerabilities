import Foundation

extension CarrierLabBridge {
    static let carrierUserRoot = "/var/mobile/Library/Carrier Bundles"
    static let carrierRoot = "/var/mobile/Library/Carrier Bundles/iPhone"
    static let defaultSlots = ["Carrier1Bundle.bundle", "Operator1Bundle.bundle"]
}

extension PairingGenerator {
    static func cancelMinting() {
        LockdownPair.requestCancel()
        PairingController.shared.pairingStatus = "Cancelling..."
    }
}

final class CarrierLabSlots: @unchecked Sendable {
    static let shared = CarrierLabSlots()
    private init() {}

    struct Outcome {
        let ok: Bool
        let message: String
        let slots: [String]
    }

    func pairingPath() -> String? {
        let fm = FileManager.default
        let canonical = PairingController.pairingFilePath()
        if fm.fileExists(atPath: canonical) { return canonical }
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        for name in ["natsuk1_pairing.plist", "ALTPairingFile.mobiledevicepairing"] {
            let candidate = docs.appendingPathComponent(name).path
            if fm.fileExists(atPath: candidate) { return candidate }
        }
        return nil
    }

    func sourcePath() -> String {
        Bundle.main.bundleURL.appendingPathComponent("CarrierAssets/CarrierLab.bundle").path
    }

    private func fileCount(_ path: String) -> Int {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else { return 0 }
        guard let walker = fm.enumerator(at: URL(fileURLWithPath: path),
                                        includingPropertiesForKeys: [.isRegularFileKey]) else { return 0 }
        var files = 0
        for case let url as URL in walker {
            if (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true { files += 1 }
        }
        return files
    }

    func status() -> String {
        guard let path = pairingPath() else { return "no pairing file, pair from Tools / Airlift" }
        let kind = PairingFileKind.of(path: path)
        if kind.hasLockdown { return "ready" }
        if kind.hasRemotePairing { return "needs a lockdown record, press Pair Lockdown Record" }
        return "pairing file is not an RPPairing plist"
    }

    @discardableResult
    func ensureLockdownRecord() -> String? {
        guard let path = pairingPath() else { return "No pairing file. Pair from Tools / Airlift first." }
        let kind = PairingFileKind.of(path: path)
        if kind.hasLockdown { return nil }
        guard kind.isUsable else { return "Pairing file is not a plist." }
        guard kind.hasRemotePairing else {
            return "No public_key/private_key in the pairing file, pair again from Airlift."
        }

        PairingController.shared.pairingStatus = "Minting lockdown record, tap Trust on the iPhone..."
        do {
            let record = try LockdownPair.mintRecord(
                hosts: LockdownPair.candidateHosts(),
                hostID: CompositePairingFile.hostID,
                systemBUID: CompositePairingFile.systemBUID,
                hostName: "natsuk1")
            let rpp = try Data(contentsOf: URL(fileURLWithPath: path))
            let merged = try CompositePairingFile.merge(lockdown: record, rpPairing: rpp, udid: kind.udid)
            CompositePairingFile.storeLockdownRecord(record, forUDID: kind.udid)
            let canonical = PairingController.syncCanonicalPairingFile(from: path)
            try merged.write(to: URL(fileURLWithPath: canonical), options: .atomic)
            guard PairingFileKind.of(path: canonical).hasLockdown else {
                return "Minted \(record.count) bytes but the merged file still has no DeviceCertificate."
            }
            PairingController.shared.pairingStatus = "Lockdown record stored"
            return nil
        } catch {
            let text = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            PairingController.shared.pairingStatus = text
            return text
        }
    }

    private func inject(source: String, parent: String, name: String) -> Bool {
        guard let pairing = pairingPath(), fileCount(source) > 0 else { return false }
        var rc: Int32 = -1
        pairing.withCString { pc in
            source.withCString { sc in
                parent.withCString { tc in
                    name.withCString { nc in
                        rc = al_exploit_inject_folder(pc, sc, tc, nc, nil, nil, nil)
                    }
                }
            }
        }
        return rc == 0
    }

    func install(slots: [String]) -> Outcome {
        if let problem = ensureLockdownRecord() {
            return Outcome(ok: false, message: problem, slots: [])
        }
        let source = sourcePath()
        guard fileCount(source) > 0 else {
            return Outcome(ok: false, message: "no files in directory: \(source)", slots: [])
        }
        var written: [String] = []
        for slot in slots where inject(source: source, parent: CarrierLabBridge.carrierUserRoot, name: slot) {
            written.append(slot)
        }
        guard written.count == slots.count else {
            return Outcome(ok: false, message: "injected \(written.count)/\(slots.count): \(written.joined(separator: ","))", slots: written)
        }
        let trigger = Bundle.main.bundleURL.appendingPathComponent("CarrierAssets/Docomo_jp.bundle").path
        if fileCount(trigger) > 0 {
            _ = inject(source: trigger, parent: CarrierLabBridge.carrierRoot, name: "Docomo_jp.bundle")
        }
        return Outcome(ok: true, message: "written into \(written.joined(separator: ","))", slots: written)
    }
}
