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
            networkSection
            if airlift.hasPairing() {
                exploitSection
            } else {
                pairingSection
            }
            logSection
            logActionsSection
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
        Section {
            if loopbackVPNUp {
                HStack {
                    Text("Status")
                    Spacer()
                    Text("active")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.green)
                }
                if let t = tunnelIP {
                    HStack {
                        Text("Tunnel")
                        Spacer()
                        Text(t)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                if let d = deviceIP {
                    HStack {
                        Text("Device")
                        Spacer()
                        Text(d)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                HStack {
                    Text("Status")
                    Spacer()
                    Text("not active")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.orange)
                }
                Text("Start LocalDevVPN with interface 10.7.0.x")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Label("Network", systemImage: "network")
        }
    }

    @ViewBuilder
    private var pairingSection: some View {
        Section {
            HStack {
                Text("State")
                Spacer()
                Text(pairingStatusText)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(pairingStatusColor)
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
            if case .pairing = airlift.state {
                Button(role: .destructive) { airlift.cancelPairing() } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "xmark").font(.system(size: 16, weight: .semibold)).frame(width: 22)
                        Text("Cancel Pairing")
                    }
                }
            } else {
                Button { airlift.runPairing() } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "antenna.radiowaves.left.and.right").font(.system(size: 16, weight: .semibold)).foregroundStyle(.blue).frame(width: 22)
                        Text("Start Pairing")
                    }
                }
            }
        }
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

    @ViewBuilder
    private var exploitSection: some View {
        Section {
            HStack {
                Text("State")
                Spacer()
                Text(pairingStatusText)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(pairingStatusColor)
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
                HStack(spacing: 12) {
                    Image(systemName: "bolt.fill").font(.system(size: 16, weight: .semibold)).foregroundStyle(.blue).frame(width: 22)
                    Text("Run Exploit")
                }
            }
            .disabled(airlift.state == .running || !loopbackVPNUp)

            Button(role: .destructive) { airlift.cancelExploit() } label: {
                HStack(spacing: 12) {
                    Image(systemName: "xmark").font(.system(size: 16, weight: .semibold)).frame(width: 22)
                    Text("Cancel Exploit")
                }
            }
            .disabled(airlift.state != .running)

            Button { respring() } label: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.clockwise").font(.system(size: 16, weight: .semibold)).foregroundStyle(.blue).frame(width: 22)
                    Text("Respring")
                }
            }
        } header: {
            Label("Exploit", systemImage: "bolt.shield")
        }

        Section {
            Button(role: .destructive) { airlift.deletePairing() } label: {
                HStack(spacing: 12) {
                    Image(systemName: "trash").font(.system(size: 16, weight: .semibold)).frame(width: 22)
                    Text("Delete Pairing")
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

    @ViewBuilder
    private var logSection: some View {
        Section {
            LogTerminal(text: airlift.exploitLog.isEmpty
                        ? "No output yet."
                        : airlift.exploitLog.joined(separator: "\n"))
        } header: {
            Label("Log", systemImage: "terminal")
        }
    }

    @ViewBuilder
    private var logActionsSection: some View {
        Section {
            Button {
                UIPasteboard.general.string = airlift.exploitLog.joined(separator: "\n")
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    copied = false
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(copied ? .green : .blue)
                        .frame(width: 22)
                    Text(copied ? "Copied!" : "Copy All")
                }
            }
            .disabled(airlift.exploitLog.isEmpty)

            Button(role: .destructive) { airlift.clearLog() } label: {
                HStack(spacing: 12) {
                    Image(systemName: "trash").font(.system(size: 16, weight: .semibold)).frame(width: 22)
                    Text("Clear")
                }
            }
            .disabled(airlift.exploitLog.isEmpty)
        } header: {
            Label("Log Actions", systemImage: "doc.on.clipboard")
        }
    }
}
