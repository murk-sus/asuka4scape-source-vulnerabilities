import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var state: AppState
    @EnvironmentObject var offsets: OffsetsStore

    @AppStorage("auto_run")   private var auto_run: Bool = false
    @AppStorage("verbose")    private var verbose: Bool = true
    @AppStorage("keep_alive_audio")    private var keep_alive_audio: Bool = false
    @AppStorage("keep_alive_location") private var keep_alive_location: Bool = false

    private var appName: String {
        Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
            ?? Bundle.main.infoDictionary?["CFBundleName"] as? String
            ?? "natsuk1"
    }

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var appIcon: UIImage? {
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String],
           let last = files.last {
            return UIImage(named: last)
        }
        return UIImage(named: "AppIcon")
    }

    private var activeVersionLabel: String {
        guard let v = OffsetsStore.activeVersion else { return "unknown" }
        return "\(v.device) / iOS \(v.ios) (\(v.build))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Group {
                            if let icon = appIcon {
                                Image(uiImage: icon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                ZStack {
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.65, green: 0.30, blue: 0.90),
                                            Color(red: 0.30, green: 0.65, blue: 0.95)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 26, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(appName)
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text("Version \(version)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer(minLength: 8)
                    }
                    .padding(.vertical, 4)

                    NavigationLink {
                        AboutView().environmentObject(state)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            Text("Credits")
                                .foregroundStyle(.primary)
                            Spacer(minLength: 8)
                        }
                        .contentShape(Rectangle())
                    }
                } header: {
                    Label("About", systemImage: "info.circle")
                }

                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "cpu")
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        Text("Offsets")
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 8)
                        Text(activeVersionLabel)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding(.vertical, 2)

                    NavigationLink {
                        OffsetsView().environmentObject(offsets)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "list.number")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            Text("Modify Offsets")
                                .foregroundStyle(.primary)
                            Spacer(minLength: 8)
                            Text("\(offsets.filledCount())/\(offsets.totalCount())")
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                } header: {
                    Label("Exploit", systemImage: "cpu")
                }

                Section {
                    Toggle(isOn: $keep_alive_audio) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Silent Audio")
                            Text("Plays inaudible audio so iOS keeps the app running.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Toggle(isOn: $keep_alive_location) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Background Location")
                            Text("Uses low-accuracy location to stay alive when an activity needs it.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Label("Background Keep-Alive", systemImage: "waveform.circle")
                }

                Section {
                    Toggle("Auto Run on Launch", isOn: $auto_run)
                    Toggle("Verbose Output", isOn: $verbose)
                } header: {
                    Label("Options", systemImage: "gearshape")
                }

                Section {
                    Button {
                        state.respring()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            Text("Respring")
                                .foregroundStyle(.primary)
                            Spacer(minLength: 8)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        state.clear()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "trash")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            Text("Clear Log")
                                .foregroundStyle(.primary)
                            Spacer(minLength: 8)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } header: {
                    Label("Tools", systemImage: "wrench.and.screwdriver")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
