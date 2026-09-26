import SwiftUI
import UIKit
import Combine

struct AirliftView: View {
    @EnvironmentObject var airlift: AirliftBridge
    @State private var loopbackVPNUp: Bool = NetworkStatus.loopbackVPNUp()
    @State private var tunnelIP: String? = NetworkStatus.tunnelIP()
    @State private var deviceIP: String? = NetworkStatus.deviceIP()
    @State private var copied = false

    private let ticker = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(loopbackVPNUp ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                            .frame(width: 72, height: 72)
                        Image(systemName: loopbackVPNUp ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(loopbackVPNUp ? .green : .orange)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("LocalDevVPN")
                            .font(.headline)
                        Text(loopbackVPNUp ? "Connected" : "Not connected")
                            .font(.subheadline)
                            .foregroundStyle(loopbackVPNUp ? .green : .orange)
                        if let t = tunnelIP {
                            Text("Tunnel \(t)")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
            } header: {
                Label("Current status", systemImage: "shield.lefthalf.filled")
            }

            Section {
                HStack {
                    Text("Tunnel IP")
                    Spacer()
                    Text(tunnelIP ?? "—")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Device IP")
                    Spacer()
                    Text(deviceIP ?? "—")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            } header: {
                Label("Session details", systemImage: "network")
            }

            Section {
                if case .pairing = airlift.state {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text(airlift.pairingStatus.isEmpty ? "Starting..." : airlift.pairingStatus)
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                if let pin = airlift.pairPIN {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ENTER PIN").font(.caption2.bold()).foregroundStyle(.secondary)
                        Text(pin).font(.system(size: 34, weight: .black, design: .monospaced))
                            .foregroundStyle(.orange)
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Text("Open Settings").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent).tint(.orange)
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                }
                Button(role: .destructive) { airlift.cancelPairing() } label: {
                    Text("Cancel Pairing")
                }
                .disabled(!isPairing)
                Button { airlift.runPairing() } label: {
                    Text("Start Pairing")
                }
                .disabled(isPairing)
            } header: {
                Label("Pairing", systemImage: "link.circle")
            }

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
                Label("Target", systemImage: "scope")
            }

            Section {
                Button { airlift.runExploit() } label: {
                    Text("Run Exploit")
                }
                .disabled(airlift.state == .running || !loopbackVPNUp || !airlift.hasPairing())
                Button(role: .destructive) { airlift.cancelExploit() } label: {
                    Text("Cancel Exploit")
                }
                .disabled(airlift.state != .running)
            } header: {
                Label("Exploit", systemImage: "cpu")
            }

            Section {
                Button(role: .destructive) { airlift.deletePairing() } label: {
                    Text("Delete Pairing")
                }
                .disabled(!airlift.hasPairing())
            }

            Section {
                LogTerminal(text: airlift.exploitLog.isEmpty
                            ? "No output yet."
                            : airlift.exploitLog.joined(separator: "\n"))
            } header: {
                Label("Log", systemImage: "terminal")
            }

            Section {
                Button {
                    UIPasteboard.general.string = airlift.exploitLog.joined(separator: "\n")
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                } label: {
                    Text(copied ? "Copied!" : "Copy All")
                }
                .disabled(airlift.exploitLog.isEmpty)
                Button(role: .destructive) { airlift.clearLog() } label: {
                    Text("Clear")
                }
                .disabled(airlift.exploitLog.isEmpty)
            } header: {
                Label("Log Actions", systemImage: "document.on.document")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Airlift")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { refresh() }
        .onReceive(ticker) { _ in refresh() }
        .refreshable { refresh() }
    }

    private func refresh() {
        let vpn = NetworkStatus.loopbackVPNUp()
        let tun = NetworkStatus.tunnelIP()
        let dev = NetworkStatus.deviceIP()
        if loopbackVPNUp != vpn { loopbackVPNUp = vpn }
        if tunnelIP != tun { tunnelIP = tun }
        if deviceIP != dev { deviceIP = dev }
    }

    private var isPairing: Bool {
        if case .pairing = airlift.state { return true }
        return false
    }
}
