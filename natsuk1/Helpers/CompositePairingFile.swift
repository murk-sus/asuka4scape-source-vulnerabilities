import Foundation
struct PairingFileKind {
    let hasRemotePairing: Bool
    let hasLockdown: Bool
    let udid: String?
    var isUsable: Bool { hasRemotePairing || hasLockdown }
    static let none = PairingFileKind(hasRemotePairing: false, hasLockdown: false, udid: nil)
    static func of(path: String) -> PairingFileKind {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return .none }
        return of(data: data)
    }
    static func of(data: Data) -> PairingFileKind {
        guard !data.isEmpty,
              let parsed = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = parsed as? [String: Any]
        else { return .none }
        let ed25519 = { (key: String) in (dict[key] as? Data)?.count == 32 }
        let remote = ed25519("public_key") && ed25519("private_key")
            && (dict["identifier"] as? String)?.isEmpty == false
        let present = { (key: String) in
            (dict[key] as? Data)?.isEmpty == false || (dict[key] as? String)?.isEmpty == false
        }
        let lockdown = present("HostCertificate") && present("HostPrivateKey")
            && present("DeviceCertificate")
        let udid = (dict["UDID"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        return PairingFileKind(hasRemotePairing: remote, hasLockdown: lockdown, udid: udid)
    }
}
enum CompositePairingFile {
    private static let hostIDKey = "natsuk1LockdownHostID"
    private static let systemBUIDKey = "natsuk1LockdownSystemBUID"
    private static let recordUDIDKey = "natsuk1LockdownRecordUDID"
    enum BuildError: LocalizedError {
        case notAPlistDictionary(String)
        var errorDescription: String? {
            switch self {
            case let .notAPlistDictionary(what):
                return "The \(what) record isn't a plist dictionary."
            }
        }
    }
    static var hostID: String { persistentUUID(forKey: hostIDKey) }
    static var systemBUID: String { persistentUUID(forKey: systemBUIDKey) }
    private static func persistentUUID(forKey key: String) -> String {
        if let stored = UserDefaults.standard.string(forKey: key), !stored.isEmpty {
            return stored
        }
        let raw = UUID().uuidString
        UserDefaults.standard.set(raw, forKey: key)
        return raw
    }
    private static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    static var cachedLockdownURL: URL {
        documents.appendingPathComponent(".natsuk1_lockdown_record")
    }
    static var mergedURL: URL {
        documents.appendingPathComponent("ALTPairingFile.mobiledevicepairing")
    }
    static func cachedLockdownRecord(forUDID udid: String?) -> Data? {
        guard let udid, !udid.isEmpty,
              UserDefaults.standard.string(forKey: recordUDIDKey) == udid,
              let data = try? Data(contentsOf: cachedLockdownURL),
              !data.isEmpty
        else { return nil }
        return data
    }
    static func storeLockdownRecord(_ data: Data, forUDID udid: String?) {
        try? data.write(to: cachedLockdownURL, options: .atomic)
        UserDefaults.standard.set(udid ?? "", forKey: recordUDIDKey)
    }
    static func clearLockdownRecord() {
        try? FileManager.default.removeItem(at: cachedLockdownURL)
        UserDefaults.standard.removeObject(forKey: recordUDIDKey)
    }
    static func merge(lockdown: Data, rpPairing: Data, udid: String?) throws -> Data {
        var merged = try dictionary(from: lockdown, describing: "lockdown")
        for (key, value) in try dictionary(from: rpPairing, describing: "RPPairing") {
            merged[key] = value
        }
        if let udid, !udid.isEmpty, (merged["UDID"] as? String)?.isEmpty != false {
            merged["UDID"] = udid
        }
        return try PropertyListSerialization.data(fromPropertyList: merged, format: .xml, options: 0)
    }
    private static func dictionary(from data: Data, describing what: String) throws -> [String: Any] {
        let parsed = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let dict = parsed as? [String: Any] else {
            throw BuildError.notAPlistDictionary(what)
        }
        return dict
    }
}
