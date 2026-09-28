import SwiftUI
import UIKit

struct CarrierLabView: View {
    @ObservedObject private var state = CarrierLabState.shared
    @EnvironmentObject private var appState: AppState

    @State private var slotText = ""
    @State private var copied = false

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Session")
                    Spacer()
                    Text(state.session?.status.rawValue ?? "clean").font(.system(.body, design: .monospaced))
                }
                if let error = state.session?.lastError {
                    Text(error).font(.footnote).foregroundStyle(.red)
                }
            } header: { Label("CarrierLab", systemImage: "shippingbox") }

            Section {
                TextField("Carrier1Bundle.bundle", text: $slotText)
                    .font(.system(.footnote, design: .monospaced))
                    .autocorrectionDisabled()
                Button("Apply Slots") { applySlots() }
                Button("Reset Slots To Default") {
                    slotText = CarrierLabBridge.defaultSlots.joined(separator: ", ")
                    applySlots()
                }
            } header: { Label("Targets", systemImage: "folder.badge.gearshape") }
            footer: { Text("Contents go into these existing bundles under \(CarrierLabBridge.carrierUserRoot).").font(.caption2) }

            Section {
                Button("Check") { run("check") { CarrierLabSlots.shared.status() } }
                Button("Pair Lockdown Record") { run("pair") { CarrierLabSlots.shared.ensureLockdownRecord() ?? "lockdown record stored" } }
                Button("Install") { run("install") { install() } }
                Button("Reload") { run("reload") { install() } }
                Button("Respring") { appState.respring() }
            } header: { Label("Actions", systemImage: "wrench") }

            if !state.logText.isEmpty {
                Section {
                    ScrollView {
                        Text(state.logText).font(.system(size: 10, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 120, maxHeight: 300)
                    Button(copied ? "Copied" : "Copy All") {
                        UIPasteboard.general.string = state.logText
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                    }
                    Button("Clear", role: .destructive) { state.clearLog() }
                } header: { Label("Log", systemImage: "terminal") }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("CarrierLab")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { slotText = state.slots.joined(separator: ", ") }
    }

    private func applySlots() {
        state.setSlots(slotText.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) })
        state.appendLog("[slots] \(state.slots.joined(separator: ","))")
    }

    private func install() -> String {
        let slots = CarrierLabState.shared.slots
        let outcome = CarrierLabSlots.shared.install(slots: slots)
        CarrierLabState.shared.save(CarrierLabState.Session(
            status: outcome.ok ? .placed : .failed,
            startedAt: Date(),
            carrierBundlePath: CarrierLabSlots.shared.sourcePath(),
            originalBackupPath: nil,
            ipccTriggerPath: nil,
            lastError: outcome.ok ? nil : outcome.message,
            aliases: nil,
            slots: outcome.slots))
        return outcome.ok ? outcome.message : "failed: \(outcome.message)"
    }

    private func run(_ name: String, _ work: @escaping () -> String) {
        if state.busy { return }
        state.setBusy(true)
        DispatchQueue.global(qos: .userInitiated).async {
            let text = work()
            CarrierLabState.shared.appendLog("[\(name)] \(text)")
            CarrierLabState.shared.setBusy(false)
        }
    }
}
