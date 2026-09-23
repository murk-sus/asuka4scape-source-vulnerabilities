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
                telegramRow(state.t("Channel", "Канал"), user: tgChannelUser)
                telegramRow(state.t("Chat", "Чат"),       user: tgChatUser)
            } header: {
                Text(state.t("Community", "Сообщество"))
            }

            Section {
                telegramRow(state.t("Owner", "Владелец"),        user: tgOwnerUser)
                telegramRow(state.t("Co-Owner", "Со-владелец"), user: tgCoOwnerUser)
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

    private func telegramRow(_ title: String, user: String) -> some View {
        Button {
            openTelegram(user: user)
        } label: {
            HStack(spacing: 10) {
                Text(title)
                    .foregroundColor(.primary)

                Spacer(minLength: 8)

                Image(systemName: "paperplane.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(red: 0.15, green: 0.60, blue: 0.90))
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
