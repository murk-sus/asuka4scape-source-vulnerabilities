import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        TabView {
            OverviewView()
                .tabItem { Label(state.t("Overview", "Обзор"), systemImage: "square.grid.2x2") }
            ToolsView()
                .tabItem { Label(state.t("Tools", "Инструменты"), systemImage: "hammer") }
            SettingsView()
                .tabItem { Label(state.t("Settings", "Настройки"), systemImage: "gearshape.fill") }
        }
        .tint(.accentColor)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("natsuk1.respring"))) { _ in
            state.show_respring = true
        }
        .overlay(RespringView().opacity(state.show_respring ? 1 : 0).ignoresSafeArea())
    }
}
