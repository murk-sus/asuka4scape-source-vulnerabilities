ftUI

lsView: View {
onmentObject var state: AppState
onmentObject var airlift: AirliftBridge
onmentObject var offsets: OffsetsStore

dy: some View {
vigationStack {
  List {
      Section {
          NavigationLink { AirliftView().environmentObject(airlift) } label: { Text("Airlift") }
          NavigationLink { CarrierLabView() } label: { Text("CarrierLab") }
          NavigationLink { OffsetsView().environmentObject(offsets) } label: { Text("Offsets") }
      } header: {
          Label("Exploit", systemImage: "memorychip")
      }

      Section {
          NavigationLink { DeviceInfoView() } label: { Text("Device Info") }
          Button { state.respring() } label: { Text("Respring") }
      } header: {
          Label("Device", systemImage: "gearshape.2")
      }

      Section {
          NavigationLink { PathAccessView() } label: { Text("Path Access") }
      } header: {
          Label("Diagnostics", systemImage: "chart.xyaxis.line")
      }
  }
  .listStyle(.insetGrouped)
  .navigationTitle("Tools")
  .navigationBarTitleDisplayMode(.large)



