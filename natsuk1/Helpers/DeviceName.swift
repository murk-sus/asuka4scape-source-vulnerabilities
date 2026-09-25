import Foundation
import UIKit

enum DeviceName {

    private struct Device {
        let id: String
        let name: String
        let chip: String
    }

    private static let devices: [Device] = [
        Device(id: "iPhone11,2", name: "iPhone XS",           chip: "A12 Bionic"),
        Device(id: "iPhone11,4", name: "iPhone XS Max",       chip: "A12 Bionic"),
        Device(id: "iPhone11,6", name: "iPhone XS Max",       chip: "A12 Bionic"),
        Device(id: "iPhone11,8", name: "iPhone XR",           chip: "A12 Bionic"),
        Device(id: "iPhone12,1", name: "iPhone 11",           chip: "A13 Bionic"),
        Device(id: "iPhone12,3", name: "iPhone 11 Pro",       chip: "A13 Bionic"),
        Device(id: "iPhone12,5", name: "iPhone 11 Pro Max",   chip: "A13 Bionic"),
        Device(id: "iPhone12,8", name: "iPhone SE (2nd gen)", chip: "A13 Bionic"),
        Device(id: "iPhone13,1", name: "iPhone 12 mini",      chip: "A14 Bionic"),
        Device(id: "iPhone13,2", name: "iPhone 12",           chip: "A14 Bionic"),
        Device(id: "iPhone13,3", name: "iPhone 12 Pro",       chip: "A14 Bionic"),
        Device(id: "iPhone13,4", name: "iPhone 12 Pro Max",   chip: "A14 Bionic"),
        Device(id: "iPhone14,2", name: "iPhone 13 Pro",       chip: "A15 Bionic"),
        Device(id: "iPhone14,3", name: "iPhone 13 Pro Max",   chip: "A15 Bionic"),
        Device(id: "iPhone14,4", name: "iPhone 13 mini",      chip: "A15 Bionic"),
        Device(id: "iPhone14,5", name: "iPhone 13",           chip: "A15 Bionic"),
        Device(id: "iPhone14,6", name: "iPhone SE (3rd gen)", chip: "A15 Bionic"),
        Device(id: "iPhone14,7", name: "iPhone 14",           chip: "A15 Bionic"),
        Device(id: "iPhone14,8", name: "iPhone 14 Plus",      chip: "A15 Bionic"),
        Device(id: "iPhone15,2", name: "iPhone 14 Pro",       chip: "A16 Bionic"),
        Device(id: "iPhone15,3", name: "iPhone 14 Pro Max",   chip: "A16 Bionic"),
        Device(id: "iPhone15,4", name: "iPhone 15",           chip: "A16 Bionic"),
        Device(id: "iPhone15,5", name: "iPhone 15 Plus",      chip: "A16 Bionic"),
        Device(id: "iPhone16,1", name: "iPhone 15 Pro",       chip: "A17 Pro"),
        Device(id: "iPhone16,2", name: "iPhone 15 Pro Max",   chip: "A17 Pro"),
        Device(id: "iPhone17,1", name: "iPhone 16 Pro",       chip: "A18 Pro"),
        Device(id: "iPhone17,2", name: "iPhone 16 Pro Max",   chip: "A18 Pro"),
        Device(id: "iPhone17,3", name: "iPhone 16",           chip: "A18"),
        Device(id: "iPhone17,4", name: "iPhone 16 Plus",      chip: "A18"),
        Device(id: "iPhone17,5", name: "iPhone 16e",          chip: "A18"),
        Device(id: "iPhone18,1", name: "iPhone 17 Pro",       chip: "A19 Pro"),
        Device(id: "iPhone18,2", name: "iPhone 17 Pro Max",   chip: "A19 Pro"),
        Device(id: "iPhone18,3", name: "iPhone 17",           chip: "A19"),
        Device(id: "iPhone18,4", name: "iPhone Air",          chip: "A19 Pro"),
        Device(id: "iPhone18,5", name: "iPhone 17e",          chip: "A19"),
    ]

    private static let byID: [String: Device] = Dictionary(
        uniqueKeysWithValues: devices.map { ($0.id, $0) }
    )

    static func friendly() -> String {
        let id = machineID()
        return byID[id]?.name ?? id
    }

    static func short() -> String {
        let name = friendly()
        if name.hasPrefix("iPhone ") {
            return String(name.dropFirst("iPhone ".count))
        }
        return name
    }

    static func chip() -> String {
        byID[machineID()]?.chip ?? "unknown"
    }

    static func full() -> String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(friendly()) · iOS \(v.majorVersion).\(v.minorVersion)"
    }

    static func fullWithChip() -> String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(friendly()) · \(chip()) · iOS \(v.majorVersion).\(v.minorVersion)"
    }

    static func machineID() -> String {
        var info = utsname()
        uname(&info)
        return Mirror(reflecting: info.machine).children.reduce("") { id, el in
            guard let v = el.value as? Int8, v != 0 else { return id }
            return id + String(UnicodeScalar(UInt8(v)))
        }
    }
}
