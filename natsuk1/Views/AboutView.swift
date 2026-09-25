
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
                NavigationLink {
                    AcknowledgementsView().environmentObject(state)
                } label: {
                    HStack {
                        Text("Acknowledgements")
                            .foregroundColor(.primary)
                        Spacer(minLength: 8)
                    }
                    .contentShape(Rectangle())
                }
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
        .background(Color.black)
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
                            Text(entry.name)
                                .foregroundStyle(.tint)
                                .font(.body)
                                .fontWeight(.medium)
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
                Text("Libraries")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .navigationTitle("Acknowledgements")
        .navigationBarTitleDisplayMode(.inline)
    }
}
