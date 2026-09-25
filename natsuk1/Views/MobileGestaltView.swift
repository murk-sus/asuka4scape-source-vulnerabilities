import SwiftUI
import UIKit

struct MobileGestaltView: View {
    @State private var query: String = ""
    @State private var editing: MobileGestaltCatalog.Key? = nil
    @State private var showClear = false
    @State private var refreshTick = 0

    private var keys: [MobileGestaltCatalog.Key] {
        if query.isEmpty { return MobileGestaltCatalog.all }
        let q = query.lowercased()
        return MobileGestaltCatalog.all.filter { $0.name.lowercased().contains(q) }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Library")
                    Spacer()
                    badge(MobileGestalt.shared.loaded ? "loaded" : "missing",
                          color: MobileGestalt.shared.loaded ? .green : .red)
                }
                if let err = MobileGestalt.shared.loadError {
                    Text(err)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.red)
                }
                HStack {
                    Text("Overrides")
                    Spacer()
                    Text("\(MobileGestalt.shared.overrideCount)")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Button(role: .destructive) {
                    showClear = true
                } label: {
                    Label("Clear All Overrides", systemImage: "trash")
                }
                .disabled(MobileGestalt.shared.overrideCount == 0)
            } header: {
                Label("Status", systemImage: "checkmark.seal.fill")
            }

            Section {
                ForEach(keys) { key in
                    Button {
                        editing = key
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(key.name)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.primary)
                            HStack(spacing: 6) {
                                Text(MobileGestalt.shared.describe(key.name, kind: key.kind))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                Spacer(minLength: 4)
                                if MobileGestalt.shared.overrideValue(for: key.name) != nil {
                                    badge("override", color: .orange)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Label("Keys", systemImage: "key.fill")
            }
        }
        .id(refreshTick)
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(UIColor.systemGroupedBackground))
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
        .navigationTitle("MobileGestalt")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { key in
            EditMGOverrideView(key: key) {
                refreshTick &+= 1
            }
        }
        .alert("Clear all overrides?", isPresented: $showClear) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                MobileGestalt.shared.clearAllOverrides()
                refreshTick &+= 1
            }
        }
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, design: .monospaced))
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(color.opacity(0.18),
                        in: RoundedRectangle(cornerRadius: 3))
            .foregroundStyle(color)
    }
}

struct EditMGOverrideView: View {
    let key: MobileGestaltCatalog.Key
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @State private var showError = false
    @State private var errorMsg = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(key.name)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("Kind: \(key.kind.rawValue)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Key")
                }

                Section {
                    TextField("override value", text: $text)
                        .font(.system(size: 14, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Override")
                } footer: {
                    Text("Leave empty to remove the override. Applies only inside natsuk1.")
                }

                Section {
                    Button {
                        MobileGestalt.shared.setOverride(key.name, value: nil)
                        onDismiss()
                        dismiss()
                    } label: {
                        Label("Remove Override", systemImage: "arrow.uturn.backward")
                    }
                    .disabled(MobileGestalt.shared.overrideValue(for: key.name) == nil)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(UIColor.systemGroupedBackground))
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
            .onAppear {
                text = MobileGestalt.shared.overrideValue(for: key.name) ?? ""
            }
        }
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            MobileGestalt.shared.setOverride(key.name, value: nil)
            onDismiss()
            dismiss()
            return
        }
        switch key.kind {
        case .bool:
            let lower = trimmed.lowercased()
            if !(lower == "true" || lower == "false" || lower == "1" || lower == "0" ||
                 lower == "yes" || lower == "no") {
                errorMsg = "Bool accepts: true/false/1/0/yes/no"
                showError = true
                return
            }
        case .int:
            if Int64(trimmed) == nil && !(trimmed.hasPrefix("0x") && Int64(trimmed.dropFirst(2), radix: 16) != nil) {
                errorMsg = "Int accepts decimal or 0xHEX"
                showError = true
                return
            }
        case .float:
            if Float(trimmed) == nil {
                errorMsg = "Float accepts decimal"
                showError = true
                return
            }
        case .string:
            break
        }
        MobileGestalt.shared.setOverride(key.name, value: trimmed)
        onDismiss()
        dismiss()
    }
}
