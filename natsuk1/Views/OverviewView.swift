import SwiftUI
import UIKit

struct OverviewView: View {
    @EnvironmentObject var state: AppState
    @State private var copied = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { state.necp_run() } label: {
                        HStack {
                            Text("Run Exploit")
                            Spacer()
                            ProgressView().opacity(state.running ? 1 : 0)
                        }
                    }
                    .disabled(state.running)

                    Button(role: .destructive) { state.cancel() } label: {
                        Text("Cancel Exploit")
                    }
                    .disabled(!state.running)
                } header: {
                    Label("Exploit", systemImage: "cpu")
                }

                RuntimeView()
                    .environmentObject(state)

                Section {
                    LogTerminal(text: state.log.isEmpty ? "Awaiting execution." : state.log)
                } header: {
                    Label(state.t("Logs", "Логи"), systemImage: "terminal")
                }

                Section {
                    Button {
                        UIPasteboard.general.string = state.log
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            copied = false
                        }
                    } label: {
                        Text(copied ? "Copied!" : state.t("Copy All", "Копировать всё"))
                    }
                    .disabled(state.log.isEmpty)

                    Button(role: .destructive) { state.clear() } label: {
                        Text(state.t("Clear", "Очистить"))
                    }
                    .disabled(state.log.isEmpty)
                } header: {
                    Label("Log Actions", systemImage: "document.on.document")
                }
            }
            .listStyle(.insetGrouped)
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
        }
        .frame(minHeight: 200, maxHeight: 400)
    }
}
