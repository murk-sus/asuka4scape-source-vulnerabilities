import SwiftUI
import UIKit

struct DeviceInfoView: View {
    var body: some View {
        List {
            Section {
                row("Model", DeviceName.friendly())
                row("Identifier", DeviceName.machineID())
                row("Chip", DeviceName.chip())
            } header: { Label("Hardware", systemImage: "cpu") }

            Section {
                row("iOS", sysctlString("kern.osproductversion"))
                row("Build", sysctlString("kern.osversion"))
                row("Architecture", arch())
            } header: { Label("Software", systemImage: "gear") }

            Section {
                row("RAM", ram())
                row("Uptime", uptime())
            } header: { Label("Resources", systemImage: "memorychip") }

            Section {
                row("Locale", localeShort())
                row("Region", regionShort())
            } header: { Label("Locale", systemImage: "globe") }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Device")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.green)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private func sysctlString(_ name: String) -> String {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return "—" }
        var buf = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buf, &size, nil, 0) == 0 else { return "—" }
        let bytes = buf.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        let text = String(decoding: bytes, as: UTF8.self)
        return text.isEmpty ? "—" : text
    }

    private func ram() -> String {
        var size: UInt64 = 0
        var len = MemoryLayout<UInt64>.size
        guard sysctlbyname("hw.memsize", &size, &len, nil, 0) == 0 else { return "—" }
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
        Locale.current.identifier.split(separator: "_").first.map(String.init)?.uppercased() ?? "—"
    }

    private func regionShort() -> String {
        let region = Locale.current.region?.identifier ?? ""
        return region.isEmpty ? "—" : region.uppercased()
    }

    private func uptime() -> String {
        let t = ProcessInfo.processInfo.systemUptime
        guard t.isFinite, t >= 0, t < Double(Int.max) else { return "—" }
        let seconds = Int(t)
        return "\(seconds / 3600)h \((seconds % 3600) / 60)m"
    }
}
