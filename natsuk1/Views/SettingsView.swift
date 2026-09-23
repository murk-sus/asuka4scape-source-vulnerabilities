import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var state: AppState

    @AppStorage("auto_run") private var auto_run: Bool = false
    @AppStorage("verbose")  private var verbose: Bool = true

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
                    Toggle(state.t("Auto Run on Launch", "Автозапуск при открытии"), isOn: $auto_run)
                    Toggle(state.t("Verbose Output", "Подробный вывод"), isOn: $verbose)
                } header: {
                    Label(state.t("Options", "Опции"), systemImage: "gearshape")
                }

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
                    Label(state.t("Exploit", "Эксплойт"), systemImage: "wrench.and.screwdriver")
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

                Section {
                    NavigationLink {
                        AboutView().environmentObject(state)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            Text(state.t("About", "О программе"))
                                .foregroundStyle(.primary)
                            Spacer(minLength: 8)
                        }
                        .contentShape(Rectangle())
                    }
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
