import Foundation
import IDevice

final class PairingGenerator: @unchecked Sendable {
    static let shared = PairingGenerator()

    enum GeneratorError: LocalizedError {
        case rppFailed(String)
        case tunnelFailed(String)
        case lockdownFailed(String)
        case writeFailed(String)

        var errorDescription: String? {
            switch self {
            case .rppFailed(let s): return "RPPairing failed: \(s)"
            case .tunnelFailed(let s): return "Tunnel creation failed: \(s)"
            case .lockdownFailed(let s): return "Lockdown handshake failed: \(s)"
            case .writeFailed(let s): return "Pairing write failed: \(s)"
            }
        }
    }

    struct MergedPairing {
        let rpp: [String: Any]
        let lockdown: [String: Any]
        var combined: [String: Any] {
            var out = rpp
            for (k, v) in lockdown { out[k] = v }
            return out
        }
    }

    func generateMergedPairing(
        deviceIP: String = "10.7.0.1",
        port: UInt16 = 49152,
        rppPath: String,
        outputPath: String
    ) throws {
        let rpp = try loadRPCRecord(from: rppPath)
        let tunnel = try createRSDTunnel(deviceIP: deviceIP, port: port, rpp: rpp)
        let lockdown = try performLockdownPair(tunnel: tunnel)
        let merged = MergedPairing(rpp: rpp, lockdown: lockdown)
        try writeMerged(merged.combined, to: outputPath)
    }

    private func loadRPCRecord(from path: String) throws -> [String: Any] {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            throw GeneratorError.rppFailed("cannot read \(path)")
        }
        guard let plist = try? PropertyListSerialization.propertyList(
            from: data, options: [], format: nil) as? [String: Any] else {
            throw GeneratorError.rppFailed("not a plist")
        }
        return plist
    }

    private func createRSDTunnel(
        deviceIP: String,
        port: UInt16,
        rpp: [String: Any]
    ) throws -> OpaquePointer {
        guard let rppData = try? PropertyListSerialization.data(
            fromPropertyList: rpp, format: .binary, options: 0) else {
            throw GeneratorError.tunnelFailed("cannot serialize RPP")
        }
        var tunnelHandle: OpaquePointer? = nil
        let rc = rppData.withUnsafeBytes { buf -> Int32 in
            guard let base = buf.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return -1 }
            return tunnel_create_rppairing(deviceIP, port, base, buf.count, &tunnelHandle)
        }
        guard rc == 0, let handle = tunnelHandle else {
            throw GeneratorError.tunnelFailed("rc=\(rc)")
        }
        return handle
    }

    private func performLockdownPair(tunnel: OpaquePointer) throws -> [String: Any] {
        var lockdownRecord: OpaquePointer? = nil
        let rc = lockdownd_pair_via_rsd(tunnel, &lockdownRecord)
        guard rc == 0, let record = lockdownRecord else {
            throw GeneratorError.lockdownFailed("rc=\(rc)")
        }
        var bytes: UnsafeMutablePointer<UInt8>? = nil
        var length: Int = 0
        let serRC = lockdown_record_serialize(record, &bytes, &length)
        guard serRC == 0, let b = bytes else {
            throw GeneratorError.lockdownFailed("serialize rc=\(serRC)")
        }
        defer { lockdown_record_free(record) }
        let data = Data(bytes: b, count: length)
        free(bytes)
        guard let plist = try? PropertyListSerialization.propertyList(
            from: data, options: [], format: nil) as? [String: Any] else {
            throw GeneratorError.lockdownFailed("not a plist")
        }
        return plist
    }

    private func writeMerged(_ merged: [String: Any], to path: String) throws {
        guard let data = try? PropertyListSerialization.data(
            fromPropertyList: merged, format: .xml, options: 0) else {
            throw GeneratorError.writeFailed("serialize")
        }
        do {
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        } catch {
            throw GeneratorError.writeFailed(error.localizedDescription)
        }
    }
}
