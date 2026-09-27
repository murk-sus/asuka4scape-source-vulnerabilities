import Foundation

private let injectLogCallback: @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?) -> Void = { _, msg in
    guard let msg = msg else { return }
    CarrierLabState.shared.appendLog("[ffi] " + String(cString: msg))
}

final class CarrierLabBridge: @unchecked Sendable {
    static let shared = CarrierLabBridge()

    enum ProbeState {
        case ok
        case noVPN
        case noPairing
        case pairingInvalid
        case ffiFailed(String)
    }

    struct ProbeResult {
        let state: ProbeState
        let detail: String
        var ok: Bool { if case .ok = state { return true }; return false }
        var message: String {
            switch state {
            case .ok: return "ready"
            case .noVPN: return "No loopback VPN. Enable LocalDevVPN or SideStore WireGuard."
            case .noPairing: return "No pairing file. Open Tools / Airlift and run Start Pairing."
            case .pairingInvalid: return detail
            case .ffiFailed(let s): return s
            }
        }
    }

    static let carrierUserRoot = "/var/mobile/Library/Carrier Bundles"
    static let carrierRoot = "/var/mobile/Library/Carrier Bundles/iPhone"

    static let defaultSlots = ["Carrier1Bundle.bundle", "Operator1Bundle.bundle"]

    func findPairingFile() -> String? {
        let fm = FileManager.default
        let canonical = PairingController.pairingFilePath()
        if fm.fileExists(atPath: canonical) {
            let size = (try? fm.attributesOfItem(atPath: canonical)[.size] as? Int) ?? 0
            if size > 0 { return canonical }
        }
        if let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
            let candidates = [
                docs.appendingPathComponent("natsuk1_pairing.plist").path,
                docs.appendingPathComponent("ALTPairingFile.mobiledevicepairing").path,
            ]
            for c in candidates {
                if fm.fileExists(atPath: c) {
                    let size = (try? fm.attributesOfItem(atPath: c)[.size] as? Int) ?? 0
                    if size > 0 { return c }
                }
            }
        }
        return nil
    }

    func validatePairingFile(_ path: String) -> (Bool, String) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return (false, "missing") }
        let size = (try? fm.attributesOfItem(atPath: path)[.size] as? Int) ?? 0
        if size < 50 { return (false, "Pairing file too small (\(size) bytes).") }
        let kind = PairingFileKind.of(path: path)
        if !kind.isUsable {
            return (false, "Pairing file is not a plist (\(size) bytes).")
        }
        if !kind.hasLockdown {
            return (false, "Pairing file has the RPPairing half but no classic lockdown record "
                + "(HostCertificate / HostPrivateKey / DeviceCertificate). Airlift's Lockdown "
                + "fallback on port 62078 will fail with \"missing field DeviceCertificate\". "
                + "Open Tools / Airlift, delete the pairing file and pair again so the lockdown "
                + "record is issued.")
        }
        return (true, "Pairing ok (\(size) bytes)")
    }

    func probe() -> ProbeResult {
        if !NetworkStatus.loopbackVPNUp() { return ProbeResult(state: .noVPN, detail: "no loopback VPN") }
        guard let pairing = findPairingFile() else {
            return ProbeResult(state: .noPairing, detail: "missing")
        }
        let (ok, msg) = validatePairingFile(pairing)
        if !ok { return ProbeResult(state: .pairingInvalid, detail: msg) }
        return ProbeResult(state: .ok, detail: msg)
    }

    struct TreeSummary {
        let files: Int
        let bytes: Int
        let names: [String]
        var isEmpty: Bool { files == 0 }
    }

    func localTreeSummary(_ path: String) -> TreeSummary {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            return TreeSummary(files: 0, bytes: 0, names: [])
        }
        var files = 0
        var bytes = 0
        var names: [String] = []
        let root = URL(fileURLWithPath: path)
        guard let walker = fm.enumerator(at: root, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) else {
            return TreeSummary(files: 0, bytes: 0, names: [])
        }
        for case let url as URL in walker {
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values?.isRegularFile == true else { continue }
            files += 1
            bytes += values?.fileSize ?? 0
            if names.count < 12 {
                names.append(url.path.replacingOccurrences(of: path + "/", with: ""))
            }
        }
        return TreeSummary(files: files, bytes: bytes, names: names)
    }

    func injectFolder(sourceFolder: String,
                      targetParent: String,
                      destName: String) -> ProbeResult {
        guard let pairing = findPairingFile() else {
            return ProbeResult(state: .noPairing, detail: "no pairing path")
        }
        let summary = localTreeSummary(sourceFolder)
        if summary.isEmpty {
            return ProbeResult(state: .ffiFailed("no files in directory: \(sourceFolder) is empty or is not a directory"),
                               detail: "no files in directory")
        }
        var outError: UnsafeMutablePointer<CChar>? = nil
        var rc: Int32 = -1
        pairing.withCString { pc in
            sourceFolder.withCString { sc in
                targetParent.withCString { tc in
                    destName.withCString { nc in
                        rc = al_exploit_inject_folder(pc, sc, tc, nc, injectLogCallback, nil, &outError)
                    }
                }
            }
        }
        let errMsg = outError.flatMap { String(cString: $0) } ?? ""
        if let p = outError { al_string_free(p) }
        if rc != 0 {
            return ProbeResult(state: .ffiFailed(errMsg.isEmpty ? "inject rc=\(rc)" : errMsg), detail: errMsg)
        }
        return ProbeResult(state: .ok, detail: "injected \(summary.files) file(s)")
    }
}
