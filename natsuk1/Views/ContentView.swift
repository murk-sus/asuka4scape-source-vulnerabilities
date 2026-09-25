import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        TabView {
            OverviewView()
                .tabItem { Label(state.t("Overview", "Обзор"), systemImage: "bolt.fill") }
            ToolsView()
                .tabItem { Label(state.t("Tools", "Инструменты"), systemImage: "wrench.and.screwdriver.fill") }
            SettingsView()
                .tabItem { Label(state.t("Settings", "Настройки"), systemImage: "gearshape.fill") }
        }
        .tint(.accentColor)
    }
}
