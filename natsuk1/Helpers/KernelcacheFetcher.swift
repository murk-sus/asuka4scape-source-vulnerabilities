import Foundation
import Compression

final class KernelcacheFetcher {

    static let shared = KernelcacheFetcher()
    private init() {}

    private var documentsURL: URL {
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents", isDirectory: true)
    }

    func fetch(completion: @escaping (Result<URL, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let docs = self.documentsURL
            let rawURL = docs.appendingPathComponent("kernelcache.raw")
            let outURL = docs.appendingPathComponent("kernelcache")

            if FileManager.default.fileExists(atPath: rawURL.path) {
                try? FileManager.default.removeItem(at: rawURL)
            }
            if FileManager.default.fileExists(atPath: outURL.path) {
                try? FileManager.default.removeItem(at: outURL)
            }

            let ok = grab_kernelcache(rawURL.path)
            guard ok else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "KernelcacheFetcher", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "grab_kernelcache failed"])))
                }
                return
            }

            do {
                _ = try self.decompress(input: rawURL, output: outURL)
                try? FileManager.default.removeItem(at: rawURL)
                DispatchQueue.main.async { completion(.success(outURL)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    func fetchImages(completion: @escaping (Result<URL, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let dir = self.documentsURL.appendingPathComponent("images", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

            let ok = grab_images(dir.path)

            DispatchQueue.main.async {
                if ok {
                    completion(.success(dir))
                } else {
                    completion(.failure(NSError(domain: "KernelcacheFetcher", code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "grab_images failed"])))
                }
            }
        }
    }

    private func decompress(input: URL, output: URL) throws -> Int {
        let raw = try Data(contentsOf: input)

        if isMachO(raw) {
            try raw.write(to: output)
            return raw.count
        }

        guard let lzfse = extractLZFSEPayload(from: raw) else {
            throw NSError(domain: "KernelcacheFetcher", code: -3,
                          userInfo: [NSLocalizedDescriptionKey: "No LZFSE payload found"])
        }

        var dstSize = lzfse.count * 4
        let maxSize = 512 * 1024 * 1024

        while dstSize <= maxSize {
            let dst = UnsafeMutablePointer<UInt8>.allocate(capacity: dstSize)
            defer { dst.deallocate() }

            let decoded = lzfse.withUnsafeBytes { (src: UnsafeRawBufferPointer) -> Int in
                guard let srcPtr = src.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return compression_decode_buffer(dst, dstSize, srcPtr, lzfse.count, nil, COMPRESSION_LZFSE)
            }

            if decoded > 0 {
                let data = Data(bytes: dst, count: decoded)
                try data.write(to: output)
                return decoded
            }

            dstSize *= 2
        }

        throw NSError(domain: "KernelcacheFetcher", code: -4,
                      userInfo: [NSLocalizedDescriptionKey: "LZFSE decompression failed"])
    }

    private func isMachO(_ data: Data) -> Bool {
        guard data.count >= 4 else { return false }
        let magic = data.withUnsafeBytes { $0.load(as: UInt32.self) }
        switch magic {
        case 0xFEEDFACF, 0xCFFAEDFE, 0xFEEDFACE, 0xCEFAEDFE, 0xCAFEBABE, 0xBEBAFECA:
            return true
        default:
            return false
        }
    }

    private func extractLZFSEPayload(from data: Data) -> Data? {
        let magics: [[UInt8]] = [
            [0x62, 0x76, 0x78, 0x32],
            [0x62, 0x76, 0x78, 0x6E],
            [0x62, 0x76, 0x78, 0x2D],
            [0x62, 0x76, 0x78, 0x31],
        ]

        var bestOffset: Int? = nil

        for magic in magics {
            let needle = Data(magic)
            if let range = data.range(of: needle) {
                if bestOffset == nil || range.lowerBound < bestOffset! {
                    bestOffset = range.lowerBound
                }
            }
        }

        guard let offset = bestOffset else { return nil }
        return data.subdata(in: offset..<data.count)
    }
}
