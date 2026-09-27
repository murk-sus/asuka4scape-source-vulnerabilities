import SwiftUI

struct CarrierLabView: View {
    @ObservedObject private var clState = CarrierLabState.shared
    @State private var logText: String = ""
    @State private var busy: Bool = false
    @State private var airliftOK: Bool = false
    @State private var airliftMessage: String = "checking..."
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
        .onAppear { runCheck() }
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
                Text("CarrierAssets in bundle")
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
            Button { runCheck() } label: { Text("Check") }.disabled(busy)
            Button { runInstall() } label: { Text("Install") }.disabled(busy || !airliftOK || !resourcesOK)
            Button { runReload() } label: { Text("Reload") }.disabled(busy || !airliftOK || !resourcesOK)
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

    private func runCheck() {
        if busy { return }
        busy = true
        DispatchQueue.global(qos: .userInitiated).async {
            var ok = false
            var msg = ""
            var resOK = false
            var lines: [String] = []
            do {
                let r = try CarrierLabInstaller.shared.check()
                ok = r.probe.ok
                msg = r.probe.message
                resOK = r.resourcesBundled
                lines.append("[check] airlift=\(r.probe.ok) msg=\(r.probe.message)")
                lines.append("[check] carrierRoot=\(r.carrierRootExists) bundleLinks=\(r.bundleLinksExists) resourcesBundled=\(r.resourcesBundled) backup=\(r.backupPresent) status=\(r.status.rawValue)")
            } catch {
                msg = error.localizedDescription
                lines.append("[check] error: \(error.localizedDescription)")
            }
            DispatchQueue.main.async {
                self.airliftOK = ok
                self.airliftMessage = msg
                self.resourcesOK = resOK
                for l in lines { self.logText += l + "\n" }
                self.busy = false
            }
        }
    }

    private func runInstall() {
        if busy { return }
        busy = true
        DispatchQueue.global(qos: .userInitiated).async {
            var lines: [String] = []
            do {
                try CarrierLabInstaller.shared.install()
                lines.append("[install] ok")
            } catch {
                lines.append("[install] error: \(error.localizedDescription)")
            }
            DispatchQueue.main.async {
                for l in lines { self.logText += l + "\n" }
                self.busy = false
            }
        }
    }

    private func runReload() {
        if busy { return }
        busy = true
        DispatchQueue.global(qos: .userInitiated).async {
            var lines: [String] = []
            do {
                try CarrierLabInstaller.shared.reload()
                lines.append("[reload] ok")
            } catch {
                lines.append("[reload] error: \(error.localizedDescription)")
            }
            DispatchQueue.main.async {
                for l in lines { self.logText += l + "\n" }
                self.busy = false
            }
        }
    }

    private func runFinish() {
        if busy { return }
        busy = true
        DispatchQueue.global(qos: .userInitiated).async {
            var lines: [String] = []
            do {
                try CarrierLabInstaller.shared.finish()
                lines.append("[finish] ok")
            } catch {
                lines.append("[finish] error: \(error.localizedDescription)")
            }
            DispatchQueue.main.async {
                for l in lines { self.logText += l + "\n" }
                self.busy = false
            }
        }
    }

    private func runReset() {
        if busy { return }
        busy = true
        DispatchQueue.global(qos: .userInitiated).async {
            var lines: [String] = []
            do {
                try CarrierLabInstaller.shared.reset()
                lines.append("[reset] ok")
            } catch {
                lines.append("[reset] error: \(error.localizedDescription)")
            }
            DispatchQueue.main.async {
                for l in lines { self.logText += l + "\n" }
                self.busy = false
            }
        }
    }
}
