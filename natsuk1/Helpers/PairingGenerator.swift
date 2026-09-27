import Foundation

final class PairingGenerator {
    static let shared = PairingGenerator()
    private init() {}

    enum GeneratorError: LocalizedError {
        case missingFile(String)
        case notAPlist(String)
        case writeFailed(String)

        var errorDescription: String? {
            switch self {
            case .missingFile(let s): return "Pairing file missing: \(s)"
            case .notAPlist(let s): return "Pairing file is not a plist: \(s)"
            case .writeFailed(let s): return "Write failed: \(s)"
            }
        }
    }

    @discardableResult
    func generateMergedPairing(rppPath: String, outputPath: String) throws -> String {
        let fm = FileManager.default
        guard fm.fileExists(atPath: rppPath) else {
            throw GeneratorError.missingFile(rppPath)
        }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: rppPath)), !data.isEmpty else {
            throw GeneratorError.missingFile("empty or unreadable: \(rppPath)")
        }
        guard let plist = try? PropertyListSerialization.propertyList(
            from: data, options: [], format: nil) as? [String: Any] else {
            throw GeneratorError.notAPlist(rppPath)
        }
        guard !plist.isEmpty else {
            throw GeneratorError.notAPlist("empty plist: \(rppPath)")
        }

        let canonical = PairingController.syncCanonicalPairingFile(from: rppPath)
        if outputPath != canonical {
            do {
                try data.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
            } catch {
                throw GeneratorError.writeFailed(error.localizedDescription)
            }
        }
        return canonical
    }
}
