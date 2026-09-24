import SwiftUI
import UIKit

enum Lang: String, CaseIterable, Hashable, Identifiable {
    case en
    case ru
    var id: String { rawValue }
    var label: String {
        switch self {
        case .en: return "English"
        case .ru: return "Русский"
        }
    }
}

enum RunStatus {
    case idle, running, done, failed
    var color: Color {
        switch self {
        case .idle:    return .gray
        case .running: return .yellow
        case .done:    return .green
        case .failed:  return .red
        }
    }
}

@main
struct natsuk1App: App {
    @StateObject private var state = AppState()
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(state)
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var log: String = ""
    @Published var running: Bool = false
    @Published var lang: Lang = .en
    @Published var status: RunStatus = .idle

    @Published var slide: UInt64 = 0
    @Published var base: UInt64 = 0
    @Published var confidence: Int = 0
    @Published var hasKread: Bool = false
    @Published var hasKwrite: Bool = false
    @Published var hasRoot: Bool = false

    private var timer: Timer?

    init() {
        nk_set_log(2)
        nk_log_capture_begin()
        startPolling()
    }

    deinit {
        timer?.invalidate()
    }

    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let c = nk_log_poll()
            let s = String(cString: c)
            if !s.isEmpty && s != self.log {
                self.log = s
            }
        }
    }

    func t(_ en: String, _ ru: String) -> String {
        lang == .ru ? ru : en
    }

    func append(_ s: String) {
        if log.isEmpty { log = s } else { log += "\n" + s }
    }

    func clearLog() {
        nk_log_capture_begin()
        log = ""
    }

    func clear() {
        clearLog()
        status = .idle
    }

    func respring() {
        append("[+] respring requested")
    }

    func run() {
        guard !running else { return }
        running = true
        status = .running
        clearLog()

        Thread.detachNewThread { [weak self] in
            Thread.current.qualityOfService = .userInitiated
            _ = nk_full_exploit()
            let s  = nk_get_slide()
            let b  = nk_get_base()
            let c  = Int(nk_get_confidence())
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
                self.status = (s != 0) ? .done : .failed
                self.running = false
            }
        }
    }

    func detectOnly() {
        guard !running else { return }
        running = true
        status = .running
        clearLog()

        Thread.detachNewThread { [weak self] in
            Thread.current.qualityOfService = .userInitiated
            _ = nk_detect_slide()
            let s = nk_get_slide()
            let b = nk_get_base()
            let c = Int(nk_get_confidence())
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.slide = s
                self.base = b
                self.confidence = c
                self.status = (s != 0) ? .done : .failed
                self.running = false
            }
        }
    }

    func slideOnly() {
        detectOnly()
    }
}