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
                linkRow(
                    state.t("Source Repository", "Исходный код"),
                    url: repoURL
                )

                linkRow(
                    state.t("MIT License", "Лицензия MIT"),
                    url: repoURL.appendingPathComponent("blob/main/LICENSE")
                )
            } header: {
                Text(state.t("Open Source", "Открытый код"))
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
            } footer: {
                Text(state.t(
                    "Not affiliated with Apple. Use at your own risk.",
                    "Не связано с Apple. Используйте на свой риск."
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
                    "Research project for iOS. SwiftUI frontend, C backend, reproducible build pipeline.",
                    "Исследовательский проект для iOS. SwiftUI-фронтенд, C-бэкенд, воспроизводимая сборка."
                ))
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
                Text(title)
                    .foregroundStyle(.tint)
                    .font(.body)
                    .fontWeight(.medium)

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
