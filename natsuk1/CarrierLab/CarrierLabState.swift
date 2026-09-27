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
        var slots: [String]?
    }

    @Published private(set) var session: Session?
    @Published private(set) var airliftOK: Bool = false
    @Published private(set) var airliftMessage: String = "Checking..."
    @Published private(set) var resourcesOK: Bool = false
    @Published private(set) var busy: Bool = false
    @Published private(set) var logText: String = ""
    @Published private(set) var slots: [String] = CarrierLabBridge.defaultSlots

    private let root: URL
    private let stateURL: URL
    private let backupDir: URL
    private let slotsKey = "natsuk1_carrierlab_slots"

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        root = docs.appendingPathComponent("carrierlab", isDirectory: true)
        stateURL = root.appendingPathComponent("state.json")
        backupDir = root.appendingPathComponent("backup", isDirectory: true)
        try? FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
        if let stored = UserDefaults.standard.array(forKey: slotsKey) as? [String], !stored.isEmpty {
            slots = stored
        }
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: stateURL),
              let s = try? JSONDecoder().decode(Session.self, from: data) else {
            DispatchQueue.main.async { self.session = nil }
            return
        }
        DispatchQueue.main.async { self.session = s }
    }

    func save(_ s: Session) {
        DispatchQueue.main.async {
            self.session = s
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            enc.dateEncodingStrategy = .iso8601
            if let d = try? enc.encode(s) {
                try? d.write(to: self.stateURL, options: .atomic)
            }
        }
    }

    func clear() {
        DispatchQueue.main.async {
            self.session = nil
            try? FileManager.default.removeItem(at: self.stateURL)
        }
    }

    func hasBackup() -> Bool {
        guard let s = session, let p = s.originalBackupPath else { return false }
        return FileManager.default.fileExists(atPath: p)
    }

    func setAirlift(ok: Bool, message: String) {
        DispatchQueue.main.async {
            self.airliftOK = ok
            self.airliftMessage = message
        }
    }

    func setResources(_ ok: Bool) {
        DispatchQueue.main.async { self.resourcesOK = ok }
    }

    func setBusy(_ v: Bool) {
        DispatchQueue.main.async { self.busy = v }
    }

    func setSlots(_ v: [String]) {
        let cleaned = v.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let unique = cleaned.reduce(into: [String]()) { acc, s in if !acc.contains(s) { acc.append(s) } }
        DispatchQueue.main.async {
            self.slots = unique.isEmpty ? CarrierLabBridge.defaultSlots : unique
            UserDefaults.standard.set(self.slots, forKey: self.slotsKey)
        }
    }

    func appendLog(_ s: String) {
        DispatchQueue.main.async {
            self.logText += s + "\n"
            if self.logText.count > 20000 { self.logText = String(self.logText.suffix(15000)) }
        }
    }

    func clearLog() {
        DispatchQueue.main.async { self.logText = "" }
    }

    func backupURL() -> URL { backupDir }
}
