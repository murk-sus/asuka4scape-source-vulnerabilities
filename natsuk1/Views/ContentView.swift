import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @AppStorage("verbose")  private var verbose: Bool = true
    @AppStorage("auto_run") private var auto_run: Bool = false

    @State private var show_settings: Bool = false
    @State private var show_device: Bool = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        state.run()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "bolt.fill")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            Text(state.t("Run Exploit", "Запустить эксплойт"))
                                .foregroundStyle(.primary)
                            Spacer(minLength: 8)
                            if state.running {
                                ProgressView().scaleEffect(0.8)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(state.running)

                    Button {
                        state.slideOnly()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "scope")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            Text(state.t("Slide Only", "Только слайд"))
                                .foregroundStyle(.primary)
                            Spacer(minLength: 8)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(state.running)
                } header: {
                    Label(state.t("Actions", "Действия"), systemImage: "play.circle")
                } footer: {
                    Text(state.t("**Run Exploit** executes the full chain. **Slide Only** runs KASLR bypass in isolation.",
                                 "**Запустить эксплойт** выполняет всю цепочку. **Только слайд** запускает только обход KASLR."))
                }

                Section {
                    HStack {
                        Text(state.t("Slide", "Слайд"))
                        Spacer()
                        Text(state.slide == 0 ? "—" : String(format: "0x%llx", state.slide))
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(state.slide == 0 ? .secondary : .green)
                    }

                    HStack {
                        Text(state.t("Base", "База"))
                        Spacer()
                        Text(state.base == 0 ? "—" : String(format: "0x%llx", state.base))
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(state.base == 0 ? .secondary : .green)
                    }

                    HStack {
                        Text(state.t("Status", "Статус"))
                        Spacer()
                        statusBadge
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
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } header: {
                    Label(state.t("Runtime", "Состояние"), systemImage: "waveform.path.ecg")
                }

                Section {
                    LogView()
                        .environmentObject(state)
                        .modifier(TerminalPlatter())
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                } header: {
                    Label(state.t("Logs", "Логи"), systemImage: "apple.terminal")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("natsuk1")
            .navigationBarTitleDisplayMode(.large)
            .tint(.blue)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        show_settings = true
                    } label: {
                        Image(systemName: "gear")
                            .foregroundStyle(Color(UIColor.tertiaryLabel))
                    }
                    .buttonStyle(.plain)
                }
            }
            .sheet(isPresented: $show_settings) {
                SettingsView()
                    .environmentObject(state)
            }
            .sheet(isPresented: $show_device) {
                DeviceInfoView()
            }
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(state.status.color)
                .frame(width: 7, height: 7)
                .shadow(color: state.status.color.opacity(0.7), radius: 4)
            Text(state.status.label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(state.status.color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(state.status.color.opacity(0.12))
        .clipShape(Capsule())
    }
}
