import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject var state: AppState

    @State private var show_settings: Bool = false
    @State private var show_device: Bool = false
    @State private var copied: Bool = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        state.run()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "bolt.fill")
                                .frame(width: 22, alignment: .center)
                            Text(state.t("Run Exploit", "Запустить эксплойт"))
                            Spacer(minLength: 8)
                            if state.running {
                                ProgressView().scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(state.running)
                } header: {
                    Label(state.t("Actions", "Действия"), systemImage: "play.circle")
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
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            copied = false
                        }
                    } label: {
                        Text(copied
                             ? state.t("Copied!", "Скопировано!")
                             : state.t("Copy All", "Копировать всё"))
                    }

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
            ScrollView(.horizontal, showsIndicators: false) {
                ScrollView(.vertical, showsIndicators: false) {
                    Text(state.log.isEmpty ? "Awaiting execution." : state.log)
                        .font(.system(size: 9, design: .monospaced))
                        .multilineTextAlignment(.leading)
                        .foregroundColor(state.log.isEmpty ? .secondary : .primary)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 0)
                        .id(0)
                }
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
