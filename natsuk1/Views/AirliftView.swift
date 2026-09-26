import SwiftUI
import UIKit
import Combine

struct AirliftView: View {
    @EnvironmentObject var airlift: AirliftBridge
    @State private var loopbackVPNUp: Bool = NetworkStatus.loopbackVPNUp()
    @State private var tunnelIP: String? = NetworkStatus.tunnelIP()
    @State private var deviceIP: String? = NetworkStatus.deviceIP()
    @State private var copied = false
    @State private var pairedTick = 0

    private let ticker = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        List {
            statusSection
            sessionSection
            pairingStatusSection
            pairingButtonsSection
            targetSection
            exploitSection
            logSection
            logActionsSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Airlift")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { refresh(); pairedTick &+= 1 }
        .onReceive(ticker) { _ in refresh() }
        .onChange(of: airlift.state) { _, _ in pairedTick &+= 1 }
        .refreshable { refresh(); pairedTick &+= 1 }
    }

    private var statusSection: some View {
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
                    Text("LocalDevVPN").font(.headline)
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
    }

    private var sessionSection: some View {
        Section {
            HStack {
                Text("Tunnel IP")
                Spacer()
                Text(tunnelIP ?? "—")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(tunnelIP != nil ? .green : .secondary)
                    .shadow(color: tunnelIP != nil ? Color.green.opacity(0.55) : Color.clear, radius: 3)
            }
            HStack {
                Text("Device IP")
                Spacer()
                Text(deviceIP ?? "—")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(deviceIP != nil ? .green : .secondary)
                    .shadow(color: deviceIP != nil ? Color.green.opacity(0.55) : Color.clear, radius: 3)
            }
        } header: {
            Label("Session details", systemImage: "network")
        }
    }

    private var pairingStatusSection: some View {
        Section {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(pairingColor.opacity(0.15))
                        .frame(width: 72, height: 72)
                    Image(systemName: pairingIcon)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(pairingColor)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(pairingTitle).font(.headline)
                    Text(pairingSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(pairingColor)
                        .lineLimit(2)
                    if let pin = airlift.pairPIN {
                        Text("PIN \(pin)")
                            .font(.system(size: 20, weight: .black, design: .monospaced))
                            .foregroundStyle(.orange)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 8)
        } header: {
            Label("Pairing", systemImage: "link.circle")
        }
    }

    private var pairingButtonsSection: some View {
        Section {
            if let pin = airlift.pairPIN {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Open Settings").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).tint(.orange)
            }
            Button { airlift.runPairing() } label: {
                HStack {
                    Text(isPaired ? "Already Paired" : "Start Pairing")
                    Spacer()
                    if isPaired {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                }
            }
            .disabled(isPairing || isPaired)
            Button(role: .destructive) { airlift.cancelPairing() } label: {
                Text("Cancel Pairing")
            }
            .disabled(!isPairing)
            Button(role: .destructive) { airlift.deletePairing(); pairedTick &+= 1 } label: {
                Text("Delete Pairing")
            }
            .disabled(!isPaired)
        }
    }

    private var targetSection: some View {
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
    }

    private var exploitSection: some View {
        Section {
            Button { airlift.runExploit() } label: {
                Text("Run Exploit")
            }
            .disabled(airlift.state == .running || !loopbackVPNUp || !isPaired)
            Button(role: .destructive) { airlift.cancelExploit() } label: {
                Text("Cancel Exploit")
            }
            .disabled(airlift.state != .running)
        } header: {
            Label("Exploit", systemImage: "cpu")
        }
    }

    private var logSection: some View {
        Section {
            LogTerminal(text: airlift.exploitLog.isEmpty
                        ? "No output yet."
                        : airlift.exploitLog.joined(separator: "\n"))
        } header: {
            Label("Log", systemImage: "terminal")
        }
    }

    private var logActionsSection: some View {
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

    private var isPaired: Bool {
        _ = pairedTick
        return airlift.hasPairing()
    }

    private var pairingColor: Color {
        if isPaired { return .green }
        if isPairing { return .orange }
        if case .done(false, _) = airlift.state { return .red }
        return .secondary
    }

    private var pairingIcon: String {
        if isPaired { return "checkmark.seal.fill" }
        if isPairing { return "link.circle.fill" }
        if case .done(false, _) = airlift.state { return "xmark.seal.fill" }
        return "link.circle"
    }

    private var pairingTitle: String {
        if isPaired { return "Paired" }
        if isPairing { return "Pairing" }
        if case .done(false, _) = airlift.state { return "Failed" }
        return "Not Paired"
    }

    private var pairingSubtitle: String {
        if isPaired { return "Credentials saved" }
        if isPairing {
            return airlift.pairingStatus.isEmpty ? "Starting..." : airlift.pairingStatus
        }
        if case .done(false, let msg) = airlift.state { return msg }
        return "Open Settings to pair"
    }
}
