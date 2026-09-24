import SwiftUI
import UIKit

struct AboutView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject var state: AppState

    private let repoURL = URL(string: "https://github.com/murk-sus/asuka4scape-source-vulnerabilities")!

    private var appName: String {
        Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
            ?? Bundle.main.infoDictionary?["CFBundleName"] as? String
            ?? "natsuk1"
    }

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private var commit: String? {
        let raw = Bundle.main.infoDictionary?["Natsuk1Commit"] as? String
        guard let raw, !raw.isEmpty else { return nil }
        return raw
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

    var body: some View {
        List {
            Section {
                header
                    .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
            }

            Section {
                linkRow(state.t("Source Repository", "Исходный код"), url: repoURL)
                linkRow(state.t("MIT License", "Лицензия MIT"),
                        url: repoURL.appendingPathComponent("blob/main/LICENSE"))
            } header: {
                Text(state.t("Open Source", "Открытый код"))
            }

            Section {
                linkRow(state.t("Star on GitHub", "Звезда на GitHub"),
                        url: repoURL.appendingPathComponent("stargazers"))
            } header: {
                Text(state.t("Community", "Сообщество"))
            }

            Section {
                NavigationLink {
                    AcknowledgementsView().environmentObject(state)
                } label: {
                    HStack {
                        Text(state.t("Acknowledgements", "Благодарности"))
                            .foregroundColor(.primary)
                        Spacer(minLength: 8)
                    }
                    .contentShape(Rectangle())
                }
            }

            Section {
            } header: {
                Text(state.t("Disclaimer", "Дисклеймер"))
            } footer: {
                Text(state.t(
                    "This is an independent research project and is not affiliated with, endorsed by, or sponsored by Apple Inc. The software is provided \"as is\", without warranty of any kind. You are solely responsible for how you use it and for any consequences that follow.",
                    "Это независимый исследовательский проект, не связанный с Apple Inc., не одобрен и не спонсируется ею. Программное обеспечение предоставляется «как есть», без каких-либо гарантий. Ответственность за использование и его последствия полностью лежит на вас."
                ))
                .font(.footnote)
                .foregroundColor(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(state.t("About", "О программе"))
        .navigationBarTitleDisplayMode(.inline)
        .tint(.blue)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            Group {
                if let icon = appIcon {
                    Image(uiImage: icon).resizable().aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        LinearGradient(
                            colors: [Color(red: 0.20, green: 0.52, blue: 1.0),
                                     Color(red: 0.30, green: 0.25, blue: 0.85)],
                            startPoint: .top, endPoint: .bottom
                        )
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(appName).font(.title3).fontWeight(.semibold)
                Text("\(state.t("Version", "Версия")) \(version) (\(build))")
                    .font(.subheadline).foregroundColor(.secondary)

                if let commit {
                    Text(commit)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }

                Divider().padding(.vertical, 4)

                Text(state.t("Research project for iOS.", "Исследовательский проект для iOS."))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func linkRow(_ title: String, url: URL) -> some View {
        Button {
            openURL(url)
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Text(title).foregroundStyle(.tint).font(.body).fontWeight(.medium)
                Spacer(minLength: 8)
                Image(systemName: "link")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tint)
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Acknowledgements

struct AcknowledgementsView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject var state: AppState

    private struct Entry {
        let name: String
        let license: String
        let url: URL
    }

    private let entries: [Entry] = [
        Entry(name: "XcodeGen", license: "MIT",
              url: URL(string: "https://github.com/yonaskolb/XcodeGen")!),
        Entry(name: "ldid", license: "GPL-3.0",
              url: URL(string: "https://github.com/ProcursusTeam/ldid")!),
        Entry(name: "libplist", license: "LGPL-2.1",
              url: URL(string: "https://github.com/libimobiledevice/libplist")!),
    ]

    var body: some View {
        List {
            Section {
                ForEach(entries, id: \.name) { entry in
                    Button {
                        openURL(entry.url)
                    } label: {
                        HStack(alignment: .top, spacing: 8) {
                            Text(entry.name).foregroundStyle(.tint).font(.body).fontWeight(.medium)
                            Spacer(minLength: 8)
                            Text(entry.license)
                                .font(.system(.footnote, design: .monospaced))
                                .foregroundColor(.secondary)
                            Image(systemName: "link")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.tint)
                        }
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text(state.t("Libraries", "Библиотеки"))
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(state.t("Acknowledgements", "Благодарности"))
        .navigationBarTitleDisplayMode(.inline)
        .tint(.blue)
    }
}