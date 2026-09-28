import Foundation
import Darwin

// The routing table is the authority: iOS keeps system utuns up with no VPN.
enum NetworkStatus {
    struct Interface { let name: String; let ipv4: String; let netmask: String? }
    struct TunnelPair { let local: String; let peer: String?; let iface: String }

    // TEST-NET-3 (RFC 5737): only the default route can claim it; the UDP
    // connect below sends nothing.
    private static let defaultRouteProbe = "203.0.113.1"
    private static let canonicalTunnelPeer = "10.7.0.1"

    static func interfaces() -> [Interface] {
        var out: [Interface] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return [] }
        defer { freeifaddrs(ifaddr) }
        var p: UnsafeMutablePointer<ifaddrs>? = first
        while let c = p {
            defer { p = c.pointee.ifa_next }
            guard let n = c.pointee.ifa_name, let a = c.pointee.ifa_addr,
                  a.pointee.sa_family == sa_family_t(AF_INET), let v4 = host(a) else { continue }
            out.append(Interface(name: String(cString: n), ipv4: v4,
                                 netmask: c.pointee.ifa_netmask.flatMap(host)))
        }
        return out
    }

    private static func host(_ a: UnsafeMutablePointer<sockaddr>) -> String? {
        var b = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        guard getnameinfo(a, socklen_t(MemoryLayout<sockaddr_in>.size), &b,
                          socklen_t(b.count), nil, 0, NI_NUMERICHOST) == 0 else { return nil }
        return String(decoding: b.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    static func tunnelPairs() -> [TunnelPair] {
        var out: [TunnelPair] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return [] }
        defer { freeifaddrs(ifaddr) }
        var p: UnsafeMutablePointer<ifaddrs>? = first
        while let c = p {
            defer { p = c.pointee.ifa_next }
            guard let n = c.pointee.ifa_name else { continue }
            let name = String(cString: n)
            guard isTunnelInterface(name), let a = c.pointee.ifa_addr,
                  a.pointee.sa_family == sa_family_t(AF_INET),
                  let local = host(a), isLoopbackRange(local) else { continue }
            var peer: String? = nil
            if let d = c.pointee.ifa_dstaddr, d.pointee.sa_family == sa_family_t(AF_INET),
               let q = host(d), isLoopbackRange(q), q != local { peer = q }
            out.append(TunnelPair(local: local, peer: peer, iface: name))
        }
        return out
    }

    // nil from the table is not a refusal: keep the interface evidence.
    static func loopbackVPNUp() -> Bool {
        if let r = routeCarriesTunnel() { return r }
        return !tunnelPairs().isEmpty
    }

    private static func routeCarriesTunnel() -> Bool? {
        let target = tunnelPairs().compactMap { $0.peer }.first ?? canonicalTunnelPeer
        guard let src = routeSource(to: target),
              let ifc = interfaces().first(where: { $0.ipv4 == src }) else { return nil }
        guard isTunnelInterface(ifc.name) else { return false }
        return routeSource(to: defaultRouteProbe) != src
    }

    // Local address the kernel would send from when dialling ip.
    private static func routeSource(to ip: String) -> String? {
        var remote = sockaddr_in()
        remote.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        remote.sin_family = sa_family_t(AF_INET)
        remote.sin_port = in_port_t(UInt16(9).bigEndian)
        guard ip.withCString({ inet_pton(AF_INET, $0, &remote.sin_addr) }) == 1 else { return nil }
        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else { return nil }
        defer { close(fd) }
        let ok = withUnsafePointer(to: &remote) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        } == 0
        guard ok else { return nil }
        var local = sockaddr_in()
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        let named = withUnsafeMutablePointer(to: &local) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(fd, $0, &len) }
        } == 0
        guard named, local.sin_addr.s_addr != 0 else { return nil }
        return withUnsafeMutablePointer(to: &local) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1, host)
        }
    }

    static func tunnelIP() -> String? {
        for p in tunnelPairs() { if let peer = p.peer { return peer } }
        return nil
    }

    static func deviceIP() -> String? {
        for p in tunnelPairs() { return p.local }
        return nil
    }

    static func isLoopbackRange(_ ip: String) -> Bool { ip.hasPrefix("10.7.") }

    static func isTunnelInterface(_ name: String) -> Bool {
        name.hasPrefix("utun") || name.hasPrefix("ipsec")
            || name.hasPrefix("tap") || name.hasPrefix("ppp")
    }
}
