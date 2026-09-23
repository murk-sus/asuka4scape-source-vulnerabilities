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
                actionRow(
                    title: state.t("Report an Issue", "Сообщить о проблеме"),
                    subtitle: "github.com",
                    symbol: "exclamationmark.bubble.fill",
                    tint: Color(red: 0.95, green: 0.45, blue: 0.35)
                ) {
                    openURL(repoURL.appendingPathComponent("issues/new"))
                }

                actionRow(
                    title: state.t("Releases", "Релизы"),
                    subtitle: state.t("Changelog & downloads", "История версий и загрузки"),
                    symbol: "tag.fill",
                    tint: Color(red: 0.20, green: 0.72, blue: 0.52)
                ) {
                    openURL(repoURL.appendingPathComponent("releases"))
                }
            } header: {
                Text(state.t("Support", "Поддержка"))
            }

            Section {
                gitHubRow(
                    title: state.t("Source Repository", "Исходный код"),
                    subtitle: "murk-sus/natsuk1",
                    url: repoURL
                )

                gitHubRow(
                    title: state.t("MIT License", "Лицензия MIT"),
                    subtitle: state.t("Open source license", "Лицензия открытого кода"),
                    url: repoURL.appendingPathComponent("blob/main/LICENSE")
                )
            } header: {
                Text(state.t("Open Source", "Открытый код"))
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
                    "Research project for iOS.",
                    "Исследовательский проект для iOS."
                ))
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func actionRow(title: String,
                           subtitle: String?,
                           symbol: String,
                           tint: Color,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                iconBox(symbol, tint: tint)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .foregroundColor(.primary)
                        .font(.body)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(UIColor.tertiaryLabel))
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func gitHubRow(title: String, subtitle: String, url: URL) -> some View {
        Button {
            openURL(url)
        } label: {
            HStack(spacing: 12) {
                githubIcon

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .foregroundStyle(.tint)
                        .font(.body)
                        .fontWeight(.medium)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.tint)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var githubIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(red: 0.11, green: 0.12, blue: 0.13))
            Image(systemName: "cat.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 30, height: 30)
    }

    private func iconBox(_ name: String, tint: Color) -> some View {
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
