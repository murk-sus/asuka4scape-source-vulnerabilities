import SwiftUI

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
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
        .navigationTitle("Modify Offsets")
        .navigationBarTitleDisplayMode(.inline)
        .tint(.blue)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showExport = true
                    } label: {
                        Label("Export JSON", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) {
                        showResetAll = true
                    } label: {
                        Label("Reset All", systemImage: "arrow.uturn.backward")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .sheet(item: Binding(
            get: { editing.map { EditTarget(name: $0) } },
            set: { editing = $0?.name }
        )) { target in
            EditOffsetView(name: target.name)
                .environmentObject(store)
        }
        .sheet(isPresented: $showExport) {
            ExportOffsetsView()
                .environmentObject(store)
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

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(name)
                .foregroundStyle(.primary)
                .font(.system(size: 13, design: .monospaced))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(value == "0x0" ? .secondary : .green)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
