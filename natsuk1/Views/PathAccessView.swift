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
        "/System/Library/PrivateFrameworks/AirTrafficDevice.framework",
        "/System/Library/PrivateFrameworks/AirTrafficHost.framework",
        "/System/Library/PrivateFrameworks/CoreFP.framework",
        "/System/Library/PrivateFrameworks/SpringBoardServices.framework",
        "/System/Library/PreferenceBundles", "/System/Library/AccessibilityBundles",
        "/System/Library/Caches/com.apple.kernelcaches", "/System/Library/Kernels",
        "/usr/lib", "/usr/libexec", "/usr/bin", "/bin", "/sbin", "/etc", "/private/etc",
        "/var/jb", NSHomeDirectory(),
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
        ("AirTrafficDevice", "/System/Library/PrivateFrameworks/AirTrafficDevice.framework/AirTrafficDevice",
         ["ATGrappaDeviceInfo"]),
        ("AirTrafficHost", "/System/Library/PrivateFrameworks/AirTrafficHost.framework/AirTrafficHost",
         ["ATGrappaDeviceInfo"]),
        ("CoreFP", "/System/Library/PrivateFrameworks/CoreFP.framework/CoreFP", []),
        ("SpringBoardServices", "/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", []),
    ]

    var body: some View {
        List {
            Section {
                HStack { Text("Paths"); Spacer(); Text("\(results.filter { $0.exists }.count)/\(results.count)").font(.system(.body, design: .monospaced)).foregroundStyle(.secondary) }
                HStack { Text("Readable"); Spacer(); Text("\(results.filter { $0.readable }.count)").font(.system(.body, design: .monospaced)).foregroundStyle(.secondary) }
                HStack { Text("Writable"); Spacer(); Text("\(results.filter { $0.writable }.count)").font(.system(.body, design: .monospaced)).foregroundStyle(.secondary) }
                HStack { Text("Libraries"); Spacer(); Text("\(libs.filter { $0.loaded }.count)/\(libs.count)").font(.system(.body, design: .monospaced)).foregroundStyle(.secondary) }
                Button { scan() } label: {
                    HStack {
                        Text(busy ? "Scanning..." : "Run Scan")
                        Spacer()
                        if busy { ProgressView().scaleEffect(0.8) }
                    }
                }.disabled(busy)
            } header: {
                Label("Summary", systemImage: "chart.bar")
            }

            if !libs.isEmpty {
                Section {
                    ForEach(libs) { r in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(r.name).font(.system(size: 12, weight: .semibold))
                                badge(r.loaded ? "loaded" : "no", color: r.loaded ? .green : .red)
                            }
                            Text(r.path).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).lineLimit(2)
                            if !r.symbols.isEmpty {
                                HStack(spacing: 4) {
                                    ForEach(r.symbols, id: \.self) { sym in
                                        badge(sym, color: r.foundSymbols.contains(sym) ? .green : .gray)
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Label("Libraries", systemImage: "books.vertical")
                }
            }

            Section {
                ForEach(results) { r in
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
                }
            } header: {
                Label("Paths", systemImage: "folder")
            }
        }
        .listStyle(.insetGrouped)
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
