import Foundation

enum CarrierGuardError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        if case .message(let s) = self { return s }
        return nil
    }
}

enum CarrierConstants {
    static let product = "iPhone18,2"
    static let board = "V54AP"
    static let version = "27.0"
    static let build = "24A437"
    static let oper = "25001"
    static let carrierTarget = "/var/mobile/Library/Carrier Bundles/iPhone"
    static let carrierLinks = "/var/mobile/Library/Carrier Bundles"
}

struct CarrierTree {
    var dirs: Set<String> = []
    var files: [String: Data] = [:]
    var links: [String: String] = [:]

    func validate() throws {
        for n in dirs { try Self.safe(n) }
        for n in files.keys { try Self.safe(n) }
        for (n, t) in links {
            try Self.safe(n)
            if t.hasPrefix("/") {
                if !t.hasPrefix("/System/Library/Carrier Bundles/iPhone/") {
                    throw CarrierGuardError.message("link escapes: \(n)")
                }
            }
        }
    }

    static func safe(_ s: String) throws {
        if s.isEmpty || s.hasPrefix("/") || s.contains("..") || s.contains("\\") {
            throw CarrierGuardError.message("unsafe path: \(s)")
        }
    }

    func digest() -> String {
        var h = SHA256()
        for n in dirs.sorted() { h.update("D\0\(n)\0") }
        for (n, d) in files.sorted(by: { $0.key < $1.key }) {
            h.update("F\0\(n)\0")
            h.update(d)
        }
        for (n, t) in links.sorted(by: { $0.key < $1.key }) { h.update("L\0\(n)\0\(t)\0") }
        return h.finalize()
    }
}

struct SHA256 {
    private var ctx = [UInt32](repeating: 0, count: 8)
    private var buffer = [UInt8]()
    private var length: UInt64 = 0

    init() {
        ctx = [
            0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
            0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
        ]
    }

    mutating func update(_ s: String) { update(Array(s.utf8)) }
    mutating func update(_ d: Data) { update([UInt8](d)) }

    mutating func update(_ bytes: [UInt8]) {
        length += UInt64(bytes.count) * 8
        buffer.append(contentsOf: bytes)
        while buffer.count >= 64 {
            let block = Array(buffer.prefix(64))
            buffer.removeFirst(64)
            compress(block)
        }
    }

    mutating func finalize() -> String {
        buffer.append(0x80)
        while buffer.count % 64 != 56 { buffer.append(0) }
        var len = length.bigEndian
        withUnsafeBytes(of: &len) { buffer.append(contentsOf: $0) }
        while buffer.count >= 64 {
            let block = Array(buffer.prefix(64))
            buffer.removeFirst(64)
            compress(block)
        }
        var out = ""
        for v in ctx { out += String(format: "%08x", v) }
        return out
    }

    private mutating func compress(_ block: [UInt8]) {
        var w = [UInt32](repeating: 0, count: 64)
        for i in 0..<16 {
            w[i] = (UInt32(block[i*4]) << 24) |
                   (UInt32(block[i*4+1]) << 16) |
                   (UInt32(block[i*4+2]) << 8) |
                   UInt32(block[i*4+3])
        }
        for i in 16..<64 {
            let s0 = rotr(w[i-15], 7) ^ rotr(w[i-15], 18) ^ (w[i-15] >> 3)
            let s1 = rotr(w[i-2], 17) ^ rotr(w[i-2], 19) ^ (w[i-2] >> 10)
            w[i] = w[i-16] &+ s0 &+ w[i-7] &+ s1
        }
        var a = ctx[0], b = ctx[1], c = ctx[2], d = ctx[3]
        var e = ctx[4], f = ctx[5], g = ctx[6], h = ctx[7]
        let k: [UInt32] = [
            0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
            0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
            0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
            0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
            0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
            0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
            0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
            0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2
        ]
        for i in 0..<64 {
            let S1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
            let ch = (e & f) ^ (~e & g)
            let t1 = h &+ S1 &+ ch &+ k[i] &+ w[i]
            let S0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
            let mj = (a & b) ^ (a & c) ^ (b & c)
            let t2 = S0 &+ mj
            h = g; g = f; f = e; e = d &+ t1
            d = c; c = b; b = a; a = t1 &+ t2
        }
        ctx[0] = ctx[0] &+ a; ctx[1] = ctx[1] &+ b
        ctx[2] = ctx[2] &+ c; ctx[3] = ctx[3] &+ d
        ctx[4] = ctx[4] &+ e; ctx[5] = ctx[5] &+ f
        ctx[6] = ctx[6] &+ g; ctx[7] = ctx[7] &+ h
    }

    private func rotr(_ x: UInt32, _ n: UInt32) -> UInt32 {
        return (x >> n) | (x << (32 - n))
    }
}

func loadCarrierTree(from url: URL) throws -> CarrierTree {
    var tree = CarrierTree()
    let fm = FileManager.default
    guard let e = fm.enumerator(at: url, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else {
        return tree
    }
    let base = url.standardizedFileURL.path
    for case let item as URL in e {
        let full = item.standardizedFileURL.path
        guard full.hasPrefix(base + "/") else { continue }
        let rel = String(full.dropFirst(base.count + 1))
        let attrs = try fm.attributesOfItem(atPath: full)
        let type = attrs[.type] as? FileAttributeType
        if type == .typeDirectory {
            tree.dirs.insert(rel)
        } else if type == .typeSymbolicLink {
            let t = try fm.destinationOfSymbolicLink(atPath: full)
            tree.links[rel] = t
        } else {
            tree.files[rel] = try Data(contentsOf: item)
        }
    }
    return tree
}

func carrierPrepareTree(original: CarrierTree, donor: CarrierTree) throws -> (CarrierTree, [String]) {
    var out = original
    for (n, d) in donor.files { out.files[n] = d }
    out.dirs.formUnion(donor.dirs)
    var aliases: [String] = []
    let op = CarrierConstants.oper
    if out.links[op] != nil || out.dirs.contains(op) || out.files[op] != nil {
        aliases.append(op)
    }
    for n in original.links.keys where n.hasPrefix(op + "_") {
        aliases.append(n)
    }
    if aliases.isEmpty {
        aliases.append(op)
    }
    for a in aliases { out.links[a] = "CarrierLab.bundle" }
    return (out, aliases)
}
