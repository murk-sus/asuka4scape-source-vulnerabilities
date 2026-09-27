import SwiftUI

struct CarrierLabView: View {
    @ObservedObject private var clState = CarrierLabState.shared
    @State private var logText: String = ""
    @State private var busy: Bool = false
    @State private var airliftOK: Bool? = nil
    @State private var airliftMessage: String = ""

    var body: some View {
        List {
            airliftSection
            statusSection
            actionsSection
            logSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("CarrierLab")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { runCheck() }
    }

    private var airliftSection: some View {
        Section {
            HStack {
                Image(systemName: (airliftOK == true) ? "checkmark.seal.fill" : ((airliftOK == false) ? "xmark.seal.fill" : "questionmark.circle"))
                    .foregroundStyle((airliftOK == true) ? .green : ((airliftOK == false) ? .red : .secondary))
                Text("Airlift")
                Spacer()
                Text(airliftMessage.isEmpty ? "проверка…" : airliftMessage)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle((airliftOK == true) ? .green : .red)
                    .lineLimit(2)
            }
        } header: { Label("Airlift", systemImage: "antenna.radiowaves.left.and.right") }
    }

    private var statusSection: some View {
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
        } header: { Label("CarrierLab", systemImage: "shippingbox") }
    }

    private var actionsSection: some View {
        Section {
            Button { runCheck() } label: { Text("Check") }.disabled(busy)
            Button { runInstall() } label: { Text("Install") }
                .disabled(busy || airliftOK != true)
            Button { runReload() } label: { Text("Reload") }
                .disabled(busy || airliftOK != true)
            Button { runFinish() } label: { Text("Finish") }.disabled(busy)
            Button(role: .destructive) { runReset() } label: { Text("Reset") }.disabled(busy)
        } header: { Label("Actions", systemImage: "wrench") }
    }

    private var logSection: some View {
        Section {
            ScrollView {
                Text(logText.isEmpty ? "no output" : logText)
                    .font(.system(size: 10, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 200, maxHeight: 400)
        } header: { Label("Log", systemImage: "terminal") }
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
            airliftOK = r.airliftOK
            airliftMessage = r.airliftMessage
            append("[check] airlift=\(r.airliftOK) msg=\(r.airliftMessage)")
            append("[check] carrierRoot=\(r.carrierRootExists) bundleLinks=\(r.bundleLinksExists) resourcesBundled=\(r.resourcesBundled) backup=\(r.backupPresent) status=\(r.status.rawValue)")
        } catch {
            airliftOK = false
            airliftMessage = error.localizedDescription
            append("[check] error: \(error.localizedDescription)")
        }
        busy = false
    }

    private func runInstall() {
        busy = true
        do {
            try CarrierLabInstaller.shared.install()
            append("[install] ok")
        } catch {
            append("[install] error: \(error.localizedDescription)")
        }
        busy = false
    }

    private func runReload() {
        busy = true
        do {
            try CarrierLabInstaller.shared.reload()
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

    private func runReset() {
        busy = true
        do {
            try CarrierLabInstaller.shared.reset()
            append("[reset] ok")
        } catch {
            append("[reset] error: \(error.localizedDescription)")
        }
        busy = false
    }
}
