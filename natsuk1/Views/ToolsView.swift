import SwiftUI

struct ToolsView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var airlift: AirliftBridge
    @EnvironmentObject var offsets: OffsetsStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink { AirliftView().environmentObject(airlift) } label: { Text("Airlift") }
                    NavigationLink { OffsetsView().environmentObject(offsets) } label: { Text("Offsets") }
                } header: {
                    Label("Exploit", systemImage: "flame")
                }

                Section {
                    NavigationLink { DeviceInfoView() } label: { Text("Device Info") }
                    Button { state.respring() } label: { Text("Respring") }
                } header: {
                    Label("Device", systemImage: "iphone.gen3")
                }

                Section {
                    NavigationLink { PathAccessView() } label: { Text("Path Access") }
                } header: {
                    Label("Diagnostics", systemImage: "waveform.path.ecg.rectangle")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Tools")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
