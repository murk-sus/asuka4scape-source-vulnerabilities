import Foundation
import Darwin

/// Loopback-tunnel detection.
///
/// An interface is not proof. iOS keeps system `utun`s up with no VPN running at
/// all, so "a utun exists" reports connected while nothing routes to the
/// device's internal services. The routing table is the authority — the check
/// SideInstaller and AirCard-iOS run before they dial RSD on
/// `10.7.0.1` / `127.0.0.1`.
///
/// Airlift's own diagnostic names the precondition:
/// `Ensure a loopback VPN (e.g. LocalDevVPN or SideStore WireGuard) is active.`
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

    /// TEST-NET-3 (RFC 5737) is reserved for documentation, so no VPN app routes
    /// it deliberately: only the default route can claim it. A UDP `connect`
    /// sends nothing — it resolves the route and selects a source address.
    private static let defaultRouteProbe = "203.0.113.1"

    /// The peer LocalDevVPN hands out when an interface does not report one.
    private static let canonicalTunnelPeer = "10.7.0.1"

    // MARK: - Interfaces

    static func interfaces() -> [Interface] {
        var result: [Interface] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return [] }
        defer { freeifaddrs(ifaddr) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let cur = ptr {
            defer { ptr = cur.pointee.ifa_next }
            guard let namePtr = cur.pointee.ifa_name,
                  let addr = cur.pointee.ifa_addr,
                  addr.pointee.sa_family == sa_family_t(AF_INET),
                  let ipv4 = numericHost(addr) else { continue }
            result.append(Interface(name: String(cString: namePtr),
                                    ipv4: ipv4,
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

    // MARK: - Tunnel interfaces

    /// Local (address, peer) pairs on loopback tunnel interfaces. Used for the
    /// host candidates and the addresses the Airlift screen prints.
    static func tunnelPairs() -> [TunnelPair] {
        var result: [TunnelPair] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return [] }
        defer { freeifaddrs(ifaddr) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let cur = ptr {
            defer { ptr = cur.pointee.ifa_next }
            guard let namePtr = cur.pointee.ifa_name else { continue }
            let name = String(cString: namePtr)
            guard isTunnelInterface(name),
                  let addr = cur.pointee.ifa_addr,
                  addr.pointee.sa_family == sa_family_t(AF_INET),
                  let local = numericHost(addr), isLoopbackRange(local) else { continue }
            var peer: String? = nil
            if let dst = cur.pointee.ifa_dstaddr,
               dst.pointee.sa_family == sa_family_t(AF_INET),
               let p = numericHost(dst), isLoopbackRange(p), p != local {
                peer = p
            }
            result.append(TunnelPair(local: local, peer: peer, iface: name))
        }
        return result
    }

    // MARK: - Route-verified state

    /// True when the loopback tunnel is up *and* the routing table agrees.
    ///
    /// Asks the route first. A point-to-point tunnel reaches its peer over a host
    /// route (LocalDevVPN's `10.7.1.1/32` -> peer `10.7.0.1/32`), so no
    /// interface's subnet contains the peer and the table is the only witness.
    ///
    /// `nil` from the table is not a refusal, so the interface evidence is kept
    /// rather than reporting a live tunnel as down.
    static func loopbackVPNUp() -> Bool {
        if let routed = routeCarriesTunnel() { return routed }
        return !tunnelPairs().isEmpty
    }

    private static func routeCarriesTunnel() -> Bool? {
        let target = tunnelPairs().compactMap { $0.peer }.first ?? canonicalTunnelPeer
        guard let source = routeSource(to: target),
              let iface = interfaces().first(where: { $0.ipv4 == source }) else { return nil }
        guard isTunnelInterface(iface.name) else { return false }
        // A full-tunnel VPN routes everything, so the peer must use a different
        // route than the default one.
        return routeSource(to: defaultRouteProbe) != source
    }

    /// The local address the kernel would send from when dialling `ip`, or nil
    /// when it has no route there.
    private static func routeSource(to ip: String) -> String? {
        var remote = sockaddr_in()
        remote.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        remote.sin_family = sa_family_t(AF_INET)
        remote.sin_port = in_port_t(UInt16(9).bigEndian)
        guard ip.withCString({ inet_pton(AF_INET, $0, &remote.sin_addr) }) == 1 else { return nil }

        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else { return nil }
        defer { close(fd) }

        let dialled = withUnsafePointer(to: remote) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard dialled == 0 else { return nil }

        var local = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let named = withUnsafeMutablePointer(to: &local) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(fd, $0, &length)
            }
        }
        guard named == 0, local.sin_addr.s_addr != 0 else { return nil }
        return withUnsafeMutablePointer(to: &local) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1, numericHost)
        }
    }

    // MARK: - Reported hosts

    static func tunnelIP() -> String? {
        for p in tunnelPairs() { if let peer = p.peer { return peer } }
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
}