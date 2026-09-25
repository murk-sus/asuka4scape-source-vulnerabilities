import SwiftUI

struct ToolsView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var airlift: AirliftBridge
    @EnvironmentObject var offsets: OffsetsStore
    @State private var show_device = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        AirliftView().environmentObject(airlift)
                    } label: {
                        Label("Airlift", systemImage: "airplane")
                    }
                    NavigationLink {
                        OffsetsView().environmentObject(offsets)
                    } label: {
                        Label("Offsets", systemImage: "list.number")
                    }
                } header: {
                    Label("Exploit", systemImage: "bolt.shield")
                }

                Section {
                    Button {
                        show_device = true
                    } label: {
                        Label("Device Info", systemImage: "iphone")
                    }
                    Button {
                        state.respring()
                    } label: {
                        Label("Respring", systemImage: "arrow.clockwise")
                    }
                } header: {
                    Label("Device", systemImage: "cpu")
                }

                Section {
                    NavigationLink {
                        PathAccessView()
                    } label: {
                        Label("Path Access", systemImage: "folder.badge.gearshape")
                    }
                } header: {
                    Label("Diagnostics", systemImage: "checkmark.shield")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Tools")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $show_device) {
                DeviceInfoView()
                    .presentationBackground(Color(UIColor.systemGroupedBackground))
            }
        }
    }
}
