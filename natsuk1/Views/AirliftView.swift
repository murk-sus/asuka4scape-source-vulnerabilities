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
            HStack(spacing: 12) {
                Image(systemName: loopbackVPNUp ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(loopbackVPNUp ? .green : .orange)
                    .shadow(color: (loopbackVPNUp ? Color.green : Color.orange).opacity(0.45), radius: 3)
                VStack(alignment: .leading, spacing: 3) {
                    Text("LocalDevVPN")
                    Text(loopbackVPNUp ? "Connected" : "Not connected")
                        .font(.subheadline)
                        .foregroundStyle(loopbackVPNUp ? .green : .orange)
                        .shadow(color: (loopbackVPNUp ? Color.green : Color.orange).opacity(0.45), radius: 3)
                }
                Spacer()
            }
            .padding(.vertical, 4)
        } header: { Label("VPN", systemImage: "shield.lefthalf.filled") }
    }

    private var sessionSection: some View {
        Section {
            HStack {
                Text("Tunnel IP")
                Spacer()
                Text(tunnelIP ?? "\u{2014}")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(tunnelIP != nil ? .green : .secondary)
                    .shadow(color: tunnelIP != nil ? Color.green.opacity(0.45) : Color.clear, radius: 3)
            }
            HStack {
                Text("Device IP")
                Spacer()
                Text(deviceIP ?? "\u{2014}")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(deviceIP != nil ? .green : .secondary)
                    .shadow(color: deviceIP != nil ? Color.green.opacity(0.45) : Color.clear, radius: 3)
            }
        } header: { Label("Session details", systemImage: "network") }
    }

    private var pairingStatusSection: some View {
        Section {
            if let pin = airlift.pairPIN {
                pinCard(pin: pin)
            } else {
                HStack(spacing: 12) {
                    Image(systemName: pairingIcon)
                        .font(.system(size: 22))
                        .foregroundStyle(pairingColor)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(pairingTitle)
                        Text(pairingSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(pairingColor)
                            .shadow(color: pairingColor.opacity(0.45), radius: 3)
                            .lineLimit(3)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        } header: { Label("Pairing", systemImage: "link.circle") }
    }

    @ViewBuilder
    private func pinCard(pin: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(.orange)
                    .shadow(color: Color.orange.opacity(0.45), radius: 3)
                Text("Enter this PIN in Settings")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                ForEach(Array(pin.enumerated()), id: \.offset) { _, ch in
                    Text(String(ch))
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .foregroundStyle(.orange)
                        .shadow(color: Color.orange.opacity(0.45), radius: 3)
                        .frame(width: 44, height: 56)
                        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                Spacer()
            }
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.large)
            .shadow(color: Color.orange.opacity(0.45), radius: 3)
            Text("Privacy & Security - Developer Mode - Pair with natsuk1")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }

    private var pairingButtonsSection: some View {
        Section {
            Button { airlift.runPairing() } label: {
                Text(isPaired ? "Already Paired" : "Start Pairing")
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
                    .font(.system(.footnote, design: .monospaced))
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        } header: { Label("Target", systemImage: "scope") }
    }

    private var exploitSection: some View {
        Section {
            Button { airlift.runExploit() } label: {
                HStack {
                    Text("Run Exploit")
                    Spacer()
                    if airlift.state == .running { ProgressView() }
                }
            }
            .disabled(airlift.state == .running || !loopbackVPNUp || !isPaired)
            Button(role: .destructive) { airlift.cancelExploit() } label: {
                Text("Cancel Exploit")
            }
            .disabled(airlift.state != .running)
        } header: { Label("Exploit", systemImage: "cpu") }
    }

    @ViewBuilder
    private var logSection: some View {
        if !airlift.exploitLog.isEmpty {
            Section {
                ScrollView {
                    Text(airlift.exploitLog.joined(separator: "\n"))
                        .font(.system(size: 10, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 200, maxHeight: 400)
            } header: { Label("Log", systemImage: "terminal") }
        }
    }

    @ViewBuilder
    private var logActionsSection: some View {
        if !airlift.exploitLog.isEmpty {
            Section {
                Button {
                    UIPasteboard.general.string = airlift.exploitLog.joined(separator: "\n")
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                } label: {
                    Text(copied ? "Copied" : "Copy All")
                }
                Button(role: .destructive) { airlift.clearLog() } label: {
                    Text("Clear")
                }
            } header: { Label("Log Actions", systemImage: "document.on.document") }
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
        if isPaired { return "checkmark.circle.fill" }
        if isPairing { return "link.circle.fill" }
        if case .done(false, _) = airlift.state { return "xmark.circle.fill" }
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
