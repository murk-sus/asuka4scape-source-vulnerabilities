import SwiftUI
import UIKit

struct AboutView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject var state: AppState

    private let repoURL = URL(string: "https://github.com/murk-sus/asuka4scape-source-vulnerabilities")!

    private let tgChannelUser = "jailbreak_IOS_and_tweaks"
    private let tgChatUser    = "IOS_pelmeshechnaia"
    private let tgOwnerUser   = "eurogoth"
    private let tgCoOwnerUser = "asuka4scape_developer"

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
                    title: state.t("Channel", "Канал"),
                    subtitle: state.t("Telegram channel", "Телеграм-канал"),
                    symbol: "paperplane.fill",
                    tint: Color(red: 0.15, green: 0.60, blue: 0.90)
                ) {
                    openTelegram(user: tgChannelUser)
                }

                actionRow(
                    title: state.t("Chat", "Чат"),
                    subtitle: state.t("Telegram chat", "Телеграм-чат"),
                    symbol: "bubble.left.and.bubble.right.fill",
                    tint: Color(red: 0.20, green: 0.72, blue: 0.52)
                ) {
                    openTelegram(user: tgChatUser)
                }
            } header: {
                Text(state.t("Community", "Сообщество"))
            }

            Section {
                actionRow(
                    title: state.t("Owner", "Владелец"),
                    subtitle: state.t("Maintainer", "Сопровождающий"),
                    symbol: "person.crop.circle.fill",
                    tint: Color(red: 0.60, green: 0.40, blue: 0.90)
                ) {
                    openTelegram(user: tgOwnerUser)
                }

                actionRow(
                    title: state.t("Co-Owner", "Со-владелец"),
                    subtitle: state.t("Contributor", "Контрибьютор"),
                    symbol: "person.2.fill",
                    tint: Color(red: 0.95, green: 0.55, blue: 0.20)
                ) {
                    openTelegram(user: tgCoOwnerUser)
                }
            } header: {
                Text(state.t("Thanks To", "Благодарности"))
            }

            Section {
                actionRow(
                    title: state.t("Source Repository", "Исходный код"),
                    subtitle: "github.com",
                    symbol: "chevron.left.forwardslash.chevron.right",
                    tint: Color(red: 0.20, green: 0.52, blue: 1.0)
                ) {
                    openURL(repoURL)
                }

                actionRow(
                    title: state.t("License · MIT", "Лицензия · MIT"),
                    subtitle: "MIT",
                    symbol: "doc.text.fill",
                    tint: .gray
                ) {
                    openURL(repoURL.appendingPathComponent("blob/main/LICENSE"))
                }
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

    private func openTelegram(user: String) {
        let appScheme = URL(string: "tg://resolve?domain=\(user)")!
        let webScheme = URL(string: "https://t.me/\(user)")!

        if UIApplication.shared.canOpenURL(appScheme) {
            UIApplication.shared.open(appScheme, options: [:]) { ok in
                if !ok {
                    UIApplication.shared.open(webScheme)
                }
            }
        } else {
            UIApplication.shared.open(webScheme)
        }
    }
}
