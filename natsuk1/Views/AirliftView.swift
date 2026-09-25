import SwiftUI
import UIKit

struct AirliftView: View {
    @EnvironmentObject var airlift: AirliftBridge
    @State private var didLogPaths = false

    private var localDevVPNUp: Bool {
        NetworkStatus.interfaces().contains {
            NetworkStatus.isTunnelInterface($0.name)
        }
    }

    var body: some View {
        List {
            if !localDevVPNUp {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.orange)
                        Text("LocalDevVPN is not active. Enable it before running Airlift.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }

            switch airlift.state {
            case .idle, .pairing:
                pairingSection
            case .ready, .running, .done:
                exploitSection
            }

            Section {
                AirliftLogView(lines: airlift.exploitLog, onClear: { airlift.clearLog() })
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            } header: {
                Label("Log", systemImage: "terminal")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Airlift")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !didLogPaths {
                didLogPaths = true
                airlift.logAccessibleFolders()
            }
        }
    }

    @ViewBuilder
    private var pairingSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(airlift.hasPairing() ? .green : .orange)
                    Text(airlift.hasPairing() ? "Paired" : "Not paired")
                        .font(.subheadline.bold())
                }
            }
            .padding(.vertical, 4)

            if case .pairing = airlift.state {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.85)
                    Text(airlift.pairingStatus.isEmpty ? "Starting..." : airlift.pairingStatus)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            if let pin = airlift.pairPIN {
                VStack(alignment: .leading, spacing: 10) {
                    Text("ENTER THIS PIN")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    Text(pin)
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundStyle(.orange)
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Open Settings", systemImage: "arrow.up.forward.app")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                .padding(12)
                .background(Color.orange.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        } header: {
            Label("Pairing", systemImage: "antenna.radiowaves.left.and.right")
        }

        Section {
            if case .pairing = airlift.state {
                Button(role: .destructive) {
                    airlift.cancelPairing()
                } label: {
                    Text("Cancel Pairing").frame(maxWidth: .infinity)
                }
            } else if airlift.hasPairing() {
                Button(role: .destructive) {
                    airlift.deletePairing()
                } label: {
                    Text("Delete Pairing").frame(maxWidth: .infinity)
                }
            } else {
                Button {
                    airlift.runPairing()
                } label: {
                    HStack {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.tint)
                        Text("Start Pairing")
                        Spacer()
                    }
                }
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
                    get: { airlift.target },
                    set: { airlift.target = $0 }
                ))
                .font(.system(size: 12, design: .monospaced))
                .multilineTextAlignment(.trailing)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            }
        } header: {
            Label("Exploit", systemImage: "scope")
        }

        Section {
            Button {
                airlift.runExploit()
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.tint)
                    Text("Run Exploit")
                    Spacer()
                }
            }
            .disabled(airlift.state == .running || !localDevVPNUp)

            Button {
                airlift.respring()
            } label: {
                HStack {
                    Image(systemName: "restart")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.tint)
                    Text("Respring (device)")
                    Spacer()
                }
            }
            .disabled(airlift.state == .running)

            Button(role: .destructive) {
                airlift.deletePairing()
            } label: {
                Text("Delete Pairing").frame(maxWidth: .infinity)
            }
            .disabled(airlift.state == .running)
        }
    }
}

struct AirliftLogView: View {
    let lines: [String]
    let onClear: () -> Void
    @State private var copied = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                Text(lines.isEmpty ? "No output yet." : lines.joined(separator: "\n"))
                    .font(.system(size: 9, design: .monospaced))
                    .multilineTextAlignment(.leading)
                    .foregroundColor(lines.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0).id(0)
            }
            .frame(maxHeight: 260)
            .padding(10)
            .background(.regularMaterial,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onChange(of: lines.count) { _, _ in
                withAnimation(.linear(duration: 0.05)) {
                    proxy.scrollTo(0, anchor: .bottom)
                }
            }
        }
        .contextMenu {
            Button {
                UIPasteboard.general.string = lines.joined(separator: "\n")
            } label: {
                Label("Copy All", systemImage: "document.on.document")
            }
            Button(role: .destructive) {
                onClear()
            } label: {
                Label("Clear", systemImage: "trash")
            }
        }
    }
}
