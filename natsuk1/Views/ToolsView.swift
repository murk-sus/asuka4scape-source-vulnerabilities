import SwiftUI

struct ToolsView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var airlift: AirliftBridge
    @EnvironmentObject var offsets: OffsetsStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        AirliftView().environmentObject(airlift)
                    } label: {
                        Label {
                            Text("Airlift")
                        } icon: {
                            Image(systemName: "airplane")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.tint)
                        }
                    }
                    NavigationLink {
                        OffsetsView().environmentObject(offsets)
                    } label: {
                        Label {
                            Text("Offsets")
                        } icon: {
                            Image(systemName: "list.number")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.tint)
                        }
                    }
                } header: {
                    Label("Exploit", systemImage: "cross.case.fill")
                }

                Section {
                    NavigationLink {
                        MobileGestaltView()
                    } label: {
                        Label {
                            Text("MobileGestalt")
                        } icon: {
                            Image(systemName: "wand.and.stars")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.tint)
                        }
                    }
                } header: {
                    Label("Spoof", systemImage: "wand.and.rays")
                }

                Section {
                    NavigationLink {
                        DeviceInfoView()
                    } label: {
                        Label {
                            Text("Device Info")
                        } icon: {
                            Image(systemName: "iphone.gen3")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.tint)
                        }
                    }
                    Button {
                        state.respring()
                    } label: {
                        Label {
                            Text("Respring")
                        } icon: {
                            Image(systemName: "arrow.clockwise.circle")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.tint)
                        }
                    }
                } header: {
                    Label("Device", systemImage: "ipad.and.iphone")
                }

                Section {
                    NavigationLink {
                        PathAccessView()
                    } label: {
                        Label {
                            Text("Path Access")
                        } icon: {
                            Image(systemName: "folder.badge.gearshape")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.tint)
                        }
                    }
                } header: {
                    Label("Diagnostics", systemImage: "stethoscope")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Tools")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
