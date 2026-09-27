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
            case .noVPN: return "no loopback VPN. Enable LocalDevVPN or SideStore WireGuard."
            case .noPairing: return "no pairing file. Open Tools -> Airlift, run Start Pairing."
            case .pairingInvalid: return detail
            case .ffiFailed(let s): return s
            }
        }
    }

    private let carrierRoot = "/var/mobile/Library/Carrier Bundles/iPhone"
    private let bundleLinks = "/var/mobile/Library/Carrier Bundles"

    func carrierRootPath() -> String { carrierRoot }
    func bundleLinksPath() -> String { bundleLinks }

    private func validatePairingFile(_ path: String) -> (Bool, String) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return (false, "missing") }
        let attrs = try? fm.attributesOfItem(atPath: path)
        let size = (attrs?[.size] as? Int) ?? 0
        if size < 200 { return (false, "pairing file damaged (\(size) bytes). Re-pair in Tools -> Airlift.") }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return (false, "pairing file unreadable") }
        guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return (false, "pairing file corrupt: not a plist (\(size) bytes). Re-pair in Tools -> Airlift.")
        }
        let keys = ["UDID", "DeviceCertificate", "HostCertificate", "RootCertificate", "HostID"]
        var hits = 0
        for k in keys where plist[k] != nil { hits += 1 }
        if hits < 2 { return (false, "pairing file invalid: only \(hits) of 5 keys present. Re-pair in Tools -> Airlift.") }
        return (true, "pairing ok (\(size) bytes, \(hits) keys)")
    }

    func probe() -> ProbeResult {
        if !NetworkStatus.loopbackVPNUp() { return ProbeResult(state: .noVPN, detail: "no loopback VPN") }
        let pairing = PairingController.pairingFilePath()
        let (pairOk, pairMsg) = validatePairingFile(pairing)
        if !pairOk {
            if pairMsg == "missing" { return ProbeResult(state: .noPairing, detail: pairMsg) }
            return ProbeResult(state: .pairingInvalid, detail: pairMsg)
        }
        let tmp = NSTemporaryDirectory() + "/carrierlab-probe-\(UUID().uuidString).txt"
        try? "probe".data(using: .utf8)?.write(to: URL(fileURLWithPath: tmp))
        var outJson: UnsafeMutablePointer<CChar>? = nil
        var outErr: UnsafeMutablePointer<CChar>? = nil
        var rc: Int32 = -1
        tmp.withCString { sf in
            "/var/mobile/Library/Carrier Bundles/.carrierlab-probe".withCString { tf in
                rc = al_exploit_run(sf, tf, nil, nil, &outJson, &outErr)
            }
        }
        let errMsg = outErr.flatMap { String(cString: $0) } ?? ""
        if let p = outJson { al_string_free(p) }
        if let p = outErr { al_string_free(p) }
        try? FileManager.default.removeItem(atPath: tmp)
        if rc != 0 { return ProbeResult(state: .ffiFailed(errMsg.isEmpty ? "rc=\(rc)" : errMsg), detail: errMsg) }
        return ProbeResult(state: .ok, detail: "ready")
    }

    func writeFile(source: String, target: String) -> ProbeResult {
        let pre = probe()
        guard pre.ok else { return pre }
        var outJson: UnsafeMutablePointer<CChar>? = nil
        var outErr: UnsafeMutablePointer<CChar>? = nil
        var rc: Int32 = -1
        source.withCString { sc in
            target.withCString { tc in
                rc = al_exploit_run(sc, tc, nil, nil, &outJson, &outErr)
            }
        }
        let errMsg = outErr.flatMap { String(cString: $0) } ?? ""
        if let p = outJson { al_string_free(p) }
        if let p = outErr { al_string_free(p) }
        if rc != 0 { return ProbeResult(state: .ffiFailed(errMsg.isEmpty ? "rc=\(rc)" : errMsg), detail: errMsg) }
        return ProbeResult(state: .ok, detail: "ok")
    }
}
