import SwiftUI
import UIKit

struct RuntimeView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Section {
            row(label: "Slide", value: state.slide)
            row(label: "Base", value: state.base)
            HStack {
                Text("Status")
                Spacer()
                StatusDot(status: state.status)
            }
        } header: {
            Label("Runtime", systemImage: "waveform.path.ecg")
        }
    }

    @ViewBuilder
    private func row(label: String, value: String) -> some View {
        let isSet = value != "-" && value != "—" && !value.isEmpty
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(isSet ? Color.green : Color.secondary)
                .shadow(color: isSet ? Color.green.opacity(0.65) : Color.clear, radius: 4)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
