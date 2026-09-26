import Foundation
import Darwin

enum NetworkStatus {
    struct Interface {
        let name: String
        let ipv4: String
        let netmask: String?
    }
    struct TunnelPair {
        let local: String
        let peer: String?
        let iface: String
    }

    static func interfaces() -> [Interface] {
        var result: [Interface] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return [] }
        defer { freeifaddrs(ifaddr) }
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let cur = ptr {
            defer { ptr = cur.pointee.ifa_next }
            guard let addr = cur.pointee.ifa_addr else { continue }
            guard addr.pointee.sa_family == sa_family_t(AF_INET) else { continue }
            let name = String(cString: cur.pointee.ifa_name)
            guard let ipv4 = numericHost(addr) else { continue }
            result.append(Interface(name: name, ipv4: ipv4,
                                    netmask: cur.pointee.ifa_netmask.flatMap(numericHost)))
        }
        return result
    }

    private static func numericHost(_ addr: UnsafeMutablePointer<sockaddr>) -> String? {
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let len = socklen_t(MemoryLayout<sockaddr_in>.size)
        guard getnameinfo(addr, len, &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0
        else { return nil }
        let bytes = host.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }

    static func tunnelPairs() -> [TunnelPair] {
        var result: [TunnelPair] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return [] }
        defer { freeifaddrs(ifaddr) }
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let cur = ptr {
            defer { ptr = cur.pointee.ifa_next }
            let name = String(cString: cur.pointee.ifa_name)
            guard isTunnelInterface(name) else { continue }
            guard let addr = cur.pointee.ifa_addr,
                  addr.pointee.sa_family == sa_family_t(AF_INET) else { continue }
            guard let local = numericHost(addr), isLoopbackRange(local) else { continue }
            var peer: String? = nil
            if let dst = cur.pointee.ifa_dstaddr,
               dst.pointee.sa_family == sa_family_t(AF_INET) {
                if let p = numericHost(dst), isLoopbackRange(p), p != local { peer = p }
            }
            result.append(TunnelPair(local: local, peer: peer, iface: name))
        }
        return result
    }

    static func summarize(deviceIP: String) -> (vpn: Bool, wifi: Bool, detail: String) {
        let ifs = interfaces()
        let vpn = loopbackVPNUp()
        let wifi = ifs.contains { $0.name == "en0" }
        let detail = ifs.map { "\($0.name)=\($0.ipv4)" }.joined(separator: ", ")
        return (vpn, wifi, detail)
    }

    static func loopbackVPNUp() -> Bool {
        return !tunnelPairs().isEmpty
    }

    static func tunnelIP() -> String? {
        for p in tunnelPairs() {
            if let peer = p.peer { return peer }
        }
        return nil
    }

    static func deviceIP() -> String? {
        for p in tunnelPairs() { return p.local }
        return nil
    }

    static func isLoopbackRange(_ ip: String) -> Bool {
        return ip.hasPrefix("10.7.")
    }

    static func isTunnelInterface(_ name: String) -> Bool {
        name.hasPrefix("utun") || name.hasPrefix("ipsec")
            || name.hasPrefix("tap") || name.hasPrefix("ppp")
    }

    static func tunnelHostCandidates() -> [String] {
        let ifs = interfaces().filter {
            !isTunnelInterface($0.name) && !$0.ipv4.hasPrefix("127.")
        }
        return (ifs.filter { $0.name == "en0" } + ifs.filter { $0.name != "en0" })
            .map(\.ipv4)
    }

    static func host(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let slash = trimmed.firstIndex(of: "/") else { return trimmed }
        return String(trimmed[..<slash]).trimmingCharacters(in: .whitespaces)
    }

    static func isOwnAddress(_ deviceIP: String) -> Bool {
        interfaces().contains { $0.ipv4 == deviceIP }
    }
}
