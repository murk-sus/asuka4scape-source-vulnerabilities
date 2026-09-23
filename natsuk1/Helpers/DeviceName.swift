import Foundation
import UIKit

enum DeviceName {

    static func friendly() -> String {
        let id = machineID()
        return map[id] ?? id
    }

    static func short() -> String {
        let name = friendly()
        if name.hasPrefix("iPhone ") {
            return String(name.dropFirst("iPhone ".count))
        }
        return name
    }

    static func chip() -> String {
        let id = machineID()
        return chipMap[id] ?? "unknown"
    }

    static func full() -> String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(friendly()) · iOS \(v.majorVersion).\(v.minorVersion)"
    }

    static func fullWithChip() -> String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(friendly()) · \(chip()) · iOS \(v.majorVersion).\(v.minorVersion)"
    }

    private static func machineID() -> String {
        var sysinfo = utsname()
        uname(&sysinfo)
        return Mirror(reflecting: sysinfo.machine).children.reduce("") { id, el in
            guard let v = el.value as? Int8, v != 0 else { return id }
            return id + String(UnicodeScalar(UInt8(v)))
        }
    }

    private static let map: [String: String] = [
        "iPhone11,2": "iPhone XS",
        "iPhone11,4": "iPhone XS Max",
        "iPhone11,6": "iPhone XS Max",
        "iPhone11,8": "iPhone XR",
        "iPhone12,1": "iPhone 11",
        "iPhone12,3": "iPhone 11 Pro",
        "iPhone12,5": "iPhone 11 Pro Max",
        "iPhone12,8": "iPhone SE (2nd gen)",
        "iPhone13,1": "iPhone 12 mini",
        "iPhone13,2": "iPhone 12",
        "iPhone13,3": "iPhone 12 Pro",
        "iPhone13,4": "iPhone 12 Pro Max",
        "iPhone14,2": "iPhone 13 Pro",
        "iPhone14,3": "iPhone 13 Pro Max",
        "iPhone14,4": "iPhone 13 mini",
        "iPhone14,5": "iPhone 13",
        "iPhone14,6": "iPhone SE (3rd gen)",
        "iPhone14,7": "iPhone 14",
        "iPhone14,8": "iPhone 14 Plus",
        "iPhone15,2": "iPhone 14 Pro",
        "iPhone15,3": "iPhone 14 Pro Max",
        "iPhone15,4": "iPhone 15",
        "iPhone15,5": "iPhone 15 Plus",
        "iPhone16,1": "iPhone 15 Pro",
        "iPhone16,2": "iPhone 15 Pro Max",
        "iPhone17,1": "iPhone 16 Pro",
        "iPhone17,2": "iPhone 16 Pro Max",
        "iPhone17,3": "iPhone 16",
        "iPhone17,4": "iPhone 16 Plus",
        "iPhone17,5": "iPhone 16e",
        "iPhone18,1": "iPhone 17 Pro",
        "iPhone18,2": "iPhone 17 Pro Max",
        "iPhone18,3": "iPhone 17",
        "iPhone18,4": "iPhone Air",
        "iPhone18,5": "iPhone 17e",
    ]

    private static let chipMap: [String: String] = [
        "iPhone11,2": "A12 Bionic",
        "iPhone11,4": "A12 Bionic",
        "iPhone11,6": "A12 Bionic",
        "iPhone11,8": "A12 Bionic",
        "iPhone12,1": "A13 Bionic",
        "iPhone12,3": "A13 Bionic",
        "iPhone12,5": "A13 Bionic",
        "iPhone12,8": "A13 Bionic",
        "iPhone13,1": "A14 Bionic",
        "iPhone13,2": "A14 Bionic",
        "iPhone13,3": "A14 Bionic",
        "iPhone13,4": "A14 Bionic",
        "iPhone14,2": "A15 Bionic",
        "iPhone14,3": "A15 Bionic",
        "iPhone14,4": "A15 Bionic",
        "iPhone14,5": "A15 Bionic",
        "iPhone14,6": "A15 Bionic",
        "iPhone14,7": "A15 Bionic",
        "iPhone14,8": "A15 Bionic",
        "iPhone15,2": "A16 Bionic",
        "iPhone15,3": "A16 Bionic",
        "iPhone15,4": "A16 Bionic",
        "iPhone15,5": "A16 Bionic",
        "iPhone16,1": "A17 Pro",
        "iPhone16,2": "A17 Pro",
        "iPhone17,1": "A18 Pro",
        "iPhone17,2": "A18 Pro",
        "iPhone17,3": "A18",
        "iPhone17,4": "A18",
        "iPhone17,5": "A18",
        "iPhone18,1": "A19 Pro",
        "iPhone18,2": "A19 Pro",
        "iPhone18,3": "A19",
        "iPhone18,4": "A19 Pro",
        "iPhone18,5": "A19",
    ]
}
