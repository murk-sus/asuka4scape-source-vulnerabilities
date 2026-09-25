import SwiftUI
import UIKit

struct DeviceInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                row("Model", DeviceName.friendly())
                row("Identifier", machineID())
                row("Chip", DeviceName.chip())
                row("iOS", sysctlString("kern.osproductversion"))
                row("Build", sysctlString("kern.osversion"))
                row("RAM", ram())
                row("Architecture", arch())
                row("Locale", localeShort())
                row("Region", regionShort())
                row("Uptime", uptime())
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private func machineID() -> String {
        var sysinfo = utsname()
        uname(&sysinfo)
        return Mirror(reflecting: sysinfo.machine).children.reduce("") { id, el in
            guard let v = el.value as? Int8, v != 0 else { return id }
            return id + String(UnicodeScalar(UInt8(v)))
        }
    }

    private func sysctlString(_ name: String) -> String {
        var size = 0
        sysctlbyname(name, nil, &size, nil, 0)
        var buf = [CChar](repeating: 0, count: size)
        sysctlbyname(name, &buf, &size, nil, 0)
        let bytes = buf.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }

    private func ram() -> String {
        var size: UInt64 = 0
        var len = MemoryLayout<UInt64>.size
        if sysctlbyname("hw.memsize", &size, &len, nil, 0) != 0 { return "unknown" }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .memory)
    }

    private func arch() -> String {
        #if arch(arm64)
        return "arm64"
        #else
        return "unknown"
        #endif
    }

    private func localeShort() -> String {
        Locale.current.identifier
            .split(separator: "_")
            .first
            .map(String.init)?
            .uppercased() ?? "—"
    }

    private func regionShort() -> String {
        let region = Locale.current.region?.identifier ?? ""
        return region.isEmpty ? "—" : region.uppercased()
    }

    private func uptime() -> String {
        let t = ProcessInfo.processInfo.systemUptime
        let h = Int(t) / 3600
        let m = (Int(t) % 3600) / 60
        return "\(h)h \(m)m"
    }
}
