import SwiftUI
import UIKit
import Combine

struct AirliftView: View {
    @EnvironmentObject var airlift: AirliftBridge
    @State private var loopbackVPNUp: Bool = NetworkStatus.loopbackVPNUp()
    @State private var tunnelIP: String? = NetworkStatus.tunnelIP()
    @State private var deviceIP: String? = NetworkStatus.deviceIP()
    @State private var copied = false

    private let ticker = Timer.publish(every: 5.0, on: .main, in: .common).autoconnect()

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(loopbackVPNUp ? "active" : "not active")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(loopbackVPNUp ? .green : .orange)
                }
                HStack {
                    Text("Tunnel")
                    Spacer()
                    Text(tunnelIP ?? "—")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Device")
                    Spacer()
                    Text(deviceIP ?? "—")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                if !loopbackVPNUp {
                    Text("Start LocalDevVPN with interface 10.7.0.x")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Label("Network", systemImage: "network")
            }

            Section {
                HStack {
                    Text("State")
                    Spacer()
                    Text(pairingStatusText)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(pairingStatusColor)
                }
                HStack(spacing: 8) {
                    ProgressView().opacity(isPairing ? 1 : 0)
                    Text(airlift.pairingStatus.isEmpty ? "Idle" : airlift.pairingStatus)
                        .font(.subheadline).foregroundStyle(.secondary)
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
                    .background(Color.orange.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 12))
                }
            } header: {
                Label("Pairing", systemImage: "link.circle")
            }

            Section {
                Button(role: .destructive) { airlift.cancelPairing() } label: {
                    Text("Cancel Pairing")
                }
                .disabled(!isPairing)

                Button { airlift.runPairing() } label: {
                    Text("Start Pairing")
                }
                .disabled(isPairing)
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

                Button { respring() } label: {
                    Text("Respring")
                }
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copied = false
                    }
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
        DispatchQueue.global(qos: .utility).async {
            let vpn = NetworkStatus.loopbackVPNUp()
            let tun = NetworkStatus.tunnelIP()
            let dev = NetworkStatus.deviceIP()
            DispatchQueue.main.async {
                if self.loopbackVPNUp != vpn { self.loopbackVPNUp = vpn }
                if self.tunnelIP != tun { self.tunnelIP = tun }
                if self.deviceIP != dev { self.deviceIP = dev }
            }
        }
    }

    private var isPairing: Bool {
        if case .pairing = airlift.state { return true }
        return false
    }

    private var pairingStatusText: String {
        switch airlift.state {
        case .pairing: return "pairing"
        case .ready:   return "paired"
        case .running: return "running"
        case .done(let ok, _): return ok ? "done" : "failed"
        default:       return "idle"
        }
    }

    private var pairingStatusColor: Color {
        switch airlift.state {
        case .pairing: return .orange
        case .ready:   return .green
        case .running: return .orange
        case .done(let ok, _): return ok ? .green : .red
        default:       return .secondary
        }
    }

    private func respring() {
        NotificationCenter.default.post(
            name: Notification.Name("natsuk1.respring"),
            object: nil
        )
    }
}
