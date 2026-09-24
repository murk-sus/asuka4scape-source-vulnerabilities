import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var state: AppState
    @EnvironmentObject var offsets: OffsetsStore

    @AppStorage("auto_run")   private var auto_run: Bool = false
    @AppStorage("verbose")    private var verbose: Bool = true
    @AppStorage("keep_alive") private var keep_alive: Bool = false

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

    private var kernelcacheStatus: String {
        guard let path = state.kernelcachePath else { return "Not loaded" }
        return URL(fileURLWithPath: path).lastPathComponent
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
                            Text("Version \(version) (Release)")
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
                    HStack(spacing: 10) {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        Text("Kernelcache")
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 8)
                        Text(kernelcacheStatus)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding(.vertical, 2)

                    Button {
                        state.fetchKernelcache()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "square.and.arrow.down")
                                .foregroundStyle(.tint)
                                .frame(width: 20)
                            Text(state.fetchingKernelcache ? "Fetching..." : "Import")
                                .foregroundStyle(.tint)
                            Spacer(minLength: 8)
                            if state.fetchingKernelcache {
                                ProgressView().scaleEffect(0.8)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(state.fetchingKernelcache)

                    Button {
                        state.parseKernelcache()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "wand.and.stars")
                                .foregroundStyle(.tint)
                                .frame(width: 20)
                            Text("Auto-Detect Offsets")
                                .foregroundStyle(.tint)
                            Spacer(minLength: 8)
                            if state.parsingKernelcache {
                                ProgressView().scaleEffect(0.8)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(state.kernelcachePath == nil || state.parsingKernelcache)

                    Button {
                        let r = KernelRW.shared.testRoundTrip()
                        state.append("[/] Test R/W: \(r)")
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.shield")
                                .foregroundStyle(.tint)
                                .frame(width: 20)
                            Text("Test R/W")
                                .foregroundStyle(.tint)
                            Spacer(minLength: 8)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        state.fetchImages()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "square.stack.3d.down.right")
                                .foregroundStyle(.tint)
                                .frame(width: 20)
                            Text("Fetch Images")
                                .foregroundStyle(.tint)
                            Spacer(minLength: 8)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(state.fetchingKernelcache)
                } header: {
                    Label("Kernelcache", systemImage: "shippingbox")
                }

                Section {
                    Toggle("Auto Run on Launch", isOn: $auto_run)
                    Toggle("Verbose Output", isOn: $verbose)
                    Toggle("Keep Alive", isOn: $keep_alive)
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
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .tint(.blue)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
