import SwiftUI

struct DeviceInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                row("Model", DeviceName.friendly())
                row("Identifier", machineID())
                row("Chip", DeviceName.chip())
                row("iOS", sysctl("kern.osproductversion"))
                row("Build", sysctl("kern.osversion"))
                row("RAM", ram())
                row("Architecture", arch())
                row("Locale", Locale.current.identifier)
                row("Uptime", uptime())
            }
            .navigationTitle("Device")
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

    private func sysctl(_ name: String) -> String {
        var size = 0
        sysctlbyname(name, nil, &size, nil, 0)
        var buf = [CChar](repeating: 0, count: size)
        sysctlbyname(name, &buf, &size, nil, 0)
        return String(cString: buf)
    }

    private func ram() -> String {
        let bytes = Int64(sysctl("hw.memsize")) ?? 0
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .memory)
    }

    private func arch() -> String {
        #if arch(arm64)
        return "arm64"
        #else
        return "unknown"
        #endif
    }

    private func uptime() -> String {
        let t = ProcessInfo.processInfo.systemUptime
        let h = Int(t) / 3600
        let m = (Int(t) % 3600) / 60
        return "\(h)h \(m)m"
    }
}
