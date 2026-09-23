import SwiftUI
import UIKit

struct LogView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                Text(state.log.isEmpty ? "Awaiting execution." : state.log)
                    .font(.system(size: 10, design: .monospaced))
                    .multilineTextAlignment(.leading)
                    .foregroundColor(state.log.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)

                Spacer(minLength: 0)
                    .id(0)
            }
            .onChange(of: state.log) { _ in
                withAnimation(.linear(duration: 0.05)) {
                    proxy.scrollTo(0, anchor: .bottom)
                }
            }
            .contextMenu {
                Button {
                    UIPasteboard.general.string = state.log
                } label: {
                    Label("Copy Output", systemImage: "doc.on.doc")
                }

                Button {
                    state.clear()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
            }
        }
    }
}
