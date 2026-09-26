import SwiftUI
import UIKit

struct OverviewView: View {
    @EnvironmentObject var state: AppState
    @State private var copied = false

    var body: some View {
        NavigationStack {
            SimpleList {
                SimpleSection("Exploit", systemImage: "cpu") {
                    Button { state.necp_run() } label: {
                        HStack {
                            Text("Run Exploit")
                            Spacer()
                            ProgressView().opacity(state.running ? 1 : 0)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                    .disabled(state.running)

                    Divider()

                    Button(role: .destructive) { state.cancel() } label: {
                        Text("Cancel Exploit")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                    }
                    .disabled(!state.running)
                }

                SimpleSection("Runtime", systemImage: "waveform.path.ecg") {
                    HStack {
                        Text("Slide")
                        Spacer()
                        Text(state.slide)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(state.slide != "—" ? .green : .secondary)
                            .lineLimit(1).truncationMode(.middle)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)

                    Divider()

                    HStack {
                        Text("Base")
                        Spacer()
                        Text(state.base)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(state.base != "—" ? .green : .secondary)
                            .lineLimit(1).truncationMode(.middle)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)

                    Divider()

                    HStack {
                        Text("Status")
                        Spacer()
                        StatusDot(status: state.status)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }

                SimpleSection(state.t("Logs", "Логи"), systemImage: "terminal") {
                    LogTerminal(text: state.log.isEmpty ? "Awaiting execution." : state.log)
                }

                SimpleSection("Log Actions", systemImage: "document.on.document") {
                    Button {
                        UIPasteboard.general.string = state.log
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            copied = false
                        }
                    } label: {
                        Text(copied ? "Copied!" : state.t("Copy All", "Копировать всё"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                    }
                    .disabled(state.log.isEmpty)

                    Divider()

                    Button(role: .destructive) { state.clear() } label: {
                        Text(state.t("Clear", "Очистить"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                    }
                    .disabled(state.log.isEmpty)
                }
            }
            .navigationTitle("natsuk1")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct StatusDot: View {
    let status: AppState.Status
    @State private var pulse = false

    var body: some View {
        Image(systemName: "circle.fill")
            .font(.system(size: 14))
            .foregroundStyle(status.color)
            .shadow(color: status.color.opacity(0.85), radius: pulse ? 8 : 4)
            .animation(
                status == .running
                    ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                    : .default,
                value: pulse
            )
            .onAppear { if status == .running { pulse = true } }
            .onChange(of: status) { _, s in pulse = (s == .running) }
    }
}

struct LogTerminal: View {
    let text: String
    var body: some View {
        ScrollView {
            Text(text)
                .font(.system(size: 10, design: .monospaced))
                .multilineTextAlignment(.leading)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
        }
        .frame(minHeight: 200, maxHeight: 400)
    }
}
