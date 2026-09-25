import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        TabView {
            OverviewView()
                .tabItem {
                    Label(state.t("Overview", "Обзор"),
                          systemImage: "syringe.fill")
                }
            ToolsView()
                .tabItem {
                    Label(state.t("Tools", "Инструменты"),
                          systemImage: "slider.vertical.3")
                }
            SettingsView()
                .tabItem {
                    Label(state.t("Settings", "Настройки"),
                          systemImage: "gearshape.fill")
                }
        }
        .tint(.accentColor)
    }
}
