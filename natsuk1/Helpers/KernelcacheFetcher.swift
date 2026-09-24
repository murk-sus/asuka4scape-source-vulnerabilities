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
                    completion(.failure(NSError(
                        domain: "KernelcacheFetcher", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "grab_kernelcache failed"]
                    )))
                }
                return
            }

            do {
                try self.processFile(at: rawURL, outputURL: outURL)
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

            if FileManager.default.fileExists(atPath: dir.path) {
                try? FileManager.default.removeItem(at: dir)
            }
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

            let ok = grab_images(dir.path)

            guard ok else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(
                        domain: "KernelcacheFetcher", code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "grab_images failed"]
                    )))
                }
                return
            }

            if let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
                for file in files {
                    let tmp = file.appendingPathExtension("tmp")
                    do {
                        try self.processFile(at: file, outputURL: tmp)
                        try? FileManager.default.removeItem(at: file)
                        try? FileManager.default.moveItem(at: tmp, to: file)
                    } catch {
                        try? FileManager.default.removeItem(at: tmp)
                    }
                }
            }

            DispatchQueue.main.async { completion(.success(dir)) }
        }
    }

    private func processFile(at input: URL, outputURL: URL) throws {
        let raw = try Data(contentsOf: input)

        if isMachO(raw) {
            try raw.write(to: outputURL)
            return
        }

        if let decoded = decompressLZFSE(raw) {
            try decoded.write(to: outputURL)
            return
        }

        try raw.write(to: outputURL)
    }

    private func decompressLZFSE(_ data: Data) -> Data? {
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
        let payload = data.subdata(in: offset..<data.count)

        let dstSize = 256 * 1024 * 1024
        let dst = UnsafeMutablePointer<UInt8>.allocate(capacity: dstSize)
        defer { dst.deallocate() }

        let decoded = payload.withUnsafeBytes { (src: UnsafeRawBufferPointer) -> Int in
            guard let srcPtr = src.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return compression_decode_buffer(
                dst, dstSize,
                srcPtr, payload.count,
                nil,
                COMPRESSION_LZFSE
            )
        }

        guard decoded > 0 else { return nil }
        return Data(bytes: dst, count: decoded)
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
}
