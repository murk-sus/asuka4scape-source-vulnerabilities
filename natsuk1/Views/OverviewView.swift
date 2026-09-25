import SwiftUI
import UIKit

struct OverviewView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        state.run()
                    } label: {
                        HStack {
                            Text(state.t("Run Exploit", "Запустить эксплойт"))
                            Spacer()
                            if state.running { ProgressView().scaleEffect(0.8) }
                        }
                    }
                    .disabled(state.running)
                } header: {
                    Label(state.t("Exploit", "Эксплойт"), systemImage: "bolt.shield")
                }

                Section {
                    HStack {
                        Text(state.t("Status", "Статус"))
                        Spacer()
                        Circle().fill(state.status.color).frame(width: 8, height: 8)
                    }
                } header: {
                    Label(state.t("Runtime", "Состояние"), systemImage: "waveform.path.ecg")
                } footer: {
                    Text(DeviceName.full()).font(.system(size: 12, design: .monospaced))
                }

                Section {
                    LogTerminal(text: state.log.isEmpty ? "Awaiting execution." : state.log)
                } header: {
                    Label(state.t("Logs", "Логи"), systemImage: "terminal")
                }

                Section {
                    Button { UIPasteboard.general.string = state.log } label: {
                        Text(state.t("Copy All", "Копировать всё"))
                    }.disabled(state.log.isEmpty)
                    Button(role: .destructive) { state.clear() } label: {
                        Text(state.t("Clear", "Очистить"))
                    }.disabled(state.log.isEmpty)
                } header: {
                    Label(state.t("Log Actions", "Действия с логом"), systemImage: "ellipsis.circle")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("natsuk1")
            .navigationBarTitleDisplayMode(.inline)
        }
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
