import Foundation
import Combine

@MainActor
final class OffsetsStore: ObservableObject {
    static let shared = OffsetsStore()

    struct Group: Codable {
        let title: String
        let items: [String]
    }

    struct VersionEntry: Codable {
        let file: String
        let device: String
        let deviceName: String
        let chip: String
        let ios: String
        let build: String
        let verified: Bool
    }

    struct Index: Codable {
        let versions: [VersionEntry]
    }

    private struct File: Codable {
        let groups: [Group]
        let defaults: [String: String]
    }

    nonisolated private static let bundled: File? = {
        guard let fileURL = resolveActiveFileURL() else { return nil }
        guard let fileData = try? Data(contentsOf: fileURL),
              let parsed = try? JSONDecoder().decode(File.self, from: fileData)
        else { return nil }
        return parsed
    }()

    nonisolated static var groups: [Group] { bundled?.groups ?? [] }
    nonisolated static var defaults: [String: String] { bundled?.defaults ?? [:] }

    nonisolated static var activeVersion: VersionEntry? {
        resolveActiveEntry()
    }

    nonisolated private static func loadIndex() -> Index? {
        guard let url = Bundle.main.url(forResource: "index", withExtension: "json", subdirectory: "Offsets"),
              let data = try? Data(contentsOf: url),
              let index = try? JSONDecoder().decode(Index.self, from: data)
        else { return nil }
        return index
    }

    nonisolated private static func resolveActiveEntry() -> VersionEntry? {
        guard let index = loadIndex() else { return nil }
        let device = DeviceName.machineID()
        let v = ProcessInfo.processInfo.operatingSystemVersion
        let ios = "\(v.majorVersion).\(v.minorVersion)"
        return index.versions.first(where: { $0.device == device && $0.ios == ios })
            ?? index.versions.first(where: { $0.device == device })
    }

    nonisolated private static func resolveActiveFileURL() -> URL? {
        guard let entry = resolveActiveEntry() else { return nil }
        let parts = entry.file.split(separator: ".", maxSplits: 1).map(String.init)
        let name = parts.first ?? entry.file
        let ext  = parts.count > 1 ? parts[1] : "json"
        return Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Offsets")
    }

    @Published var values: [String: String] = [:]

    private let storageKey = "natsuk1_offsets_v2"

    private init() { load() }

    func load() {
        let saved = UserDefaults.standard.dictionary(forKey: storageKey) as? [String: String]
        var merged = Self.defaults
        if let saved = saved {
            for (k, v) in saved where merged[k] != nil { merged[k] = v }
        }
        values = merged
        if saved == nil { save() }
    }

    func save() {
        UserDefaults.standard.set(values, forKey: storageKey)
    }

    func reset() {
        values = Self.defaults
        save()
    }

    func resetOne(_ name: String) {
        values[name] = Self.defaults[name] ?? "0x0"
        save()
    }

    func update(_ name: String, value: String) {
        values[name] = value
        save()
    }

    func value(for name: String) -> String {
        values[name] ?? Self.defaults[name] ?? "0x0"
    }

    func filledCount() -> Int {
        values.filter { $0.value != "0x0" && !$0.value.isEmpty }.count
    }

    func totalCount() -> Int {
        Self.groups.reduce(0) { $0 + $1.items.count }
    }
}
