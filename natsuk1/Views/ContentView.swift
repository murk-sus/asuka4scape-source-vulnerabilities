import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var airlift: AirliftBridge

    @State private var show_settings: Bool = false
    @State private var show_device: Bool = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        AirliftView().environmentObject(airlift)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "airplane")
                                .frame(width: 22, alignment: .center)
                            Text(state.t("Airlift", "Airlift"))
                            Spacer(minLength: 8)
                            Text(airlift.hasPairing() ? "Ready" : "Setup")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Label(state.t("Sandbox Escape", "Побег из песочницы"), systemImage: "bolt.shield")
                }

                Section {
                    Button {
                        state.run()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "bolt.fill")
                                .frame(width: 22, alignment: .center)
                            Text(state.t("Run Offsets", "Показать оффсеты"))
                            Spacer(minLength: 8)
                            if state.running {
                                ProgressView().scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(state.running)
                } header: {
                    Label(state.t("Kernel Offsets", "Оффсеты ядра"), systemImage: "cpu")
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

                    Button {
                        show_device = true
                    } label: {
                        HStack(spacing: 8) {
                            Text(state.t("Device", "Устройство"))
                                .foregroundColor(.primary)
                            Spacer(minLength: 8)
                            Text(DeviceName.full())
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(UIColor.tertiaryLabel))
                        }
                    }
                } header: {
                    Label(state.t("Runtime", "Состояние"), systemImage: "waveform.path.ecg")
                }

                Section {
                    LogView()
                        .environmentObject(state)
                        .terminalPlatter()
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                } header: {
                    Label(state.t("Logs", "Логи"), systemImage: "apple.terminal")
                }

                Section {
                    Button {
                        UIPasteboard.general.string = state.log
                    } label: {
                        Text(state.t("Copy All", "Копировать всё"))
                    }
                    .disabled(state.log.isEmpty)

                    Button(role: .destructive) {
                        state.clear()
                    } label: {
                        Text(state.t("Clear", "Очистить"))
                    }
                    .disabled(state.log.isEmpty)
                } header: {
                    Label(state.t("Log Actions", "Действия с логом"), systemImage: "doc.on.doc")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("natsuk1")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        show_settings = true
                    } label: {
                        Image(systemName: "gear")
                            .foregroundStyle(Color(UIColor.tertiaryLabel))
                    }
                }
            }
            .sheet(isPresented: $show_settings) {
                SettingsView()
                    .environmentObject(state)
                    .presentationBackground(Color(UIColor.systemGroupedBackground))
            }
            .sheet(isPresented: $show_device) {
                DeviceInfoView()
                    .presentationBackground(Color(UIColor.systemGroupedBackground))
            }
        }
    }
}

struct LogView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                Text(state.log.isEmpty ? "Awaiting execution." : state.log)
                    .font(.system(size: 10, design: .monospaced))
                    .multilineTextAlignment(.leading)
                    .foregroundColor(state.log.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)
                    .id(0)
            }
            .onChange(of: state.log) { _, _ in
                withAnimation(.linear(duration: 0.05)) {
                    proxy.scrollTo(0, anchor: .bottom)
                }
            }
        }
    }
}

private extension View {
    func terminalPlatter() -> some View {
        self
            .frame(maxWidth: .infinity)
            .frame(minHeight: 180, idealHeight: 260, maxHeight: 400)
            .padding(10)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
