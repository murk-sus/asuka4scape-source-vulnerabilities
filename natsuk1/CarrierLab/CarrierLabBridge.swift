import Foundation

final class CarrierLabBridge: @unchecked Sendable {
    static let shared = CarrierLabBridge()

    enum ProbeState {
        case ok
        case noVPN
        case noPairing
        case pairingTooSmall(Int)
        case ffiFailed(String)
    }

    struct ProbeResult {
        let state: ProbeState
        var ok: Bool {
            if case .ok = state { return true }
            return false
        }
        var message: String {
            switch state {
            case .ok: return "ready"
            case .noVPN: return "no loopback VPN. Enable LocalDevVPN or SideStore WireGuard."
            case .noPairing: return "no pairing file. Open Airlift and start pairing."
            case .pairingTooSmall(let n): return "pairing file damaged (\(n) bytes). Re-pair in Airlift."
            case .ffiFailed(let s): return s
            }
        }
    }

    private let carrierRoot = "/var/mobile/Library/Carrier Bundles/iPhone"
    private let bundleLinks = "/var/mobile/Library/Carrier Bundles"

    func carrierRootPath() -> String { carrierRoot }
    func bundleLinksPath() -> String { bundleLinks }

    func probe() -> ProbeResult {
        if !NetworkStatus.loopbackVPNUp() {
            return ProbeResult(state: .noVPN)
        }
        let pairing = PairingController.pairingFilePath()
        guard FileManager.default.fileExists(atPath: pairing) else {
            return ProbeResult(state: .noPairing)
        }
        let size = (try? FileManager.default.attributesOfItem(atPath: pairing)[.size] as? Int) ?? 0
        if size < 200 {
            return ProbeResult(state: .pairingTooSmall(size))
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
        if rc != 0 {
            return ProbeResult(state: .ffiFailed(errMsg.isEmpty ? "rc=\(rc)" : errMsg))
        }
        return ProbeResult(state: .ok)
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
        if rc != 0 {
            return ProbeResult(state: .ffiFailed(errMsg.isEmpty ? "rc=\(rc)" : errMsg))
        }
        return ProbeResult(state: .ok)
    }
}
