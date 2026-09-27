import SwiftUI

struct CarrierLabView: View {
    @ObservedObject private var clState = CarrierLabState.shared

    private let ticker = Timer.publish(every: 5.0, on: .main, in: .common).autoconnect()

    var body: some View {
        List {
            airliftSection
            pairingHintSection
            resourcesSection
            statusSection
            actionsSection
            logSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("CarrierLab")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { runCheck() }
        .onReceive(ticker) { _ in
            if !clState.busy { runCheck(silent: true) }
        }
    }

    private var airliftSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: clState.airliftOK ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(clState.airliftOK ? .green : .orange)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Airlift")
                    Text(clState.airliftOK ? "Connected" : "Not ready")
                        .font(.subheadline)
                        .foregroundStyle(clState.airliftOK ? .green : .orange)
                    if !clState.airliftOK {
                        Text(clState.airliftMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(4)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 4)
        } header: { Label("Airlift", systemImage: "antenna.radiowaves.left.and.right") }
    }

    @ViewBuilder
    private var pairingHintSection: some View {
        if !clState.airliftOK {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Pairing is done in Airlift only", systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("CarrierLab never creates a pairing file. Open Tools / Airlift, run Start Pairing, then return here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var resourcesSection: some View {
        Section {
            HStack {
                Text("CarrierAssets")
                Spacer()
                Text(clState.resourcesOK ? "Bundled" : "Missing")
                    .foregroundStyle(clState.resourcesOK ? .green : .red)
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
                    Text(s.startedAt.formatted())
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                if let e = s.lastError {
                    Text(e)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        } header: { Label("CarrierLab", systemImage: "shippingbox") }
    }

    private var actionsSection: some View {
        Section {
            Button { runCheck() } label: { Text("Check") }.disabled(clState.busy)
            Button { runInstall() } label: { Text("Install") }.disabled(clState.busy || !clState.airliftOK || !clState.resourcesOK)
            Button { runReload() } label: { Text("Reload") }.disabled(clState.busy || !clState.airliftOK || !clState.resourcesOK)
            Button { runFinish() } label: { Text("Finish") }.disabled(clState.busy)
            Button(role: .destructive) { runReset() } label: { Text("Reset") }.disabled(clState.busy)
        } header: { Label("Actions", systemImage: "wrench") }
    }

    @ViewBuilder
    private var logSection: some View {
        if !clState.logText.isEmpty {
            Section {
                ScrollView {
                    Text(clState.logText)
                        .font(.system(size: 10, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 120, maxHeight: 300)
            } header: { Label("Log", systemImage: "terminal") }
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

    private func runCheck(silent: Bool = false) {
        if clState.busy { return }
        clState.setBusy(true)
        DispatchQueue.global(qos: .userInitiated).async {
            let r = CarrierLabInstaller.shared.check()
            CarrierLabState.shared.setAirlift(ok: r.probe.ok, message: r.probe.message)
            CarrierLabState.shared.setResources(r.resourcesBundled)
            if !silent {
                let lines = [
                    "[check] airlift=\(r.probe.ok) msg=\(r.probe.message)",
                    "[check] carrierRoot=\(r.carrierRootExists) bundleLinks=\(r.bundleLinksExists) resourcesBundled=\(r.resourcesBundled) backup=\(r.backupPresent) status=\(r.status.rawValue)"
                ]
                for l in lines { CarrierLabState.shared.appendLog(l) }
            }
            CarrierLabState.shared.setBusy(false)
        }
    }

    private func runInstall() {
        if clState.busy { return }
        clState.setBusy(true)
        DispatchQueue.global(qos: .userInitiated).async {
            let r = CarrierLabInstaller.shared.install()
            let line = r.ok ? "[install] ok" : "[install] failed: \(r.message)"
            CarrierLabState.shared.appendLog(line)
            CarrierLabState.shared.setBusy(false)
        }
    }

    private func runReload() {
        if clState.busy { return }
        clState.setBusy(true)
        DispatchQueue.global(qos: .userInitiated).async {
            let r = CarrierLabInstaller.shared.reload()
            let line = r.ok ? "[reload] ok" : "[reload] failed: \(r.message)"
            CarrierLabState.shared.appendLog(line)
            CarrierLabState.shared.setBusy(false)
        }
    }

    private func runFinish() {
        if clState.busy { return }
        clState.setBusy(true)
        DispatchQueue.global(qos: .userInitiated).async {
            CarrierLabInstaller.shared.finish()
            CarrierLabState.shared.appendLog("[finish] ok")
            CarrierLabState.shared.setBusy(false)
        }
    }

    private func runReset() {
        if clState.busy { return }
        clState.setBusy(true)
        DispatchQueue.global(qos: .userInitiated).async {
            CarrierLabInstaller.shared.reset()
            CarrierLabState.shared.clearLog()
            CarrierLabState.shared.appendLog("[reset] ok")
            CarrierLabState.shared.setBusy(false)
        }
    }
}
