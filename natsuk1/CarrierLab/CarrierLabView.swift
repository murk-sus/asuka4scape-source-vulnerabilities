import SwiftUI

struct CarrierLabView: View {
    @ObservedObject private var clState = CarrierLabState.shared
    @State private var logText: String = ""
    @State private var busy: Bool = false
    @State private var airliftOK: Bool = false
    @State private var airliftMessage: String = "проверка…"
    @State private var resourcesOK: Bool = false

    var body: some View {
        List {
            airliftSection
            resourcesSection
            statusSection
            actionsSection
            logSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("CarrierLab")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task { @MainActor in runCheck() }
        }
    }

    private var airliftSection: some View {
        Section {
            HStack(alignment: .top) {
                Image(systemName: airliftOK ? "checkmark.seal.fill" : "xmark.seal.fill")
                    .foregroundStyle(airliftOK ? .green : .red)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Airlift")
                    Text(airliftMessage)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(airliftOK ? .green : .red)
                        .lineLimit(4)
                }
            }
        } header: { Label("Airlift", systemImage: "antenna.radiowaves.left.and.right") }
    }

    private var resourcesSection: some View {
        Section {
            HStack {
                Image(systemName: resourcesOK ? "checkmark.seal.fill" : "xmark.seal.fill")
                    .foregroundStyle(resourcesOK ? .green : .red)
                Text("CarrierAssets в бандле")
                Spacer()
                Text(resourcesOK ? "ok" : "missing")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(resourcesOK ? .green : .red)
            }
        } header: { Label("Resources", systemImage: "shippingbox") }
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
            Button { Task { @MainActor in runCheck() } } label: { Text("Check") }
                .disabled(busy)
            Button { Task { @MainActor in runInstall() } } label: { Text("Install") }
                .disabled(busy || !airliftOK || !resourcesOK)
            Button { Task { @MainActor in runReload() } } label: { Text("Reload") }
                .disabled(busy || !airliftOK || !resourcesOK)
            Button { Task { @MainActor in runFinish() } } label: { Text("Finish") }
                .disabled(busy)
            Button(role: .destructive) { Task { @MainActor in runReset() } } label: { Text("Reset") }
                .disabled(busy)
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

    @MainActor
    private func append(_ s: String) {
        logText += s + "\n"
    }

    @MainActor
    private func runCheck() {
        busy = true
        do {
            let r = try CarrierLabInstaller.shared.check()
            airliftOK = r.probe.ok
            airliftMessage = r.probe.message
            resourcesOK = r.resourcesBundled
            append("[check] airlift=\(r.probe.ok) msg=\(r.probe.message)")
            append("[check] carrierRoot=\(r.carrierRootExists) bundleLinks=\(r.bundleLinksExists) resourcesBundled=\(r.resourcesBundled) backup=\(r.backupPresent) status=\(r.status.rawValue)")
        } catch {
            airliftOK = false
            airliftMessage = error.localizedDescription
            resourcesOK = false
            append("[check] error: \(error.localizedDescription)")
        }
        busy = false
    }

    @MainActor
    private func runInstall() {
        busy = true
        do {
            try CarrierLabInstaller.shared.install()
            append("[install] ok")
        } catch {
            append("[install] error: \(error.localizedDescription)")
        }
        busy = false
        runCheck()
    }

    @MainActor
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

    @MainActor
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

    @MainActor
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
