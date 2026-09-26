import SwiftUI

struct ToolsView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var airlift: AirliftBridge
    @EnvironmentObject var offsets: OffsetsStore

    var body: some View {
        NavigationStack {
            SimpleList {
                SimpleSection("Exploit", systemImage: "memorychip") {
                    NavigationLink { AirliftView().environmentObject(airlift) } label: {
                        navRow("Airlift")
                    }
                    Divider()
                    NavigationLink { OffsetsView().environmentObject(offsets) } label: {
                        navRow("Offsets")
                    }
                }

                SimpleSection("Device", systemImage: "gearshape.2") {
                    NavigationLink { DeviceInfoView() } label: {
                        navRow("Device Info")
                    }
                    Divider()
                    Button { state.respring() } label: {
                        HStack {
                            Text("Respring")
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                }

                SimpleSection("Diagnostics", systemImage: "chart.xyaxis.line") {
                    NavigationLink { PathAccessView() } label: {
                        navRow("Path Access")
                    }
                }
            }
            .navigationTitle("Tools")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private func navRow(_ title: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
