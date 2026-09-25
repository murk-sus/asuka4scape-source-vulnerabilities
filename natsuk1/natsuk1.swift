import SwiftUI
import UIKit
import Foundation

private let cCallback: @convention(c) (UnsafePointer<CChar>?) -> Void = { line in
    guard let line = line else { return }
    AppState.shared.append(String(cString: line))
}

@main
struct natsuk1App: App {
    @StateObject private var state = AppState.shared
    @StateObject private var offsets = OffsetsStore.shared
    @AppStorage("auto_run") private var auto_run = false

    init() {
        UserDefaults.standard.register(defaults: [
            "auto_run": false,
            "lang": "en",
        ])
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
                .environmentObject(offsets)
                .preferredColorScheme(.dark)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    nk_set_log(cCallback)
                    if state.log.isEmpty {
                        let v = ProcessInfo.processInfo.operatingSystemVersion
                        state.append("[*] natsuk1 v5.0")
                        state.append("[*] iOS \(v.majorVersion).\(v.minorVersion) / arm64e")
                        if let version = OffsetsStore.activeVersion {
                            state.append("[*] offsets: \(version.device) / iOS \(version.ios) (\(version.build))")
                        }
                        state.append("")
                    }
                    if auto_run {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            state.run()
                        }
                    }
                }
                .overlay {
                    if state.show_respring {
                        RespringView()
                            .brightness(-1.0)
                            .ignoresSafeArea()
                    }
                }
        }
    }
}

final class AppState: ObservableObject {
    static let shared = AppState()

    enum Status {
        case idle, running, ok, failed
        var color: Color {
            switch self {
            case .idle:    return .secondary
            case .running: return .orange
            case .ok:      return .green
            case .failed:  return .red
            }
        }
    }

    @Published var log: String = ""
    @Published var status: Status = .idle
    @Published var running: Bool = false
    @Published var show_respring: Bool = false

    @Published var lang: String {
        didSet { UserDefaults.standard.set(lang, forKey: "lang") }
    }

    private var flusher: Timer?
    private var pending: String = ""
    private let lock = NSLock()

    private init() {
        self.lang = UserDefaults.standard.string(forKey: "lang") ?? "en"
        startFlusher()
    }

    func t(_ en: String, _ ru: String) -> String {
        lang == "ru" ? ru : en
    }

    private func startFlusher() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.flusher = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.lock.lock()
                let chunk = self.pending
                self.pending = ""
                self.lock.unlock()
                guard !chunk.isEmpty else { return }
                var newLog = self.log
                newLog += chunk
                if newLog.count > 30000 {
                    newLog = String(newLog.suffix(20000))
                }
                self.log = newLog
            }
        }
    }

    func append(_ s: String) {
        lock.lock()
        pending += s
        pending += "\n"
        if pending.count > 10000 {
            pending = String(pending.suffix(6000))
        }
        lock.unlock()
    }

    func run() {
        if running { return }
        running = true
        status = .running

        let t = Thread { [weak self] in
            _ = nk_full_exploit()
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.running = false
                self.status = .ok
            }
        }
        t.qualityOfService = .userInitiated
        t.stackSize = 16 * 1024 * 1024
        t.start()
    }

    func respring() {
        show_respring = true
    }

    func clear() {
        lock.lock()
        pending = ""
        lock.unlock()
        log = ""
    }
}
