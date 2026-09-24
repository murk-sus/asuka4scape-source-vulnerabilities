import Foundation
import UIKit

final class KernelcacheFetcher {

    static let shared = KernelcacheFetcher()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        session = URLSession(configuration: config)
    }

    func fetch(completion: @escaping (Result<URL, Error>) -> Void) {
        let device = DeviceName.machineID()
        let build = sysctlString("kern.osversion")

        guard !build.isEmpty else {
            completion(.failure(NSError(domain: "KernelcacheFetcher", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to read kernel build"])))
            return
        }

        fetchKernelcacheURL(device: device, build: build) { [weak self] result in
            switch result {
            case .success(let url):
                self?.download(from: url, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func fetchKernelcacheURL(device: String, build: String, completion: @escaping (Result<URL, Error>) -> Void) {
        let osKey = "iOS;\(build)"
        let encoded = osKey.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? osKey
        let urlString = "https://api.appledb.dev/ios/\(encoded).json"

        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "KernelcacheFetcher", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid AppleDB URL"])))
            return
        }

        session.dataTask(with: url) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "KernelcacheFetcher", code: -3, userInfo: [NSLocalizedDescriptionKey: "Empty AppleDB response"])))
                return
            }

            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let sources = json?["sources"] as? [[String: Any]] else {
                    completion(.failure(NSError(domain: "KernelcacheFetcher", code: -4, userInfo: [NSLocalizedDescriptionKey: "No sources in AppleDB response"])))
                    return
                }

                for source in sources {
                    guard let type = source["type"] as? String, type == "ipsw" else { continue }
                    guard let link = source["link"] as? String, let ipswURL = URL(string: link) else { continue }
                    if self.matchesDevice(source: source, device: device) {
                        completion(.success(ipswURL))
                        return
                    }
                }

                if let first = sources.first(where: { ($0["type"] as? String) == "ipsw" }),
                   let link = first["link"] as? String,
                   let ipswURL = URL(string: link) {
                    completion(.success(ipswURL))
                    return
                }

                completion(.failure(NSError(domain: "KernelcacheFetcher", code: -5, userInfo: [NSLocalizedDescriptionKey: "No IPSW source found"])))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    private func matchesDevice(source: [String: Any], device: String) -> Bool {
        guard let devices = source["devices"] as? [String] else { return false }
        return devices.contains(device)
    }

    private func download(from remoteURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        let fileName = remoteURL.lastPathComponent
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        session.downloadTask(with: remoteURL) { location, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let location = location else {
                completion(.failure(NSError(domain: "KernelcacheFetcher", code: -6, userInfo: [NSLocalizedDescriptionKey: "Download returned no file"])))
                return
            }

            do {
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.moveItem(at: location, to: destination)
                completion(.success(destination))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    private func sysctlString(_ name: String) -> String {
        var size = 0
        sysctlbyname(name, nil, &size, nil, 0)
        guard size > 0 else { return "" }
        var buf = [CChar](repeating: 0, count: size)
        sysctlbyname(name, &buf, &size, nil, 0)
        return String(cString: buf)
    }
}
