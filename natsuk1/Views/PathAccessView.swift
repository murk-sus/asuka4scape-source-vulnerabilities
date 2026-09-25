import SwiftUI
import UIKit

struct PathAccessView: View {
    struct PathResult: Identifiable {
        let id = UUID()
        let path: String
        let exists: Bool
        let isDirectory: Bool
        let readable: Bool
        let writable: Bool
        let size: Int64?
    }

    @State private var results: [PathResult] = []
    @State private var busy = false

    private let paths: [String] = [
        "/usr/lib/libMobileGestalt.dylib",
        "/System/Library/PrivateFrameworks/MobileGestalt.framework",
        "/System/Library/PrivateFrameworks/MobileGestalt.framework/MobileGestalt",
        "/System/Library/PrivateFrameworks/MobileGestalt.framework/Resources",
        "/System/Library/CoreServices/SystemVersion.plist",
        "/System/Library/CoreServices/SystemVersionCompat.plist",
        "/var/mobile/Library/Preferences/com.apple.MobileGestalt.plist",
        "/var/mobile/Library/Caches/com.apple.MobileGestalt.plist",
        "/var/mobile/Library/Preferences/.GlobalPreferences.plist",
        "/var/mobile/Library/Preferences/com.apple.springboard.plist",
        "/var/mobile/Library/Caches",
        "/var/mobile/Library",
        "/var/mobile/Media",
        "/var/mobile/Containers/Data/Application",
        "/var/mobile/Containers/Data/System",
        "/var/mobile/Containers/Shared/AppGroup",
        "/var/containers/Bundle/Application",
        "/var/containers/Shared/SystemGroup",
        "/private/var/mobile",
        "/private/var/mobile/Library",
        "/private/var/containers/Shared/SystemGroup",
        "/System/Library",
        "/System/Library/Frameworks",
        "/System/Library/PrivateFrameworks",
        "/System/Library/PrivateFrameworks/AirTrafficDevice.framework",
        "/System/Library/PrivateFrameworks/AirTrafficHost.framework",
        "/System/Library/Caches/com.apple.kernelcaches",
        "/System/Library/Kernels",
        "/usr/lib",
        "/usr/libexec",
        "/usr/bin",
        "/bin",
        "/sbin",
        "/etc",
        "/private/etc",
        "/var/jb",
        "/var/jb/usr/bin",
        NSHomeDirectory(),
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path,
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0].path,
        NSTemporaryDirectory(),
    ]

    var body: some View {
        List {
            Section {
                Button {
                    scan()
                } label: {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text(busy ? "Scanning..." : "Run Scan")
                        Spacer(minLength: 8)
                        if busy { ProgressView().scaleEffect(0.8) }
                    }
                }
                .disabled(busy)
            }

            Section {
                ForEach(results) { r in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(r.path)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(r.exists ? .primary : .secondary)
                            .lineLimit(2)
                        HStack(spacing: 6) {
                            badge(r.exists ? "exists" : "missing", color: r.exists ? .green : .red)
                            if r.isDirectory { badge("dir", color: .blue) }
                            if r.readable { badge("r", color: .green) }
                            if r.writable { badge("w", color: .orange) }
                            if let s = r.size { badge("\(s)B", color: .gray) }
                        }
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Label("Paths", systemImage: "folder")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Path Access")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    let text = results.map { r in
                        "\(r.path) exists=\(r.exists) dir=\(r.isDirectory) r=\(r.readable) w=\(r.writable)"
                    }.joined(separator: "\n")
                    UIPasteboard.general.string = text
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .disabled(results.isEmpty)
            }
        }
        .onAppear {
            if results.isEmpty { scan() }
        }
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, design: .monospaced))
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(color.opacity(0.18))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    private func scan() {
        busy = true
        let list = paths
        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            var out: [PathResult] = []
            for p in list {
                var isDir: ObjCBool = false
                let exists = fm.fileExists(atPath: p, isDirectory: &isDir)
                let readable = fm.isReadableFile(atPath: p)
                let writable = fm.isWritableFile(atPath: p)
                var size: Int64? = nil
                if exists, !isDir.boolValue {
                    if let attrs = try? fm.attributesOfItem(atPath: p),
                       let n = attrs[.size] as? NSNumber {
                        size = n.int64Value
                    }
                }
                out.append(PathResult(
                    path: p, exists: exists, isDirectory: isDir.boolValue,
                    readable: readable, writable: writable, size: size))
            }
            DispatchQueue.main.async {
                self.results = out
                self.busy = false
            }
        }
    }
}
