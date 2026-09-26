import SwiftUI
import UIKit
import Combine

struct AirliftView: View {
    @EnvironmentObject var airlift: AirliftBridge
    @State private var loopbackVPNUp: Bool = NetworkStatus.loopbackVPNUp()
    @State private var tunnelIP: String? = NetworkStatus.tunnelIP()
    @State private var deviceIP: String? = NetworkStatus.deviceIP()
    @State private var copied = false

    private let ticker = Timer.publish(every: 3.0, on: .main, in: .common).autoconnect()

    var body: some View {
        List {
            networkSection
            if airlift.hasPairing() {
                exploitSection
            } else {
                pairingSection
            }
            logSection
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

    @ViewBuilder
    private var networkSection: some View {
        if !loopbackVPNUp {
            Section {
                HStack(spacing: 10) {
                    Image(systemName: "wifi.exclamationmark")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Loopback VPN is not active")
                            .font(.subheadline).fontWeight(.semibold)
                        Text("Start LocalDevVPN (10.7.0.x)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            } header: {
                Label("Network", systemImage: "network")
            }
        } else {
            Section {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(.green)
                    Text("Loopback VPN active")
                        .font(.subheadline).fontWeight(.semibold)
                }
                if let t = tunnelIP {
                    HStack {
                        Text("Tunnel")
                        Spacer()
                        Text(t).font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                if let d = deviceIP {
                    HStack {
                        Text("Device")
                        Spacer()
                        Text(d).font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Label("Network", systemImage: "network")
            }
        }
    }

    @ViewBuilder
    private var pairingSection: some View {
        Section {
            HStack(spacing: 8) {
                Image(systemName: pairingStatusIcon)
                    .foregroundStyle(pairingStatusColor)
                Text(pairingStatusText).font(.subheadline.bold())
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
                    Text(pin).font(.system(size: 34, weight: .black, design: .monospaced))
                        .foregroundStyle(.orange)
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Open Settings", systemImage: "arrow.up.forward.app")
                            .frame(maxWidth: .infinity)
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
            if case .pairing = airlift.state {
                Button(role: .destructive) { airlift.cancelPairing() } label: {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("Cancel Pairing")
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                Button { airlift.runPairing() } label: {
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                        Text("Start Pairing")
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var pairingStatusText: String {
        switch airlift.state {
        case .pairing: return "Pairing…"
        case .ready:   return "Paired"
        case .running: return "Exploit running…"
        case .done(let ok, _): return ok ? "Done" : "Failed"
        default:       return "Not paired"
        }
    }

    private var pairingStatusIcon: String {
        switch airlift.state {
        case .pairing: return "hourglass"
        case .ready:   return "link.circle.fill"
        case .running: return "bolt.fill"
        case .done(let ok, _): return ok ? "checkmark.circle.fill" : "xmark.circle.fill"
        default:       return "link.badge.plus"
        }
    }

    private var pairingStatusColor: Color {
        switch airlift.state {
        case .pairing: return .orange
        case .ready:   return .green
        case .running: return .orange
        case .done(let ok, _): return ok ? .green : .red
        default:       return .orange
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

            Button(role: .destructive) {
                airlift.cancelExploit()
            } label: {
                HStack {
                    Image(systemName: "xmark.circle")
                    Text("Cancel Exploit")
                }
            }
            .disabled(airlift.state != .running)

            Button { respring() } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Respring")
                }
            }
        } header: {
            Label("Exploit", systemImage: "bolt.shield")
        }

        Section {
            Button(role: .destructive) { airlift.deletePairing() } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete Pairing")
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func respring() {
        NotificationCenter.default.post(
            name: Notification.Name("natsuk1.respring"),
            object: nil
        )
    }

    @ViewBuilder
    private var logSection: some View {
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
                HStack {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    Text(copied ? "Copied!" : "Copy All")
                }
            }
            .disabled(airlift.exploitLog.isEmpty)

            Button(role: .destructive) { airlift.clearLog() } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Clear")
                }
            }
            .disabled(airlift.exploitLog.isEmpty)
        }
    }
}
