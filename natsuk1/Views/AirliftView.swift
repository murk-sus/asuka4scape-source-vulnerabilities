import SwiftUI
import UIKit

struct AirliftView: View {
    @EnvironmentObject var airlift: AirliftBridge
    @State private var loopbackVPNUp: Bool = NetworkStatus.loopbackVPNUp()
    @State private var tunnelIP: String? = NetworkStatus.tunnelIP()
    @State private var deviceIP: String? = NetworkStatus.deviceIP()

    var body: some View {
        List {
            if !loopbackVPNUp {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "wifi.exclamationmark")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Loopback VPN is not active")
                                .font(.subheadline).fontWeight(.semibold)
                            Text("Start LocalDevVPN (10.7.0.1 / 10.7.1.1)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundStyle(.green)
                        Text("Loopback VPN active").font(.subheadline).fontWeight(.semibold)
                    }
                    if let t = tunnelIP {
                        HStack {
                            Text("Tunnel")
                            Spacer()
                            Text(t).font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
                        }
                    }
                    if let d = deviceIP {
                        HStack {
                            Text("Device")
                            Spacer()
                            Text(d).font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Label("Network", systemImage: "network")
                }
            }

            if airlift.hasPairing() {
                exploitSection
            } else {
                pairingSection
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
        .onAppear { refresh() }
        .refreshable { refresh() }
    }

    private func refresh() {
        loopbackVPNUp = NetworkStatus.loopbackVPNUp()
        tunnelIP = NetworkStatus.tunnelIP()
        deviceIP = NetworkStatus.deviceIP()
    }

    @ViewBuilder
    private var pairingSection: some View {
        Section {
            HStack(spacing: 8) {
                Image(systemName: "link.badge.plus")
                    .foregroundStyle(.orange)
                Text("Not paired").font(.subheadline.bold())
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
            Label("Pairing", systemImage: "link.circle")
        }

        Section {
            if case .pairing = airlift.state {
                Button(role: .destructive) { airlift.cancelPairing() } label: { Text("Cancel Pairing").frame(maxWidth: .infinity) }
            } else {
                Button { airlift.runPairing() } label: { Text("Start Pairing").frame(maxWidth: .infinity) }
            }
        }
    }

    @ViewBuilder
    private var exploitSection: some View {
        Section {
            HStack {
                Image(systemName: "link.circle.fill").foregroundStyle(.green)
                Text("Paired").font(.subheadline.bold())
            }
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
            Label("Pairing", systemImage: "link.circle")
        }

        Section {
            Button { airlift.runExploit() } label: {
                HStack {
                    Image(systemName: "bolt.fill")
                    Text("Run Exploit")
                }
            }
            .disabled(airlift.state == .running || !loopbackVPNUp)

            Button { airlift.respring() } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Respring")
                }
            }
            .disabled(airlift.state == .running)
        } header: {
            Label("Exploit", systemImage: "bolt.shield")
        }

        Section {
            Button(role: .destructive) { airlift.deletePairing() } label: { Text("Delete Pairing").frame(maxWidth: .infinity) }
        }
    }
}
