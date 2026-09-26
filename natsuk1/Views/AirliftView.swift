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
        SimpleList {
            networkSection
            pairingOrExploit
            logSection
            logActionsSection
        }
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

    private var networkSection: some View {
        SimpleSection("Network", systemImage: "network") {
            HStack {
                Text("Status")
                Spacer()
                Text(loopbackVPNUp ? "active" : "not active")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(loopbackVPNUp ? .green : .orange)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            if let t = tunnelIP {
                Divider()
                HStack {
                    Text("Tunnel")
                    Spacer()
                    Text(t)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }

            if let d = deviceIP {
                Divider()
                HStack {
                    Text("Device")
                    Spacer()
                    Text(d)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }

            if !loopbackVPNUp {
                Divider()
                Text("Start LocalDevVPN with interface 10.7.0.x")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            }
        }
    }

    private var pairingOrExploit: some View {
        Group {
            if airlift.hasPairing() {
                exploitSection
            } else {
                pairingSection
            }
        }
    }

    private var pairingSection: some View {
        Group {
            SimpleSection("Pairing", systemImage: "link.circle") {
                HStack {
                    Text("State")
                    Spacer()
                    Text(pairingStatusText)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(pairingStatusColor)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

                HStack(spacing: 8) {
                    ProgressView().opacity(isPairing ? 1 : 0)
                    Text(airlift.pairingStatus.isEmpty ? "Idle" : airlift.pairingStatus)
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }

            SimpleSection("Actions", systemImage: "hand.tap") {
                Button(role: .destructive) { airlift.cancelPairing() } label: {
                    Text("Cancel Pairing")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
                .opacity(isPairing ? 1 : 0)
                .disabled(!isPairing)
                .frame(height: isPairing ? nil : 0)

                Button { airlift.runPairing() } label: {
                    Text("Start Pairing")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
                .opacity(isPairing ? 0 : 1)
                .disabled(isPairing)
                .frame(height: isPairing ? 0 : nil)
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

    private var exploitSection: some View {
        Group {
            SimpleSection("Pairing", systemImage: "link.circle") {
                HStack {
                    Text("State")
                    Spacer()
                    Text(pairingStatusText)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(pairingStatusColor)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

                Divider()

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
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }

            SimpleSection("Exploit", systemImage: "cpu") {
                Button { airlift.runExploit() } label: {
                    Text("Run Exploit")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
                .disabled(airlift.state == .running || !loopbackVPNUp)

                Divider()

                Button(role: .destructive) { airlift.cancelExploit() } label: {
                    Text("Cancel Exploit")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
                .disabled(airlift.state != .running)

                Divider()

                Button { respring() } label: {
                    Text("Respring")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
            }

            SimpleSection("Danger", systemImage: "exclamationmark.triangle") {
                Button(role: .destructive) { airlift.deletePairing() } label: {
                    Text("Delete Pairing")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
            }
        }
    }

    private func respring() {
        NotificationCenter.default.post(
            name: Notification.Name("natsuk1.respring"),
            object: nil
        )
    }

    private var logSection: some View {
        SimpleSection("Log", systemImage: "terminal") {
            LogTerminal(text: airlift.exploitLog.isEmpty
                        ? "No output yet."
                        : airlift.exploitLog.joined(separator: "\n"))
        }
    }

    private var logActionsSection: some View {
        SimpleSection("Log Actions", systemImage: "document.on.document") {
            Button {
                UIPasteboard.general.string = airlift.exploitLog.joined(separator: "\n")
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    copied = false
                }
            } label: {
                Text(copied ? "Copied!" : "Copy All")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            }
            .disabled(airlift.exploitLog.isEmpty)

            Divider()

            Button(role: .destructive) { airlift.clearLog() } label: {
                Text("Clear")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            }
            .disabled(airlift.exploitLog.isEmpty)
        }
    }
}
