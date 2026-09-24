import Foundation
import Combine

final class OffsetsStore: ObservableObject {
    static let shared = OffsetsStore()

    struct Group: Codable {
        let title: String
        let items: [String]
    }

    private struct File: Codable {
        let groups: [Group]
        let defaults: [String: String]
    }

    private static let file: File = {
        guard let url = Bundle.main.url(forResource: "Offsets", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let parsed = try? JSONDecoder().decode(File.self, from: data)
        else { return File(groups: [], defaults: [:]) }
        return parsed
    }()

    static var groups: [Group] { file.groups }
    static var defaults: [String: String] { file.defaults }

    @Published var values: [String: String] = [:]

    private let storageKey = "natsuk1_offsets_v1"

    private init() { load() }

    func load() {
        let saved = UserDefaults.standard.dictionary(forKey: storageKey) as? [String: String]
        var merged = Self.defaults
        if let saved = saved {
            for (k, v) in saved { merged[k] = v }
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
