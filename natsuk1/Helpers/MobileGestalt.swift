import Foundation
import CoreFoundation

final class MobileGestalt: @unchecked Sendable {
    static let shared = MobileGestalt()

    private typealias CopyAnswerFn = @convention(c) (CFString) -> Unmanaged<CFTypeRef>?
    private typealias BoolFn       = @convention(c) (CFString) -> Bool
    private typealias SInt32Fn     = @convention(c) (CFString) -> Int32
    private typealias SInt64Fn     = @convention(c) (CFString) -> Int64
    private typealias Float32Fn    = @convention(c) (CFString) -> Float32

    private var handle: UnsafeMutableRawPointer?
    private var copyAnswerFn: CopyAnswerFn?
    private var boolFn: BoolFn?
    private var sInt32Fn: SInt32Fn?
    private var sInt64Fn: SInt64Fn?
    private var float32Fn: Float32Fn?

    private(set) var loaded: Bool = false
    private(set) var loadError: String?

    private let storageKey = "natsuk1_mg_overrides"
    private var overrides: [String: String]

    private init() {
        self.overrides =
            (UserDefaults.standard.dictionary(forKey: storageKey) as? [String: String]) ?? [:]
        load()
    }

    private func load() {
        let path = "/usr/lib/libMobileGestalt.dylib"
        guard let h = dlopen(path, RTLD_NOW) else {
            loadError = "dlopen failed: \(String(cString: dlerror()))"
            return
        }
        handle = h
        if let s = dlsym(h, "MGCopyAnswer") {
            copyAnswerFn = unsafeBitCast(s, to: CopyAnswerFn.self)
        }
        if let s = dlsym(h, "MGGetBoolAnswer") {
            boolFn = unsafeBitCast(s, to: BoolFn.self)
        }
        if let s = dlsym(h, "MGGetSInt32Answer") {
            sInt32Fn = unsafeBitCast(s, to: SInt32Fn.self)
        }
        if let s = dlsym(h, "MGGetSInt64Answer") {
            sInt64Fn = unsafeBitCast(s, to: SInt64Fn.self)
        }
        if let s = dlsym(h, "MGGetFloat32Answer") {
            float32Fn = unsafeBitCast(s, to: Float32Fn.self)
        }
        loaded = copyAnswerFn != nil
        if !loaded { loadError = "MGCopyAnswer not found" }
    }

    func overrideValue(for key: String) -> String? {
        return overrides[key]
    }

    func setOverride(_ key: String, value: String?) {
        if let v = value, !v.isEmpty {
            overrides[key] = v
        } else {
            overrides.removeValue(forKey: key)
        }
        UserDefaults.standard.set(overrides, forKey: storageKey)
    }

    func clearAllOverrides() {
        overrides.removeAll()
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    var overrideCount: Int { overrides.count }
    var overrideKeys: [String] { overrides.keys.sorted() }

    func raw(_ key: String) -> CFTypeRef? {
        guard let f = copyAnswerFn else { return nil }
        return f(key as CFString)?.takeRetainedValue()
    }

    func string(_ key: String) -> String? {
        if let ov = overrides[key] { return ov }
        guard let v = raw(key) else { return nil }
        if let s = v as? String { return s }
        if let n = v as? NSNumber { return n.stringValue }
        if let d = v as? Data {
            return d.map { String(format: "%02x", $0) }.joined()
        }
        if let arr = v as? [Any] {
            return arr.map { "\($0)" }.joined(separator: ", ")
        }
        return "\(v)"
    }

    func bool(_ key: String) -> Bool? {
        if let ov = overrides[key] {
            if ov == "1" || ov.lowercased() == "true" || ov.lowercased() == "yes" { return true }
            if ov == "0" || ov.lowercased() == "false" || ov.lowercased() == "no" { return false }
        }
        if let f = boolFn { return f(key as CFString) }
        if let v = raw(key) as? NSNumber { return v.boolValue }
        return nil
    }

    func int(_ key: String) -> Int64? {
        if let ov = overrides[key], let n = Int64(ov) { return n }
        if let ov = overrides[key], ov.hasPrefix("0x"), let n = Int64(ov.dropFirst(2), radix: 16) { return n }
        if let f = sInt64Fn { return f(key as CFString) }
        if let f = sInt32Fn { return Int64(f(key as CFString)) }
        if let v = raw(key) as? NSNumber { return v.int64Value }
        return nil
    }

    func float(_ key: String) -> Float? {
        if let ov = overrides[key], let f = Float(ov) { return f }
        if let f = float32Fn { return f(key as CFString) }
        if let v = raw(key) as? NSNumber { return v.floatValue }
        return nil
    }

    func describe(_ key: String, kind: MobileGestaltCatalog.Key.Kind) -> String {
        let overridden = overrides[key] != nil
        let base: String
        switch kind {
        case .string: base = string(key) ?? "—"
        case .bool:   base = bool(key).map { $0 ? "true" : "false" } ?? "—"
        case .int:    base = int(key).map { "\($0)" } ?? "—"
        case .float:  base = float(key).map { String(format: "%.4f", $0) } ?? "—"
        }
        return overridden ? "\(base)  (override)" : base
    }
}

enum MobileGestaltCatalog {
    struct Key: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let kind: Kind
        enum Kind: String { case string, bool, int, float }
    }

