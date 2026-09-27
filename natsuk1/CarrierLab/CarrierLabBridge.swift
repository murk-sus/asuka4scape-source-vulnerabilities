import Foundation

final class CarrierLabBridge: @unchecked Sendable {
    static let shared = CarrierLabBridge()

    enum ProbeState {
        case ok
        case noVPN
        case noPairing
        case pairingRPPOnly
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
            case .pairingRPPOnly: return "Pairing file is RPPairing-only. AirliftFFI needs merged lockdown+RPPairing with DeviceCertificate."
            case .pairingInvalid: return detail
            case .ffiFailed(let s): return s
            }
        }
    }

    private let carrierRoot = "/var/mobile/Library/Carrier Bundles/iPhone"
    private let bundleLinks = "/var/mobile/Library/Carrier Bundles"
    private let expectedLockdownKeys = ["DeviceCertificate", "HostCertificate", "RootCertificate", "HostID", "SystemBUID"]

    func carrierRootPath() -> String { carrierRoot }
    func bundleLinksPath() -> String { bundleLinks }

    private func findPairingFile() -> String? {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let candidates = [
            docs.appendingPathComponent("ALTPairingFile.mobiledevicepairing"),
            docs.appendingPathComponent("natsuk1_pairing.plist"),
            docs.appendingPathComponent("pairingFile.plist"),
        ]
        for url in candidates {
            if fm.fileExists(atPath: url.path) {
                let size = (try? fm.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
                if size > 0 { return url.path }
            }
        }
        let controller = PairingController.pairingFilePath()
        if fm.fileExists(atPath: controller) {
            let size = (try? fm.attributesOfItem(atPath: controller)[.size] as? Int) ?? 0
            if size > 0 { return controller }
        }
        if let e = try? fm.contentsOfDirectory(atPath: docs.path) {
            for f in e where f.hasSuffix(".plist") || f.hasSuffix(".mobilepairing") || f.hasSuffix(".mobilepair") {
                let p = docs.appendingPathComponent(f).path
                let size = (try? fm.attributesOfItem(atPath: p)[.size] as? Int) ?? 0
                if size > 100 { return p }
            }
        }
        let nested = docs.appendingPathComponent("Data/Application")
        if let e = try? fm.contentsOfDirectory(atPath: nested.path) {
            for sub in e {
                let inner = nested.appendingPathComponent(sub).appendingPathComponent("Documents/natsuk1_pairing.plist")
                if fm.fileExists(atPath: inner.path) {
                    let size = (try? fm.attributesOfItem(atPath: inner.path)[.size] as? Int) ?? 0
                    if size > 0 { return inner.path }
                }
            }
        }
        return nil
    }

    private func validatePairingFile(_ path: String) -> (Bool, String, Bool) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return (false, "missing", false) }
        let attrs = try? fm.attributesOfItem(atPath: path)
        let size = (attrs?[.size] as? Int) ?? 0
        if size < 50 { return (false, "Pairing file too small (\(size) bytes).", false) }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return (false, "Pairing file unreadable.", false)
        }
        guard let obj = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = obj as? [String: Any] else {
            return (false, "Pairing file not a plist (\(size) bytes).", false)
        }
        if dict.isEmpty { return (false, "Pairing plist empty.", false) }
        var lockdownCount = 0
        for k in expectedLockdownKeys where dict[k] != nil { lockdownCount += 1 }
        let hasLockdown = lockdownCount >= 3
        return (true, "Pairing ok (\(size) bytes, \(dict.count) keys, lockdown=\(lockdownCount))", hasLockdown)
    }

    func probe() -> ProbeResult {
        if !NetworkStatus.loopbackVPNUp() { return ProbeResult(state: .noVPN, detail: "no loopback VPN") }
        guard let pairing = findPairingFile() else {
            return ProbeResult(state: .noPairing, detail: "missing")
        }
        let (ok, msg, hasLockdown) = validatePairingFile(pairing)
        if !ok { return ProbeResult(state: .pairingInvalid, detail: msg) }
        if !hasLockdown { return ProbeResult(state: .pairingRPPOnly, detail: msg) }
        return ProbeResult(state: .ok, detail: msg)
    }

    func writeFile(source: String, target: String) -> ProbeResult {
        let pre = probe()
        guard pre.ok else { return pre }
        let pairingPath = findPairingFile() ?? ""
        guard !pairingPath.isEmpty else {
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
