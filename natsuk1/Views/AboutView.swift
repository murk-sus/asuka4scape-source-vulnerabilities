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

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(appName)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Version \(version) (\(build))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Research project iOS.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
                .padding(.vertical, 6)
            }

            Section {
                linkRow("Source Repository", url: repoURL)
                linkRow("MIT License", url: repoURL.appendingPathComponent("blob/main/LICENSE"))
            } header: {
                Text("Open Source")
            }

            Section {
                linkRow("Star on GitHub", url: repoURL.appendingPathComponent("stargazers"))
            } header: {
                Text("Community")
            }

            Section {
                linkRow("AirLift by 0xjohnnydev", url: URL(string: "https://github.com/0xjohnnydev/airlift")!)
                linkRow("AirCard-iOS by Mak5er", url: URL(string: "https://github.com/Mak5er/AirCard-iOS")!)
            } header: {
                Text("Credits")
            }

            Section {
            } header: {
                Text("Disclaimer")
            } footer: {
                Text("Independent research project. Not affiliated with Apple Inc. Provided as-is.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
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