    static let all: [Key] = [
        Key(name: "ProductType", kind: .string),
        Key(name: "ProductVersion", kind: .string),
        Key(name: "BuildVersion", kind: .string),
        Key(name: "MarketingName", kind: .string),
        Key(name: "UserAssignedDeviceName", kind: .string),
        Key(name: "DeviceName", kind: .string),
        Key(name: "ModelNumber", kind: .string),
        Key(name: "RegionCode", kind: .string),
        Key(name: "RegionInfo", kind: .string),
        Key(name: "SerialNumber", kind: .string),
        Key(name: "UniqueDeviceID", kind: .string),
        Key(name: "InternationalMobileEquipmentIdentity", kind: .string),
        Key(name: "MobileEquipmentIdentifier", kind: .string),
        Key(name: "IntegratedCircuitCardIdentifier", kind: .string),
        Key(name: "WiFiAddress", kind: .string),
        Key(name: "BluetoothAddress", kind: .string),
        Key(name: "EthernetMacAddress", kind: .string),
        Key(name: "BasebandVersion", kind: .string),
        Key(name: "BasebandChipId", kind: .int),
        Key(name: "BasebandSerialNumber", kind: .string),
        Key(name: "HWModel", kind: .string),
        Key(name: "CPUArchitecture", kind: .string),
        Key(name: "CPUType", kind: .int),
        Key(name: "BoardId", kind: .int),
        Key(name: "ChipID", kind: .int),
        Key(name: "DeviceSupportsApplePencil", kind: .bool),
        Key(name: "DeviceSupportsFaceTime", kind: .bool),
        Key(name: "HasBaseband", kind: .bool),
        Key(name: "HasBattery", kind: .bool),
        Key(name: "HasCellularTelephony", kind: .bool),
        Key(name: "IsSimulator", kind: .bool),
        Key(name: "PasswordProtected", kind: .bool),
        Key(name: "ActivationState", kind: .string),
        Key(name: "ActivationStateAcknowledged", kind: .bool),
        Key(name: "RegulatoryModelNumber", kind: .string),
        Key(name: "ReleaseType", kind: .string),
        Key(name: "SigningFuse", kind: .bool),
        Key(name: "SupportsExternalAccessory", kind: .bool),
        Key(name: "SupportsSiri", kind: .bool),
        Key(name: "SupportsTouchID", kind: .bool),
        Key(name: "SupportsFaceID", kind: .bool),
        Key(name: "BatteryCurrentCapacity", kind: .int),
        Key(name: "BatteryIsCharging", kind: .bool),
        Key(name: "BatteryIsFullyCharged", kind: .bool),
        Key(name: "DiskUsage", kind: .int),
        Key(name: "ScreenDimensions", kind: .string),
        Key(name: "FrontCameraCapturedMTF", kind: .float),
        Key(name: "RearCameraCapturedMTF", kind: .float),
        Key(name: "WifiChipset", kind: .string),
        Key(name: "WifiVendor", kind: .string),
        Key(name: "AirplaneMode", kind: .bool),
        Key(name: "AssistedGPS", kind: .bool),
    ]
}
