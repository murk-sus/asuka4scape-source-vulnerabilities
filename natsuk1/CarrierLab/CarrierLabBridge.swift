import Foundation
import UIKit

final class CarrierLabBridge: @unchecked Sendable {
    static let shared = CarrierLabBridge()

    enum CarrierError: LocalizedError {
        case airliftUnavailable
        case remote(String)
        case io(String)

        var errorDescription: String? {
            switch self {
            case .airliftUnavailable: return "Airlift недоступен. Проверьте pairing и запустите Airlift ещё раз."
            case .remote(let s): return s
            case .io(let s): return "I/O: " + s
            }
        }
    }

    private let carrierRoot = CarrierConstants.carrierTarget
    private let bundleLinks = CarrierConstants.carrierLinks

    private var lastProbeOK = false
    private var lastProbeMessage = "не проверялся"

    func probe() -> (ok: Bool, message: String) {
        var outErr: UnsafeMutablePointer<CChar>? = nil
        var outJson: UnsafeMutablePointer<CChar>? = nil
        let probeFile = NSTemporaryDirectory() + "/carrierlab-probe-\(UUID().uuidString).txt"
        try? "probe".data(using: .utf8)?.write(to: URL(fileURLWithPath: probeFile))
        var rc: Int32 = -1
        probeFile.withCString { pf in
            "/var/mobile/Library/Carrier Bundles/.carrierlab-probe".withCString { tf in
                rc = al_exploit_run(pf, tf, nil, nil, &outJson, &outErr)
            }
        }
        let errMsg = outErr.flatMap { String(cString: $0) } ?? ""
        if let p = outErr { al_string_free(p) }
        if let p = outJson { al_string_free(p) }
        try? FileManager.default.removeItem(atPath: probeFile)
        if rc == 0 {
            lastProbeOK = true
            lastProbeMessage = "OK"
        } else {
            lastProbeOK = false
            lastProbeMessage = errMsg.isEmpty ? "rc=\(rc)" : errMsg
        }
        return (lastProbeOK, lastProbeMessage)
    }

    func isAvailable() -> Bool { lastProbeOK }
    func probeMessage() -> String { lastProbeMessage }

    func writeFile(source: String, target: String) throws {
        let (ok, msg) = probe()
        guard ok else { throw CarrierError.airliftUnavailable }
        _ = msg
        var outJson: UnsafeMutablePointer<CChar>? = nil
        var outErr: UnsafeMutablePointer<CChar>? = nil
        var rc: Int32 = -1
        source.withCString { sc in
            target.withCString { tc in
                rc = al_exploit_run(sc, tc, nil, nil, &outJson, &outErr)
            }
        }
        if let p = outJson { al_string_free(p) }
        let errMsg = outErr.flatMap { String(cString: $0) } ?? ""
        if let p = outErr { al_string_free(p) }
        if rc != 0 { throw CarrierError.remote(errMsg.isEmpty ? "rc=\(rc)" : errMsg) }
    }

    func bundleLinksPath() -> String { bundleLinks + "/iPhone" }
    func carrierRootPath() -> String { carrierRoot }
}
