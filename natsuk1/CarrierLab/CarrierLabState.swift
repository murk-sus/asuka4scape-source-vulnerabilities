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
        var aliases: [String]?
    }

    @Published private(set) var session: Session?
    @Published private(set) var airliftOK: Bool = false
    @Published private(set) var airliftMessage: String = "checking..."
    @Published private(set) var resourcesOK: Bool = false
    @Published private(set) var busy: Bool = false
    @Published private(set) var logText: String = ""

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
        let write = {
            self.session = s
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            enc.dateEncodingStrategy = .iso8601
            if let d = try? enc.encode(s) {
                try? d.write(to: self.stateURL, options: .atomic)
            }
        }
        if Thread.isMainThread { write() }
        else { DispatchQueue.main.async(execute: write) }
    }

    func clear() {
        let write = {
            self.session = nil
            try? FileManager.default.removeItem(at: self.stateURL)
        }
        if Thread.isMainThread { write() }
        else { DispatchQueue.main.async(execute: write) }
    }

    func hasBackup() -> Bool {
        guard let s = session, let p = s.originalBackupPath else { return false }
        return FileManager.default.fileExists(atPath: p)
    }

    func setAirlift(ok: Bool, message: String) {
        let write = {
            self.airliftOK = ok
            self.airliftMessage = message
        }
        if Thread.isMainThread { write() }
        else { DispatchQueue.main.async(execute: write) }
    }

    func setResources(_ ok: Bool) {
        let write = { self.resourcesOK = ok }
        if Thread.isMainThread { write() }
        else { DispatchQueue.main.async(execute: write) }
    }

    func setBusy(_ v: Bool) {
        let write = { self.busy = v }
        if Thread.isMainThread { write() }
        else { DispatchQueue.main.async(execute: write) }
    }

    func appendLog(_ s: String) {
        let write = {
            self.logText += s + "\n"
            if self.logText.count > 20000 {
                self.logText = String(self.logText.suffix(15000))
            }
        }
        if Thread.isMainThread { write() }
        else { DispatchQueue.main.async(execute: write) }
    }

    func clearLog() {
        let write = { self.logText = "" }
        if Thread.isMainThread { write() }
        else { DispatchQueue.main.async(execute: write) }
    }

    func backupURL() -> URL { backupDir }
    func rootURL() -> URL { root }
}
