import SwiftUI
import UIKit

struct RuntimeView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Section {
            HStack {
                Text("Slide")
                Spacer()
                Text(state.slide)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(state.slide != "—" ? .green : .secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            HStack {
                Text("Base")
                Spacer()
                Text(state.base)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(state.base != "—" ? .green : .secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            HStack {
                Text("Status")
                Spacer()
                StatusDot(status: state.status)
            }
        } header: {
            Text("Runtime")
        }
    }
}
