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
                        HStack(spacing: 12) {
                            Image(systemName: "bolt.fill")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.tint)
                                .frame(width: 22, alignment: .center)
                            Text(state.t("Run Exploit", "Запустить эксплойт"))
                                .foregroundStyle(.primary)
                            Spacer(minLength: 8)
                            if state.running {
                                ProgressView().scaleEffect(0.8)
                            }
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
                        Circle()
                            .fill(state.status.color)
                            .frame(width: 8, height: 8)
                            .shadow(color: state.status.color.opacity(0.7), radius: 3)
                    }
                } header: {
                    Label(state.t("Runtime", "Состояние"), systemImage: "waveform.path.ecg")
                } footer: {
                    Text(DeviceName.full())
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Section {
                    OverviewLogView()
                        .environmentObject(state)
                        .terminalPlatter()
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                } header: {
                    Label(state.t("Logs", "Логи"), systemImage: "text.alignleft")
                }

                Section {
                    Button {
                        UIPasteboard.general.string = state.log
                    } label: {
                        Label(state.t("Copy All", "Копировать всё"),
                              systemImage: "document.on.document")
                    }
                    .disabled(state.log.isEmpty)

                    Button(role: .destructive) {
                        state.clear()
                    } label: {
                        Label(state.t("Clear", "Очистить"),
                              systemImage: "trash")
                    }
                    .disabled(state.log.isEmpty)
                } header: {
                    Label(state.t("Log Actions", "Действия с логом"), systemImage: "ellipsis.circle")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("natsuk1")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct OverviewLogView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                Text(state.log.isEmpty ? "Awaiting execution." : state.log)
                    .font(.system(size: 10, design: .monospaced))
                    .multilineTextAlignment(.leading)
                    .foregroundColor(state.log.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0).id(0)
            }
            .onChange(of: state.log) { _, _ in
                withAnimation(.linear(duration: 0.05)) {
                    proxy.scrollTo(0, anchor: .bottom)
                }
            }
        }
    }
}

extension View {
    func terminalPlatter() -> some View {
        self
            .frame(maxWidth: .infinity)
            .frame(minHeight: 180, idealHeight: 260, maxHeight: 400)
            .padding(10)
            .background(.regularMaterial,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
