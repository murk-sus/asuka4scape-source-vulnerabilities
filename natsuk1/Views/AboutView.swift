import SwiftUI
import UIKit

struct AboutView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject var state: AppState

    private static let repoURL = URL(string: "https://github.com/murk-sus/asuka4scape-source-vulnerabilities")

    private var appName: String {
        Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
            ?? Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "natsuk1"
    }
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(appName).font(.title2).fontWeight(.semibold)
                    Text("Version \(version) (\(build))").font(.subheadline).foregroundStyle(.secondary)
                    Text("Research project iOS.").font(.footnote).foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
            Section {
                linkRow("Source Repository", url: Self.repoURL)
                linkRow("MIT License", url: Self.repoURL?.appendingPathComponent("blob/main/LICENSE"))
                linkRow("Star on GitHub", url: Self.repoURL?.appendingPathComponent("stargazers"))
            } header: { Text("Open Source") }
            Section { } header: { Text("Disclaimer") }
            footer: {
                Text("Independent research project. Not affiliated with Apple Inc.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func linkRow(_ title: String, url: URL?) -> some View {
        if let url = url {
            Button { openURL(url) } label: {
                HStack {
                    Text(title).foregroundStyle(.tint)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        }
    }
}
