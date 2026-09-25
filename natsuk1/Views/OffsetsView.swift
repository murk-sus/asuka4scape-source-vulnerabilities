import SwiftUI
import UIKit

struct OffsetsView: View {
    @EnvironmentObject var store: OffsetsStore
    @State private var query = ""
    @State private var editing: String? = nil
    @State private var showResetAll = false
    @State private var showExport = false

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Filled")
                    Spacer()
                    Text("\(store.filledCount()) / \(store.totalCount())")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }

            ForEach(filteredGroups, id: \.title) { group in
                Section {
                    ForEach(group.items, id: \.self) { name in
                        Button {
                            editing = name
                        } label: {
                            OffsetRow(name: name, value: store.value(for: name))
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(group.title)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(UIColor.systemGroupedBackground))
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
        .navigationTitle("Modify Offsets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button { showExport = true } label: {
                        Label("Export JSON", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) { showResetAll = true } label: {
                        Label("Reset All", systemImage: "arrow.uturn.backward")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Color(UIColor.tertiaryLabel))
                }
            }
        }
        .sheet(item: Binding(
            get: { editing.map { EditTarget(name: $0) } },
            set: { editing = $0?.name }
        )) { target in
            EditOffsetView(name: target.name)
                .environmentObject(store)
                .presentationBackground(Color(UIColor.systemGroupedBackground))
        }
        .sheet(isPresented: $showExport) {
            ExportOffsetsView()
                .environmentObject(store)
                .presentationBackground(Color(UIColor.systemGroupedBackground))
        }
        .alert("Reset All Offsets?", isPresented: $showResetAll) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { store.reset() }
        } message: {
            Text("All offsets will be set to built-in defaults.")
        }
    }

    private var filteredGroups: [OffsetsStore.Group] {
        if query.isEmpty { return OffsetsStore.groups }
        let q = query.lowercased()
        return OffsetsStore.groups.compactMap { g in
            let items = g.items.filter { $0.lowercased().contains(q) }
            if items.isEmpty { return nil }
            return OffsetsStore.Group(title: g.title, items: items)
        }
    }
}

struct EditTarget: Identifiable {
    let name: String
    var id: String { name }
}

struct OffsetRow: View {
    let name: String
    let value: String

    private var valueColor: Color {
        value == "0x0" ? Color.secondary : Color.green
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(name)
                .foregroundStyle(Color.primary)
                .font(.system(size: 13, design: .monospaced))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(valueColor)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

struct EditOffsetView: View {
    @EnvironmentObject var store: OffsetsStore
    @Environment(\.dismiss) private var dismiss
    let name: String

    @State private var text: String = ""
    @State private var showError = false
    @State private var errorMsg = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(name)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Offset")
                }

                Section {
                    TextField("Value", text: $text)
                        .font(.system(size: 14, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.asciiCapable)
                } header: {
                    Text("Value")
                } footer: {
                    Text("Hex (0x...) or decimal. Default: \(OffsetsStore.defaults[name] ?? "0x0")")
                }

                Section {
                    Button {
                        store.resetOne(name)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.uturn.backward")
                            Text("Restore Default")
                        }
                    }
                }
            }
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }.fontWeight(.semibold)
                }
            }
            .alert("Invalid Value", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMsg)
            }
            .onAppear { text = store.value(for: name) }
        }
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            errorMsg = "Value cannot be empty."; showError = true; return
        }
        if trimmed.hasPrefix("0x") || trimmed.hasPrefix("0X") {
            let hexPart = String(trimmed.dropFirst(2))
            if UInt64(hexPart, radix: 16) == nil {
                errorMsg = "Invalid hex value."; showError = true; return
            }
        } else if UInt64(trimmed) == nil {
            errorMsg = "Invalid numeric value."; showError = true; return
        }
        store.update(name, value: trimmed)
        dismiss()
    }
}

struct ExportOffsetsView: View {
    @EnvironmentObject var store: OffsetsStore
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    private var json: String {
        let sorted = store.values.sorted { $0.key < $1.key }
        let dict = Dictionary(uniqueKeysWithValues: sorted)
        if let data = try? JSONSerialization.data(
            withJSONObject: dict,
            options: [.prettyPrinted, .sortedKeys]
        ), let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(json)
                    .font(.system(size: 11, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        UIPasteboard.general.string = json
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            copied = false
                        }
                    } label: {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    }
                }
            }
        }
    }
}
