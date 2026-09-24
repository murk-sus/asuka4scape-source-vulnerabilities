import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var state: AppState
    @EnvironmentObject var offsets: OffsetsStore

    @AppStorage("auto_run") private var auto_run: Bool = false
    @AppStorage("verbose")  private var verbose: Bool = true
    @AppStorage("keep_alive") private var keep_alive: Bool = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        appIcon
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("natsuk1")
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text("Version 4.1 (Release)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer(minLength: 8)
                    }
                    .padding(.vertical, 4)

                    NavigationLink {
                        AboutView().environmentObject(state)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            Text(state.t("Credits", "Авторы"))
                                .foregroundStyle(.primary)
                            Spacer(minLength: 8)
                        }
                        .contentShape(Rectangle())
                    }
                } header: {
                    Label(state.t("About", "О программе"), systemImage: "info.circle")
                }

                Section {
                    NavigationLink {
                        OffsetsView()
                            .environmentObject(offsets)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "list.number")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            Text(state.t("Modify Offsets", "Изменить оффсеты"))
                                .foregroundStyle(.primary)
                            Spacer(minLength: 8)
                            Text("\(offsets.filledCount())/\(offsets.totalCount())")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                } header: {
                    Label(state.t("Exploit", "Эксплойт"), systemImage: "cpu")
                }

                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        Text(state.t("Kernelcache", "Kernelcache"))
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 8)
                        Text(state.t("Not loaded", "Не загружен"))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Label(state.t("Kernelcache", "Kernelcache"), systemImage: "shippingbox")
                } footer: {
                    Text(state.t(
                        "Kernelcache loading is not implemented in this build.",
                        "Загрузка kernelcache в этой сборке не реализована."
                    ))
                }

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
                    Toggle(state.t("Keep Alive", "Не выгружать"), isOn: $keep_alive)
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

                    Button {
                        state.clear()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "trash")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            Text(state.t("Clear Log", "Очистить лог"))
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

    private var appIcon: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.65, green: 0.30, blue: 0.90),
                    Color(red: 0.30, green: 0.65, blue: 0.95)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "ladybug.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}
