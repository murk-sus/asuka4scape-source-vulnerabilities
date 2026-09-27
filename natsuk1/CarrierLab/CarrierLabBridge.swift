import Foundation

final class CarrierLabBridge: @unchecked Sendable {
    static let shared = CarrierLabBridge()

    enum CarrierError: LocalizedError {
        case noPairing
        case notImplemented(String)
        case remote(String)

        var errorDescription: String? {
            switch self {
            case .noPairing: return "No pairing file. Pair via Airlift first."
            case .notImplemented(let s): return "Not implemented: " + s
            case .remote(let s): return s
            }
        }
    }

    private let carrierRoot = "/var/mobile/Library/Carrier Bundles"
    private let bundleLinks = "/var/mobile/Library/Carrier Bundles/BundleLinks"

    func carrierRootPath() -> String { carrierRoot }
    func bundleLinksPath() -> String { bundleLinks }

    func writeFile(source: String, target: String) throws {
        let pairing = PairingController.pairingFilePath()
        guard FileManager.default.fileExists(atPath: pairing) else { throw CarrierError.noPairing }
        var outJson: UnsafeMutablePointer<CChar>? = nil
        var outErr: UnsafeMutablePointer<CChar>? = nil
        let rc: Int32 = pairing.withCString { pc in
            source.withCString { sc in
                target.withCString { tc in
                    al_exploit_run(pc, tc, nil, nil, &outJson, &outErr)
                }
            }
        }
        if let p = outJson { al_string_free(p) }
        let errMsg = outErr.flatMap { String(cString: $0) } ?? ""
        if let p = outErr { al_string_free(p) }
        if rc != 0 { throw CarrierError.remote(errMsg.isEmpty ? "rc=\(rc)" : errMsg) }
    }

    func readFile(path: String) throws -> Data {
        throw CarrierError.notImplemented("al_read_file")
    }

    func removePath(_ path: String) throws {
        throw CarrierError.notImplemented("al_remove_path")
    }

    func symlink(link: String, target: String) throws {
        throw CarrierError.notImplemented("al_make_symlink")
    }
}
