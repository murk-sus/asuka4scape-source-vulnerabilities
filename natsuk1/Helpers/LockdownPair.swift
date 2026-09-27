import Foundation
import Darwin
enum LockdownPair {
    static let port: UInt16 = 62078
    private static let userDeniedPairingCode: Int32 = 31
    struct Failure: LocalizedError {
        enum Stage: String {
            case connect
            case pair
            case serialize
        }
        let stage: Stage
        let host: String
        let code: Int32
        let subCode: Int32
        let message: String
        var userDeclined: Bool {
            stage == .pair
                && (code == LockdownPair.userDeniedPairingCode || message.contains("UserDeniedPairing"))
        }
        var errorDescription: String? {
            if userDeclined {
                return "Trust was declined on the iPhone, so no lockdown record was issued."
            }
            return "lockdownd \(stage.rawValue) at \(host):\(LockdownPair.port) failed "
                + "(code \(code)/\(subCode)): \(message)"
        }
    }
    static func candidateHosts() -> [String] {
        var hosts: [String] = []
        if let peer = NetworkStatus.tunnelIP() { hosts.append(peer) }
        hosts.append(contentsOf: ["10.7.0.1", "10.7.0.2", "10.7.0.3", "127.0.0.1"])
        var seen = Set<String>()
        return hosts.filter { seen.insert($0).inserted }
    }
    static func mintRecord(hosts: [String],
                           hostID: String,
                           systemBUID: String,
                           hostName: String) throws -> Data {
        guard !hosts.isEmpty else {
            throw Failure(stage: .connect, host: "", code: -1, subCode: 0,
                          message: "no address to reach lockdownd on")
        }
        var last: Failure?
        for host in hosts {
            do {
                return try pair(host: host, hostID: hostID,
                                systemBUID: systemBUID, hostName: hostName)
            } catch let failure as Failure {
                last = failure
                if failure.userDeclined { throw failure }
            }
        }
        throw last ?? Failure(stage: .connect, host: hosts.joined(separator: ", "),
                              code: -1, subCode: 0, message: "lockdownd did not pair")
    }
    private static func pair(host: String,
                             hostID: String,
                             systemBUID: String,
                             hostName: String) throws -> Data {
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        guard host.withCString({ inet_pton(AF_INET, $0, &addr.sin_addr) }) == 1 else {
            throw Failure(stage: .connect, host: host, code: -1, subCode: 0,
                          message: "invalid address")
        }
        var device: OpaquePointer?
        let connectError = withUnsafePointer(to: &addr) { aptr in
            aptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                hostName.withCString { label in
                    idevice_new_tcp_socket(sa, socklen_t(MemoryLayout<sockaddr_in>.size),
                                           label, &device)
                }
            }
        }
        if let failure = consume(connectError, host, .connect) { throw failure }
        guard let device else {
            throw Failure(stage: .connect, host: host, code: -1, subCode: 0,
                          message: "lockdown socket handle was null")
        }
        var client: OpaquePointer?
        let newError = lockdownd_new(device, &client)
        if let failure = consume(newError, host, .connect) {
            idevice_free(device)
            throw failure
        }
        guard let client else {
            idevice_free(device)
            throw Failure(stage: .connect, host: host, code: -1, subCode: 0,
                          message: "lockdown client was null")
        }
        defer { lockdownd_client_free(client) }
        var record: OpaquePointer?
        let pairError = hostID.withCString { h in
            systemBUID.withCString { b in
                hostName.withCString { n in
                    lockdownd_pair(client, h, b, n, &record)
                }
            }
        }
        if let failure = consume(pairError, host, .pair) { throw failure }
        guard let record else {
            throw Failure(stage: .pair, host: host, code: -1, subCode: 0,
                          message: "lockdownd_pair returned no pair record")
        }
        defer { idevice_pairing_file_free(record) }
        var bytes: UnsafeMutablePointer<UInt8>?
        var length: UInt = 0
        let serializeError = idevice_pairing_file_serialize(record, &bytes, &length)
        if let failure = consume(serializeError, host, .serialize) { throw failure }
        guard let bytes, length > 0 else {
            throw Failure(stage: .serialize, host: host, code: -1, subCode: 0,
                          message: "serialised pair record was empty")
        }
        defer { idevice_data_free(bytes, length) }
        return Data(bytes: bytes, count: Int(length))
    }
    private static func consume(_ err: UnsafeMutablePointer<IdeviceFfiError>?,
                                _ host: String,
                                _ stage: Failure.Stage) -> Failure? {
        guard let err else { return nil }
        let code = err.pointee.code
        let subCode = err.pointee.sub_code
        let message = err.pointee.message.flatMap { String(validatingUTF8: $0) } ?? ""
        idevice_error_free(err)
        return Failure(stage: stage, host: host, code: code, subCode: subCode,
                       message: message.isEmpty ? "unknown error" : message)
    }
}
