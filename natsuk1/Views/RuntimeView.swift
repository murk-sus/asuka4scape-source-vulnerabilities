import SwiftUI
import UIKit

struct RuntimeView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Section {
            row("Slide", state.slide, hot: state.slide != "—")
            row("Base",  state.base,  hot: state.base  != "—")
            HStack {
                Text("Status")
                Spacer()
                StatusDot(status: state.status)
            }
        } header: {
            Label("Runtime", systemImage: "waveform.path.ecg")
        }
    }

    private func row(_ k: String, _ v: String, hot: Bool) -> some View {
        HStack {
            Text(k)
            Spacer()
            Text(v)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(hot ? Color.green : Color.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
