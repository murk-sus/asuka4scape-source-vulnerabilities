import SwiftUI

struct CarrierLabView: View {
    @ObservedObject private var clState = CarrierLabState.shared
    @State private var logText: String = ""
    @State private var busy: Bool = false
    @State private var showInstall = false
    @State private var confirmText = ""
    @State private var carrierSource: String = ""

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(statusText)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(statusColor)
                }
                if let s = clState.session {
                    HStack {
                        Text("Started")
                        Spacer()
                        Text(s.startedAt.formatted()).font(.caption).foregroundStyle(.secondary)
                    }
                    if let e = s.lastError {
                        Text(e).font(.caption).foregroundStyle(.red)
                    }
                }
            } header: { Label("CarrierLab", systemImage: "antenna.radiowaves.left.and.right") }

            Section {
                TextField("Source .bundle path", text: $carrierSource)
                    .font(.system(.footnote, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } header: { Label("Source", systemImage: "folder") }

            Section {
                Button { runCheck() } label: { Text("Check") }.disabled(busy)
                Button { showInstall = true } label: { Text("Install") }.disabled(busy)
                Button { runReload() } label: { Text("Reload") }.disabled(busy)
                Button { runFinish() } label: { Text("Finish") }.disabled(busy)
            } header: { Label("Actions", systemImage: "wrench") }

            Section {
                ScrollView {
                    Text(logText.isEmpty ? "no output" : logText)
                        .font(.system(size: 10, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 200, maxHeight: 400)
            } header: { Label("Log", systemImage: "terminal") }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("CarrierLab")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Confirm install", isPresented: $showInstall) {
            TextField("Type INSTALL", text: $confirmText)
            Button("Cancel", role: .cancel) { confirmText = "" }
            Button("Install", role: .destructive) {
                if confirmText == "INSTALL" { runInstall() }
                confirmText = ""
            }
        } message: {
            Text("Modifies operator files. No guaranteed rollback.")
        }
    }

    private var statusText: String {
        clState.session?.status.rawValue ?? "clean"
    }

    private var statusColor: Color {
        switch clState.session?.status {
        case .placed, .finished: return .green
        case .placing: return .orange
        case .failed: return .red
        default: return .secondary
        }
    }

    private func append(_ s: String) { logText += s + "\n" }

    private func runCheck() {
        busy = true
        do {
            let r = try CarrierLabInstaller.shared.check()
            append("[check] carrierRoot=\(r.carrierRootExists) bundleLinks=\(r.bundleLinksExists) backup=\(r.backupPresent) status=\(r.status.rawValue)")
            append("[check] links=\(r.currentLinks.joined(separator: ", "))")
        } catch {
            append("[check] error: \(error.localizedDescription)")
        }
        busy = false
    }

    private func runInstall() {
        busy = true
        let src = carrierSource.isEmpty ? Bundle.main.bundlePath + "/CarrierLab.bundle" : carrierSource
        let ipcc = Bundle.main.bundlePath + "/ipcc"
        do {
            try CarrierLabInstaller.shared.install(sourceBundlePath: src, ipccPath: ipcc)
            append("[install] ok")
        } catch {
            append("[install] error: \(error.localizedDescription)")
        }
        busy = false
    }

    private func runReload() {
        busy = true
        do {
            try CarrierLabInstaller.shared.reload(ipccPath: Bundle.main.bundlePath + "/ipcc")
            append("[reload] ok")
        } catch {
            append("[reload] error: \(error.localizedDescription)")
        }
        busy = false
    }

    private func runFinish() {
        busy = true
        do {
            try CarrierLabInstaller.shared.finish()
            append("[finish] ok")
        } catch {
            append("[finish] error: \(error.localizedDescription)")
        }
        busy = false
    }
}
