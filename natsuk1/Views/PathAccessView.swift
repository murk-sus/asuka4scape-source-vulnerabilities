import SwiftUI
import UIKit
import Darwin

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
    struct LibResult: Identifiable {
        let id = UUID()
        let name: String
        let path: String
        let loaded: Bool
        let symbols: [String]
        let foundSymbols: [String]
    }

    @State private var results: [PathResult] = []
    @State private var libs: [LibResult] = []
    @State private var busy = false

    private let paths: [String] = [
        "/usr/lib/libMobileGestalt.dylib", "/usr/lib/libMobileActivation.dylib",
        "/usr/lib/libmis.dylib", "/usr/lib/libsandbox.1.dylib",
        "/usr/lib/system/libsystem_kernel.dylib", "/usr/lib/system/libsystem_sandbox.dylib",
        "/System/Library/PrivateFrameworks/MobileGestalt.framework",
        "/System/Library/CoreServices/SystemVersion.plist",
        "/var/mobile/Library/Preferences/com.apple.MobileGestalt.plist",
        "/var/mobile/Library/Preferences/.GlobalPreferences.plist",
        "/var/mobile/Library/Preferences/com.apple.springboard.plist",
        "/var/mobile/Library/Caches", "/var/mobile/Library/Logs", "/var/mobile/Library",
        "/var/mobile/Media", "/var/mobile/Containers/Data/Application",
        "/var/mobile/Containers/Data/System", "/var/mobile/Containers/Shared/AppGroup",
        "/var/containers/Bundle/Application", "/var/containers/Shared/SystemGroup",
        "/private/var/mobile", "/private/var/mobile/Library", "/private/etc/hosts", "/etc/hosts",
        "/System/Library", "/System/Library/Frameworks", "/System/Library/PrivateFrameworks",
        NSHomeDirectory(),
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path,
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0].path,
        NSTemporaryDirectory(),
    ]

    private let libsToProbe: [(name: String, path: String, symbols: [String])] = [
        ("MobileGestalt", "/usr/lib/libMobileGestalt.dylib",
         ["MGCopyAnswer", "MGGetBoolAnswer", "MGGetSInt32Answer"]),
        ("MobileActivation", "/usr/lib/libMobileActivation.dylib", []),
        ("libmis", "/usr/lib/libmis.dylib", []),
        ("libsandbox", "/usr/lib/libsandbox.1.dylib", []),
    ]

    var body: some View {
        SimpleList {
            SimpleSection("Summary", systemImage: "chart.bar") {
                summaryRow("Paths", "\(results.filter { $0.exists }.count)/\(results.count)")
                Divider()
                summaryRow("Readable", "\(results.filter { $0.readable }.count)")
                Divider()
                summaryRow("Writable", "\(results.filter { $0.writable }.count)")
                Divider()
                summaryRow("Libraries", "\(libs.filter { $0.loaded }.count)/\(libs.count)")
                Divider()
                Button { scan() } label: {
                    HStack {
                        Text(busy ? "Scanning..." : "Run Scan")
                        Spacer()
                        ProgressView().opacity(busy ? 1 : 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .disabled(busy)
            }

            libsSection
            pathsSection
        }
        .navigationTitle("Path Access")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    var text = ""
                    for r in libs { text += "\(r.name) loaded=\(r.loaded)\n" }
                    for r in results { text += "\(r.path) exists=\(r.exists) r=\(r.readable) w=\(r.writable)\n" }
                    UIPasteboard.general.string = text
                } label: { Image(systemName: "square.and.arrow.up") }
                .disabled(results.isEmpty && libs.isEmpty)
            }
        }
        .onAppear { if results.isEmpty { scan() } }
    }

    private var libsSection: some View {
        SimpleSection("Libraries", systemImage: "books.vertical") {
            ForEach(Array(libs.enumerated()), id: \.element.id) { idx, r in
                if idx > 0 { Divider() }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(r.name).font(.system(size: 12, weight: .semibold))
                        badge(r.loaded ? "loaded" : "no", color: r.loaded ? .green : .red)
                    }
                    Text(r.path).font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary).lineLimit(2)
                    if !r.symbols.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(r.symbols, id: \.self) { sym in
                                badge(sym, color: r.foundSymbols.contains(sym) ? .green : .gray)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
    }

    private var pathsSection: some View {
        SimpleSection("Paths", systemImage: "folder") {
            ForEach(Array(results.enumerated()), id: \.element.id) { idx, r in
                if idx > 0 { Divider() }
                VStack(alignment: .leading, spacing: 4) {
                    Text(r.path).font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(r.exists ? .primary : .secondary).lineLimit(2)
                    HStack(spacing: 6) {
                        badge(r.exists ? "exists" : "missing", color: r.exists ? .green : .red)
                        if r.isDirectory { badge("dir", color: .blue) }
                        if r.readable { badge("r", color: .green) }
                        if r.writable { badge("w", color: .orange) }
                        if let s = r.size { badge("\(s)B", color: .gray) }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
    }

    private func summaryRow(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key)
            Spacer()
            Text(value).font(.system(.body, design: .monospaced)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text).font(.system(size: 9, design: .monospaced))
            .padding(.horizontal, 4).padding(.vertical, 1)
            .background(color.opacity(0.18), in: RoundedRectangle(cornerRadius: 3))
            .foregroundStyle(color)
    }

    private func scan() {
        busy = true
        let pathList = paths
        let libList = libsToProbe
        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            var outPaths: [PathResult] = []
            for p in pathList {
                var isDir: ObjCBool = false
                let exists = fm.fileExists(atPath: p, isDirectory: &isDir)
                let readable = fm.isReadableFile(atPath: p)
                let writable = fm.isWritableFile(atPath: p)
                var size: Int64? = nil
                if exists, !isDir.boolValue,
                   let attrs = try? fm.attributesOfItem(atPath: p),
                   let n = attrs[.size] as? NSNumber { size = n.int64Value }
                outPaths.append(PathResult(path: p, exists: exists, isDirectory: isDir.boolValue,
                                           readable: readable, writable: writable, size: size))
            }
            var outLibs: [LibResult] = []
            for entry in libList {
                let handle = dlopen(entry.path, RTLD_NOW)
                var found: [String] = []
                if handle != nil {
                    for sym in entry.symbols { if dlsym(handle, sym) != nil { found.append(sym) } }
                    dlclose(handle)
                }
                outLibs.append(LibResult(name: entry.name, path: entry.path, loaded: handle != nil,
                                         symbols: entry.symbols, foundSymbols: found))
            }
            DispatchQueue.main.async {
                self.results = outPaths; self.libs = outLibs; self.busy = false
            }
        }
    }
}
