import Foundation

final class PairingGenerator {
    static let shared = PairingGenerator()
    private init() {}

    enum GeneratorError: LocalizedError {
        case lockdownFailed(String)
        case mergeFailed(String)
        case writeFailed(String)

        var errorDescription: String? {
            switch self {
            case .lockdownFailed(let s): return "Lockdown handshake failed: \(s)"
            case .mergeFailed(let s): return "Merge failed: \(s)"
            case .writeFailed(let s): return "Write failed: \(s)"
            }
        }
    }

    func generateMergedPairing(rppPath: String, outputPath: String) throws {
        guard let rppData = try? Data(contentsOf: URL(fileURLWithPath: rppPath)) else {
            throw GeneratorError.lockdownFailed("cannot read RPP file")
        }
        guard let rpp = try? PropertyListSerialization.propertyList(
            from: rppData, options: [], format: nil) as? [String: Any] else {
            throw GeneratorError.lockdownFailed("RPP is not a plist")
        }

        var lockdownClient: OpaquePointer? = nil
        let connectRC = lockdownd_connect_rsd(nil, &lockdownClient)
        guard connectRC == 0, let client = lockdownClient else {
            throw GeneratorError.lockdownFailed("lockdownd_connect_rsd rc=\(connectRC)")
        }
        defer { lockdownd_client_free(client) }

        var lockdownRecord: OpaquePointer? = nil
        let pairRC = lockdownd_pair(client, nil, &lockdownRecord)
        guard pairRC == 0, let record = lockdownRecord else {
            throw GeneratorError.lockdownFailed("lockdownd_pair rc=\(pairRC)")
        }
        defer { lockdownd_pair_record_free(record) }

        var bytes: UnsafeMutablePointer<UInt8>? = nil
        var length: Int = 0
        let serRC = idevice_pairing_file_serialize(record, &bytes, &length)
        guard serRC == 0, let b = bytes else {
            throw GeneratorError.lockdownFailed("serialize rc=\(serRC)")
        }
        defer { free(bytes) }

        let lockdownData = Data(bytes: b, count: length)
        guard let lockdown = try? PropertyListSerialization.propertyList(
            from: lockdownData, options: [], format: nil) as? [String: Any] else {
            throw GeneratorError.lockdownFailed("lockdown record not a plist")
        }

        var merged = rpp
        for (k, v) in lockdown { merged[k] = v }
        if let udid = lockdown["UDID"] as? String { merged["UDID"] = udid }

        guard let out = try? PropertyListSerialization.data(
            fromPropertyList: merged, format: .xml, options: 0) else {
            throw GeneratorError.mergeFailed("serialize")
        }
        do {
            try out.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
        } catch {
            throw GeneratorError.writeFailed(error.localizedDescription)
        }
    }
}
