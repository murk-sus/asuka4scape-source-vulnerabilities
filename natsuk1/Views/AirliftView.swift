import SwiftUI
import UIKit

struct AirliftView: View {
    @EnvironmentObject var airlift: AirliftBridge
    private var localDevVPNUp: Bool {
        NetworkStatus.interfaces().contains { NetworkStatus.isTunnelInterface($0.name) }
    }

    var body: some View {
        List {
            if !localDevVPNUp {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text("LocalDevVPN is not active.").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }

            switch airlift.state {
            case .idle, .pairing: pairingSection
            case .ready, .running, .done: exploitSection
            }

            Section {
                LogTerminal(text: airlift.exploitLog.isEmpty ? "No output yet." : airlift.exploitLog.joined(separator: "\n"))
            } header: {
                Label("Log", systemImage: "terminal")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Airlift")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var pairingSection: some View {
        Section {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(airlift.hasPairing() ? .green : .orange)
                Text(airlift.hasPairing() ? "Paired" : "Not paired").font(.subheadline.bold())
            }
            if case .pairing = airlift.state {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.85)
                    Text(airlift.pairingStatus.isEmpty ? "Starting..." : airlift.pairingStatus)
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            if let pin = airlift.pairPIN {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ENTER PIN").font(.caption2.bold()).foregroundStyle(.secondary)
                    Text(pin).font(.system(size: 34, weight: .black, design: .monospaced)).foregroundStyle(.orange)
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    } label: { Label("Open Settings", systemImage: "arrow.up.forward.app").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).tint(.orange)
                }
                .padding(12)
                .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            }
        } header: {
            Label("Pairing", systemImage: "antenna.radiowaves.left.and.right")
        }

        Section {
            if case .pairing = airlift.state {
                Button(role: .destructive) { airlift.cancelPairing() } label: { Text("Cancel Pairing").frame(maxWidth: .infinity) }
            } else if airlift.hasPairing() {
                Button(role: .destructive) { airlift.deletePairing() } label: { Text("Delete Pairing").frame(maxWidth: .infinity) }
            } else {
                Button { airlift.runPairing() } label: { Text("Start Pairing").frame(maxWidth: .infinity) }
            }
        }
    }

    @ViewBuilder
    private var exploitSection: some View {
        Section {
            HStack {
                Text("Target")
                Spacer()
                TextField("/var/mobile/Library/SpringBoard", text: Binding(
                    get: { airlift.target }, set: { airlift.target = $0 }))
                    .font(.system(size: 12, design: .monospaced))
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        } header: {
            Label("Exploit", systemImage: "scope")
        }
        Section {
            Button { airlift.runExploit() } label: { Text("Run Exploit") }
                .disabled(airlift.state == .running || !localDevVPNUp)
            Button { airlift.respring() } label: { Text("Respring") }
                .disabled(airlift.state == .running)
            Button(role: .destructive) { airlift.deletePairing() } label: { Text("Delete Pairing") }
        }
    }
}
