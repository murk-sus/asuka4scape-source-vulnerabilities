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
                componentRow(
                    name: "XNU",
                    desc: state.t("Apple kernel target", "Целевое ядро Apple"),
                    version: "iOS 16+",
                    symbol: "cpu",
                    tint: .blue,
                    url: nil
                )
                componentRow(
                    name: "XcodeGen",
                    desc: state.t("Project generator", "Генератор проекта"),
                    version: "2.46+",
                    symbol: "hammer.fill",
                    tint: .orange,
                    url: URL(string: "https://github.com/yonaskolb/XcodeGen")
                )
                componentRow(
                    name: "ldid",
                    desc: state.t("Entitlements signer", "Подпись entitlements"),
                    version: "2.1.5+",
                    symbol: "signature",
                    tint: .purple,
                    url: URL(string: "https://github.com/ProcursusTeam/ldid")
                )
            } header: {
                Text(state.t("Components", "Компоненты"))
            }

            Section {
                creditRow("flong69zxc-max", url: URL(string: "https://github.com/flong69zxc-max"))
                creditRow("murk-sus",       url: URL(string: "https://github.com/murk-sus"))
                creditRow("eurogoth",       url: URL(string: "https://t.me/eurogoth"))
                creditRow("asuka4scape",    url: URL(string: "https://t.me/asuka4scape_developer"))
            } header: {
                Text(state.t("Thanks To", "Благодарности"))
            }

            Section {
                linkRow(
                    state.t("Source Repository", "Исходный код"),
                    symbol: "chevron.left.forwardslash.chevron.right",
                    tint: .blue,
                    url: repoURL
                )
                linkRow(
                    state.t("License · MIT", "Лицензия · MIT"),
                    symbol: "doc.text",
                    tint: .gray,
                    url: repoURL.appendingPathComponent("blob/main/LICENSE")
                )
            } header: {
                Text(state.t("Open Source", "Открытый код"))
            }

            Section {
            } footer: {
                Text(state.t(
                    "natsuk1 is a research scaffold. Not a jailbreak, not a tool for compromising devices you do not own.",
                    "natsuk1 — исследовательский каркас. Не джейлбрейк и не инструмент для взлома чужих устройств."
                ))
                .font(.footnote)
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
                    Image(uiImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
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
                Text(appName)
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("\(state.t("Version", "Версия")) \(version) (\(build))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if let commit {
                    Text(commit)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }

                Divider().padding(.vertical, 4)

                Text(state.t(
                    "Research scaffold for iOS. SwiftUI frontend, C backend, reproducible CI build.",
                    "Исследовательский каркас для iOS. SwiftUI-фронтенд, C-бэкенд, воспроизводимая сборка в CI."
                ))
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func componentRow(name: String, desc: String, version: String,
                              symbol: String, tint: Color, url: URL?) -> some View {
        Button {
            if let url { openURL(url) }
        } label: {
            HStack(spacing: 12) {
                symbolBox(symbol, tint: tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .foregroundColor(.primary)
                    Text(desc)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Text(version)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundColor(.secondary)

                if url != nil {
                    Image(systemName: "link")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(UIColor.tertiaryLabel))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(url == nil)
    }

    private func creditRow(_ name: String, url: URL?) -> some View {
        Button {
            if let url { openURL(url) }
        } label: {
            HStack {
                Text(name)
                    .foregroundColor(.primary)
                Spacer()
                if url != nil {
                    Image(systemName: "link")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(UIColor.tertiaryLabel))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func linkRow(_ title: String, symbol: String, tint: Color, url: URL?) -> some View {
        Button {
            if let url { openURL(url) }
        } label: {
            HStack(spacing: 12) {
                symbolBox(symbol, tint: tint)
                Text(title)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(UIColor.tertiaryLabel))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func symbolBox(_ name: String, tint: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.gradient)
            Image(systemName: name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 30, height: 30)
    }
}
