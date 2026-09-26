import SwiftUI
import UIKit

struct RuntimeView: View {
    @EnvironmentObject var state: AppState

    private var osShort: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion)"
    }
    private var deviceLine: String {
        "\(DeviceName.friendly()) · iOS \(osShort)"
    }

    var body: some View {
        Section {
            row("Slide", state.slide, hot: state.slide != "—")
            row("Base",  state.base,  hot: state.base  != "—")
            HStack {
                Text("Status")
                Spacer()
                StatusDot(status: state.status)
            }
            HStack {
                Text("Device")
                Spacer()
                Text(deviceLine)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        } header: {
            Label("Runtime", systemImage: "waveform.path.ecg")
        } footer: {
            if let crash = state.previousCrash, !crash.isEmpty {
                Button {
                    state.showCrashLog = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Previous session crashed — tap to view")
                            .font(.footnote)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
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
