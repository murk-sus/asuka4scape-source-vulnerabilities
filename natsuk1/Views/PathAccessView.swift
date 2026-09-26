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

    @State private var results: [PathResult] = []
    @State private var busy = false

    private let paths: [String] = [
        "/var/mobile",
        "/var/mobile/Documents",
        "/var/mobile/Library",
        "/var/mobile/Library/Preferences",
        "/var/mobile/Library/Caches",
        "/var/mobile/Library/SpringBoard",
        "/var/mobile/Library/SMS",
        "/var/mobile/Library/Safari",
        "/var/mobile/Containers",
        "/var/mobile/Containers/Data/Application",
        "/var/mobile/Containers/Shared/AppGroup",
        "/var/tmp",
        "/var/mobile/Media",
    ]

    var body: some View {
        List {
            Section {
                HStack { Text("Paths"); Spacer(); Text("\(results.filter { $0.exists }.count)/\(results.count)").font(.system(.body, design: .monospaced)).foregroundStyle(.secondary) }
                HStack { Text("Readable"); Spacer(); Text("\(results.filter { $0.readable }.count)").font(.system(.body, design: .monospaced)).foregroundStyle(.secondary) }
                HStack { Text("Writable"); Spacer(); Text("\(results.filter { $0.writable }.count)").font(.system(.body, design: .monospaced)).foregroundStyle(.secondary) }
                Button { scan() } label: {
                    HStack {
                        Text(busy ? "Scanning..." : "Run Scan")
                        Spacer()
                        ProgressView().opacity(busy ? 1 : 0)
                    }
                }.disabled(busy)
            } header: {
                Label("Summary", systemImage: "chart.bar")
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
            DispatchQueue.main.async {
                self.results = outPaths; self.busy = false
            }
        }
    }
}
