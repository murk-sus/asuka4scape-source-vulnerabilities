import Foundation

final class KernelcacheFetcher {
    static let shared = KernelcacheFetcher()
    private init() {}

    func fetch(completion: @escaping (Result<URL, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("kernelcache")

            if FileManager.default.fileExists(atPath: dest.path) {
                try? FileManager.default.removeItem(at: dest)
            }

            let ok = grab_kernelcache(dest.path)

            DispatchQueue.main.async {
                if ok {
                    completion(.success(dest))
                } else {
                    completion(.failure(NSError(
                        domain: "KernelcacheFetcher",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "grab_kernelcache failed"]
                    )))
                }
            }
        }
    }

    func fetchImages(completion: @escaping (Result<URL, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("images", isDirectory: true)

            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

            let ok = grab_images(dir.path)

            DispatchQueue.main.async {
                if ok {
                    completion(.success(dir))
                } else {
                    completion(.failure(NSError(
                        domain: "KernelcacheFetcher",
                        code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "grab_images failed"]
                    )))
                }
            }
        }
    }
}
