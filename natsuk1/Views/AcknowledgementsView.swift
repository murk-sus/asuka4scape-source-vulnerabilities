import SwiftUI

struct AcknowledgementsView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject var state: AppState

    private struct Entry {
        let name: String
        let license: String
        let url: URL
    }

    private let entries: [Entry] = [
        Entry(
            name: "XcodeGen",
            license: "MIT",
            url: URL(string: "https://github.com/yonaskolb/XcodeGen")!
        ),
        Entry(
            name: "ldid",
            license: "GPL-3.0",
            url: URL(string: "https://github.com/ProcursusTeam/ldid")!
        ),
        Entry(
            name: "libplist",
            license: "LGPL-2.1",
            url: URL(string: "https://github.com/libimobiledevice/libplist")!
        ),
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
                Text(state.t("Libraries", "Библиотеки"))
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(state.t("Acknowledgements", "Благодарности"))
        .navigationBarTitleDisplayMode(.inline)
        .tint(.blue)
    }
}
