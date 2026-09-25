import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @AppStorage("auto_run") private var auto_run: Bool = false
    @AppStorage("verbose") private var verbose: Bool = true
    @AppStorage("keep_alive_audio") private var keep_alive_audio: Bool = false
    @AppStorage("keep_alive_location") private var keep_alive_location: Bool = false

    private var appName: String {
        Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
            ?? Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "natsuk1"
    }
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    private var appIcon: UIImage? {
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String],
           let last = files.last { return UIImage(named: last) }
        return UIImage(named: "AppIcon")
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Group {
                            if let icon = appIcon {
                                Image(uiImage: icon).resizable().aspectRatio(contentMode: .fill)
                            } else {
                                ZStack {
                                    LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.6)],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                                    Image(systemName: "bolt.fill").font(.system(size: 26, weight: .semibold)).foregroundStyle(.white)
                                }
                            }
                        }
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(appName).font(.title3).fontWeight(.semibold)
                            Text("Version \(version)").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    NavigationLink { AboutView().environmentObject(state) } label: { Text("About") }
                } header: {
                    Label("App", systemImage: "person.crop.circle")
                }

                Section {
                    Toggle(isOn: $keep_alive_audio) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Silent Audio")
                            Text("Keeps the app running in the background.").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Toggle(isOn: $keep_alive_location) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Background Location")
                            Text("Low-accuracy location keeps the app alive.").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Label("Background Keep-Alive", systemImage: "moon.stars")
                }

                Section {
                    Toggle("Auto Run on Launch", isOn: $auto_run)
                    Toggle("Verbose Output", isOn: $verbose)
                } header: {
                    Label("Options", systemImage: "slider.horizontal.3")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
