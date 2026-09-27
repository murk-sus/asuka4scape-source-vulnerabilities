import Foundation

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

    private let carrierRoot = "/var/mobile/Library/Carrier Bundles/iPhone"
    private let bundleLinks = "/var/mobile/Library/Carrier Bundles/BundleLinks"

    func carrierRootPath() -> String { carrierRoot }
    func bundleLinksPath() -> String { bundleLinks }

    func findPairingFile() -> String? {
        let fm = FileManager.default
        let canonical = PairingController.pairingFilePath()
        if fm.fileExists(atPath: canonical) {
            let size = (try? fm.attributesOfItem(atPath: canonical)[.size] as? Int) ?? 0
            if size > 0 { return canonical }
        }
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let candidates = [
            docs.appendingPathComponent("natsuk1_pairing.plist").path,
            docs.appendingPathComponent("ALTPairingFile.mobiledevicepairing").path
        ]
        for c in candidates {
            if fm.fileExists(atPath: c) {
                let size = (try? fm.attributesOfItem(atPath: c)[.size] as? Int) ?? 0
                if size > 0 { return c }
            }
        }
        return nil
    }

    private func validatePairingFile(_ path: String) -> (Bool, String) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return (false, "missing") }
        let size = (try? fm.attributesOfItem(atPath: path)[.size] as? Int) ?? 0
        if size < 50 { return (false, "Pairing file too small (\(size) bytes).") }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return (false, "Pairing file unreadable.")
        }
        guard let obj = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = obj as? [String: Any] else {
            return (false, "Pairing file not a plist (\(size) bytes).")
        }
        if dict.isEmpty { return (false, "Pairing plist empty.") }
        return (true, "Pairing ok (\(size) bytes, \(dict.count) keys)")
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

    func injectFolder(sourceFolder: String, targetFolder: String, folderName: String) -> ProbeResult {
        let pre = probe()
        guard pre.ok else { return pre }
        guard let pairingPath = findPairingFile() else {
            return ProbeResult(state: .noPairing, detail: "no pairing path")
        }
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: sourceFolder, isDirectory: &isDir), isDir.boolValue else {
            return ProbeResult(state: .ffiFailed("source is not a directory: \(sourceFolder)"), detail: "source missing")
        }
        let contents = (try? fm.contentsOfDirectory(atPath: sourceFolder)) ?? []
        guard !contents.isEmpty else {
            return ProbeResult(state: .ffiFailed("no files in directory: \(sourceFolder)"), detail: "empty source")
        }
        var outError: UnsafeMutablePointer<CChar>? = nil
        var rc: Int32 = -1
        pairingPath.withCString { pc in
            sourceFolder.withCString { sc in
                targetFolder.withCString { tc in
                    folderName.withCString { nc in
                        rc = al_exploit_inject_folder(pc, sc, tc, nc, nil, nil, &outError)
                    }
                }
            }
        }
        let errMsg = outError.flatMap { String(cString: $0) } ?? ""
        if let p = outError { al_string_free(p) }
        if rc != 0 {
            return ProbeResult(state: .ffiFailed(errMsg.isEmpty ? "inject rc=\(rc)" : errMsg), detail: errMsg)
        }
        return ProbeResult(state: .ok, detail: "injected")
    }

    func writeFile(source: String, target: String) -> ProbeResult {
        let pre = probe()
        guard pre.ok else { return pre }
        guard let pairingPath = findPairingFile() else {
            return ProbeResult(state: .noPairing, detail: "no pairing path")
        }
        var outJson: UnsafeMutablePointer<CChar>? = nil
        var outErr: UnsafeMutablePointer<CChar>? = nil
        var rc: Int32 = -1
        pairingPath.withCString { pc in
            source.withCString { sc in
                target.withCString { tc in
                    rc = al_exploit_run(pc, tc, nil, nil, &outJson, &outErr)
                }
            }
        }
        let errMsg = outErr.flatMap { String(cString: $0) } ?? ""
        if let p = outJson { al_string_free(p) }
        if let p = outErr { al_string_free(p) }
        if rc != 0 { return ProbeResult(state: .ffiFailed(errMsg.isEmpty ? "rc=\(rc)" : errMsg), detail: errMsg) }
        return ProbeResult(state: .ok, detail: "ok")
    }
}
