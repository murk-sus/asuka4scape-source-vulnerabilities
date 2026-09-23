import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var state: AppState

    @AppStorage("auto_run") private var auto_run: Bool = false
    @AppStorage("verbose")  private var verbose: Bool = true

    @State private var show_respring_confirm: Bool = false

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
                    Button {
                        state.run()
                    } label: {
                        Label(state.t("Run Exploit", "Запустить эксплойт"), systemImage: "bolt.fill")
                    }
                    .disabled(state.running)

                    Button {
                        state.slideOnly()
                    } label: {
                        Label(state.t("Slide Only", "Только слайд"), systemImage: "scope")
                    }
                    .disabled(state.running)
                } header: {
                    Label(state.t("Exploit", "Эксплойт"), systemImage: "wrench.and.screwdriver")
                } footer: {
                    Text(state.t("Runs KASLR bypass (vote-based slide detection). Full chain is under development.",
                                 "Запускает обход KASLR (поиск слайда через голосование). Полная цепочка в разработке."))
                }

                Section {
                    Toggle(state.t("Auto Run on Launch", "Автозапуск при открытии"), isOn: $auto_run)
                    Toggle(state.t("Verbose Output", "Подробный вывод"), isOn: $verbose)
                } header: {
                    Label(state.t("Options", "Опции"), systemImage: "gearshape")
                }

                Section {
                    Button {
                        show_respring_confirm = true
                    } label: {
                        Label(state.t("Respring", "Респринг"), systemImage: "arrow.clockwise")
                    }
                } header: {
                    Label(state.t("Tools", "Инструменты"), systemImage: "wrench.and.screwdriver")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(state.t("Settings", "Настройки"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(state.t("Done", "Готово")) { dismiss() }
                }
            }
            .alert(state.t("Are you sure?", "Ты уверен?"), isPresented: $show_respring_confirm) {
                Button(state.t("Cancel", "Отмена"), role: .cancel) { }
                Button(state.t("Respring", "Респринг"), role: .destructive) {
                    state.respring()
                }
            } message: {
                Text(state.t("Confirm that you want to respring.",
                             "Подтверди, что хочешь сделать респринг."))
            }
        }
    }
}
