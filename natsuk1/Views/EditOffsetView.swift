import SwiftUI

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
                        .textSelection(.enabled)
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
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
            .alert("Invalid Value", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMsg)
            }
            .onAppear {
                text = store.value(for: name)
            }
        }
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            errorMsg = "Value cannot be empty."
            showError = true
            return
        }
        if trimmed.hasPrefix("0x") || trimmed.hasPrefix("0X") {
            let hexPart = String(trimmed.dropFirst(2))
            if UInt64(hexPart, radix: 16) == nil {
                errorMsg = "Invalid hex value."
                showError = true
                return
            }
        } else if UInt64(trimmed) == nil {
            errorMsg = "Invalid numeric value."
            showError = true
            return
        }
        store.update(name, value: trimmed)
        dismiss()
    }
}
