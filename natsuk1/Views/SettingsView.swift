import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var state: AppState

    @AppStorage("auto_run")   private var auto_run: Bool = false
    @AppStorage("verbose")    private var verbose: Bool = true
    @AppStorage("kread_mode") private var kread_mode: String = "necp"

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker(state.t("Language", "Язык"), selection: $state.lang) {
                        Text("English").tag("en")
                        Text("Русский").tag("ru")
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Label(state.t("Interface", "Интерфейс"), systemImage: "globe")
                }

                Section {
                    LogView()
                        .environmentObject(state)
                        .modifier(TerminalPlatter())
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                } header: {
                    Label(state.t("Logs", "Логи"), systemImage: "apple.terminal")
                }

                Section {
                    Picker(state.t("Method", "Метод"), selection: $kread_mode) {
                        Text("NECP").tag("necp")
                        Text("MACH").tag("mach")
                    }
                    .pickerStyle(.segmented)

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
                    Label(state.t("Exploit", "Эксплойт"), systemImage: "wrench.and.screwdriver")
                } footer: {
                    Text(state.t("**NECP:** uses syscalls 501/502 for the read primitive. **MACH:** fallback via OOL spray.",
                                 "**NECP:** использует syscall 501/502 для примитива чтения. **MACH:** запасной вариант через OOL spray."))
                }

                Section {
                    Toggle(state.t("Auto Run on Launch", "Автозапуск при открытии"), isOn: $auto_run)
                    Toggle(state.t("Verbose Output", "Подробный вывод"), isOn: $verbose)
                } header: {
                    Label(state.t("Options", "Опции"), systemImage: "gearshape")
                }

                Section {
                    Button {
                        state.respring()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            Text(state.t("Respring", "Респринг"))
                                .foregroundStyle(.primary)
                            Spacer(minLength: 8)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } header: {
                    Label(state.t("Tools", "Инструменты"), systemImage: "wrench.and.screwdriver")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(state.t("Settings", "Настройки"))
            .navigationBarTitleDisplayMode(.inline)
            .tint(.blue)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(state.t("Done", "Готово")) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
