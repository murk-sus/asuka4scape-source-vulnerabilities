import Foundation
import Combine

final class CarrierLabState: ObservableObject, @unchecked Sendable {
    static let shared = CarrierLabState()

    enum Status: String, Codable { case clean, placing, placed, finished, failed }

    struct Session: Codable {
        var status: Status
        var startedAt: Date
        var carrierBundlePath: String?
        var originalBackupPath: String?
        var ipccTriggerPath: String?
        var lastError: String?
    }

    @Published private(set) var session: Session?

    private let root: URL
    private let stateURL: URL
    private let backupDir: URL

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        root = docs.appendingPathComponent("carrierlab", isDirectory: true)
        stateURL = root.appendingPathComponent("state.json")
        backupDir = root.appendingPathComponent("backup", isDirectory: true)
        try? FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: stateURL),
              let s = try? JSONDecoder().decode(Session.self, from: data) else {
            session = nil
            return
        }
        session = s
    }

    func save(_ s: Session) {
        session = s
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        if let d = try? enc.encode(s) { try? d.write(to: stateURL, options: .atomic) }
    }

    func clear() {
        session = nil
        try? FileManager.default.removeItem(at: stateURL)
    }

    func hasBackup() -> Bool {
        guard let s = session, let p = s.originalBackupPath else { return false }
        return FileManager.default.fileExists(atPath: p)
    }

    func backupURL() -> URL { backupDir }
    func rootURL() -> URL { root }
}
