import Foundation
import Darwin
import UIKit

final class LockdownPairResultBox: @unchecked Sendable {
    var value: Data?
    var failure: LockdownPair.Failure?
}

enum LockdownPair {
    static let port: UInt16 = 62078
    static let probeTimeoutMS: Int32 = 1500
    static let perHostTimeout: TimeInterval = 75
    static let totalTimeout: TimeInterval = 150
    private static let userDeniedPairingCode: Int32 = 31

    private static let stateLock = NSLock()
    private static var _cancelled = false

    static var cancelled: Bool {
        stateLock.lock(); defer { stateLock.unlock() }
        return _cancelled
    }

    static func requestCancel() {
        stateLock.lock(); _cancelled = true; stateLock.unlock()
    }

    static func resetCancel() {
        stateLock.lock(); _cancelled = false; stateLock.unlock()
    }

    struct Failure: LocalizedError {
        enum Stage: String {
            case locked
            case probe
            case connect
            case pair
            case timeout
            case serialize
            case cancelled
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
            switch stage {
            case .locked:
                return "The iPhone is locked, so lockdownd cannot show its Trust prompt."
            case .cancelled:
                return "Minting was cancelled."
            default:
                break
            }
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

    private static func address(_ host: String) -> sockaddr_in? {
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        guard host.withCString({ inet_pton(AF_INET, $0, &addr.sin_addr) }) == 1 else { return nil }
        return addr
    }

    private static func tcpReachable(_ addr: inout sockaddr_in) -> Bool {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        _ = fcntl(fd, F_SETFL, O_NONBLOCK)
        let rc = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                connect(fd, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        if rc == 0 { return true }
        guard errno == EINPROGRESS else { return false }
        var pfd = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
        guard poll(&pfd, 1, probeTimeoutMS) > 0 else { return false }
        var soError: Int32 = 0
        var len = socklen_t(MemoryLayout<Int32>.size)
        guard getsockopt(fd, SOL_SOCKET, SO_ERROR, &soError, &len) == 0 else { return false }
        return soError == 0
    }

    static func reachableHosts(_ hosts: [String], progress: ((String) -> Void)? = nil) -> [String] {
        var out: [String] = []
        for host in hosts {
            if cancelled { break }
            progress?("Probing lockdownd on \(host):\(port)...")
            guard var addr = address(host) else { continue }
            if tcpReachable(&addr) { out.append(host) }
        }
        return out
    }

    static func mintRecord(hosts: [String],
                           hostID: String,
                           systemBUID: String,
                           hostName: String,
                           progress: ((String) -> Void)? = nil) throws -> Data {
        if cancelled {
            throw Failure(stage: .cancelled, host: "", code: -1, subCode: 0, message: "cancelled")
        }
        guard UIApplication.shared.isProtectedDataAvailable else {
            throw Failure(stage: .locked, host: "", code: -1, subCode: 0,
                          message: "protected data unavailable")
        }
        guard !hosts.isEmpty else {
            throw Failure(stage: .connect, host: "", code: -1, subCode: 0,
                          message: "no address to reach lockdownd on")
        }

        let targets = reachableHosts(hosts, progress: progress)
        guard !targets.isEmpty else {
            throw Failure(stage: .probe, host: hosts.joined(separator: ", "), code: -1, subCode: 0,
                          message: "nothing accepted a TCP connection on port \(port)")
        }

        let started = Date()
        let overallDeadline = started.addingTimeInterval(totalTimeout)
        var last: Failure?

        for host in targets {
            if cancelled {
                throw Failure(stage: .cancelled, host: host, code: -1, subCode: 0, message: "cancelled")
            }
            if Date() > overallDeadline {
                throw Failure(stage: .timeout, host: host, code: -1, subCode: 0,
                              message: "gave up after \(Int(totalTimeout))s")
            }

            let sem = DispatchSemaphore(value: 0)
            let box = LockdownPairResultBox()
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    box.value = try pair(host: host, hostID: hostID,
                                         systemBUID: systemBUID, hostName: hostName)
                } catch let failure as Failure {
                    box.failure = failure
                } catch {
                    box.failure = Failure(stage: .pair, host: host, code: -1, subCode: 0,
                                          message: String(describing: error))
                }
                sem.signal()
            }

            let hostDeadline = Date().addingTimeInterval(perHostTimeout)
            var timedOut = false
            while true {
                if sem.wait(timeout: .now() + 0.25) == .success { break }
                let now = Date()
                if cancelled {
                    throw Failure(stage: .cancelled, host: host, code: -1, subCode: 0, message: "cancelled")
                }
                if now > hostDeadline || now > overallDeadline {
                    timedOut = true
                    break
                }
                let elapsed = Int(now.timeIntervalSince(started))
                progress?("Waiting for Trust on \(host):\(port) (\(elapsed)s). Unlock the iPhone and tap Trust.")
            }

            if timedOut {
                last = Failure(stage: .timeout, host: host, code: -1, subCode: 0,
                               message: "no answer within \(Int(perHostTimeout))s")
                continue
            }
            if let value = box.value { return value }
            if let failure = box.failure {
                if failure.userDeclined { throw failure }
                last = failure
            }
        }

        throw last ?? Failure(stage: .pair, host: targets.joined(separator: ", "), code: -1, subCode: 0,
                              message: "lockdownd did not pair")
    }

    private static func pair(host: String,
                             hostID: String,
                             systemBUID: String,
                             hostName: String) throws -> Data {
        guard var addr = address(host) else {
            throw Failure(stage: .connect, host: host, code: -1, subCode: 0, message: "invalid address")
        }

        var device: OpaquePointer?
        let connectError = withUnsafePointer(to: &addr) { aptr in
            aptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                hostName.withCString { label in
                    idevice_new_tcp_socket(sa, socklen_t(MemoryLayout<sockaddr_in>.size), label, &device)
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
