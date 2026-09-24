import SwiftUI
import UIKit

@main
struct natsuk1App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct LogLine: Identifiable {
    let id = UUID()
    let text: String
    let level: String
}

@MainActor
final class AppState: ObservableObject {
    @Published var logs: [LogLine] = []
    @Published var running = false
    @Published var slide: UInt64 = 0
    @Published var base: UInt64 = 0
    @Published var confidence: Int = 0
    @Published var hasKread = false
    @Published var hasKwrite = false
    @Published var hasRoot = false

    init() {
        nk_set_log(2)
    }

    func append(_ text: String, level: String = "INF") {
        logs.append(LogLine(text: text, level: level))
        if logs.count > 2000 {
            logs.removeFirst(logs.count - 2000)
        }
    }

    func run() {
        guard !running else { return }
        running = true
        logs.removeAll()

        Thread.detachNewThread { [weak self] in
            Thread.current.qualityOfService = .userInitiated

            _ = nk_full_exploit()

            let s  = nk_get_slide()
            let b  = nk_get_base()
            let c  = nk_get_confidence()
            let kr = nk_get_has_kread()
            let kw = nk_get_has_kwrite()
            let rt = nk_get_has_root()

            DispatchQueue.main.async {
                guard let self = self else { return }
                self.slide = s
                self.base = b
                self.confidence = c
                self.hasKread = kr != 0
                self.hasKwrite = kw != 0
                self.hasRoot = rt != 0
                self.append("slide = 0x\(String(s, radix: 16))")
                self.append("base  = 0x\(String(b, radix: 16))")
                self.append("confidence = \(c)")
                self.running = false
            }
        }
    }

    func detectOnly() {
        guard !running else { return }
        running = true
        logs.removeAll()

        Thread.detachNewThread { [weak self] in
            Thread.current.qualityOfService = .userInitiated

            _ = nk_detect_slide()

            let s = nk_get_slide()
            let b = nk_get_base()
            let c = nk_get_confidence()

            DispatchQueue.main.async {
                guard let self = self else { return }
                self.slide = s
                self.base = b
                self.confidence = c
                self.append("slide = 0x\(String(s, radix: 16))")
                self.append("base  = 0x\(String(b, radix: 16))")
                self.append("confidence = \(c)")
                self.running = false
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var state = AppState()

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                DeviceInfoView()

                HStack(spacing: 12) {
                    Button("Run") {
                        state.run()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(state.running)

                    Button("Detect KASLR") {
                        state.detectOnly()
                    }
                    .buttonStyle(.bordered)
                    .disabled(state.running)
                }
                .padding(.horizontal)

                SummaryView(state: state)

                LogView(lines: state.logs)
            }
            .navigationTitle("natsuk1")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink("About") {
                        AboutView()
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink("Acks") {
                        AcknowledgementsView()
                    }
                }
            }
        }
    }
}

struct SummaryView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("slide")
                Spacer()
                Text("0x\(String(state.slide, radix: 16))").monospaced()
            }
            HStack {
                Text("base")
                Spacer()
                Text("0x\(String(state.base, radix: 16))").monospaced()
            }
            HStack {
                Text("confidence")
                Spacer()
                Text("\(state.confidence)").monospaced()
            }
            HStack {
                Text("kread")
                Spacer()
                Text(state.hasKread ? "yes" : "no").monospaced()
            }
            HStack {
                Text("kwrite")
                Spacer()
                Text(state.hasKwrite ? "yes" : "no").monospaced()
            }
            HStack {
                Text("root")
                Spacer()
                Text(state.hasRoot ? "yes" : "no").monospaced()
            }
        }
        .font(.footnote)
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

struct LogView: View {
    let lines: [LogLine]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(lines) { line in
                        Text("[\(line.level)] \(line.text)")
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(line.id)
                    }
                }
                .padding(.horizontal)
            }
            .background(Color.black.opacity(0.05))
            .onChange(of: lines.count) { _, _ in
                if let last = lines.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("natsuk1").font(.title)
            Text("iOS 27.0 / arm64e research framework").font(.caption)
            Spacer()
        }
        .padding()
    }
}

struct AcknowledgementsView: View {
    var body: some View {
        List {
            Text("Apple")
            Text("XNU")
            Text("NECP")
        }
        .navigationTitle("Acknowledgements")
    }
}

struct DeviceInfoView: View {
    var body: some View {
        VStack(spacing: 2) {
            Text(DeviceName.current)
                .font(.headline)
            Text("iOS \(UIDevice.current.systemVersion)")
                .font(.caption)
        }
    }
}