import SwiftUI
import UIKit
import Foundation

private let cCallback: @convention(c) (UnsafePointer<CChar>?) -> Void = { line in
    guard let line = line else { return }
    let s = String(cString: line)
    DispatchQueue.main.async {
        AppState.shared.append(s)
    }
}

@main
struct natsuk1App: App {
    @StateObject private var state = AppState.shared
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
                .preferredColorScheme(.dark)
                .onAppear {
                    nk_set_log(cCallback)
                    if state.log.isEmpty {
                        let v = ProcessInfo.processInfo.operatingSystemVersion
                        state.append("[*] natsuk1 v3.1")
                        state.append("[*] iOS \(v.majorVersion).\(v.minorVersion) / arm64e")
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
                            .ignoresSafeArea()
                    }
                }
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    enum Status {
        case idle, running, ok, failed
        var label: String {
            switch self {
            case .idle:    return "idle"
            case .running: return "running"
            case .ok:      return "ok"
            case .failed:  return "failed"
            }
        }
        var color: Color {
            switch self {
            case .idle:    return .secondary
            case .running: return .yellow
            case .ok:      return .green
            case .failed:  return .red
            }
        }
    }

    @Published var log: String = ""
    @Published var slide: UInt64 = 0
    @Published var base: UInt64 = 0
    @Published var status: Status = .idle
    @Published var running: Bool = false
    @Published var show_respring: Bool = false
    @Published var lang: String = "en" {
        didSet { UserDefaults.standard.set(lang, forKey: "lang") }
    }

    private var poller: Timer?

    private init() {
        self.lang = UserDefaults.standard.string(forKey: "lang") ?? "en"
    }

    func t(_ en: String, _ ru: String) -> String {
        lang == "ru" ? ru : en
    }

    func append(_ s: String) {
        log += s + "\n"
        if log.count > 50000 {
            log = String(log.suffix(40000))
        }
    }

    private func startPoller() {
        poller?.invalidate()
        poller = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                let s = nk_get_slide()
                let b = nk_get_base()
                if s != 0 && self.slide != s { self.slide = s }
                if b != 0 && self.base != b { self.base = b }
            }
        }
    }

    private func stopPoller() {
        poller?.invalidate()
        poller = nil
    }

    func run() {
        guard !running else { return }
        running = true
        status = .running
        startPoller()

        let thread = Thread { [weak self] in
            let r = nk_full_exploit()
            let sl = nk_get_slide()
            let bs = nk_get_base()
            let cf = Int(nk_get_confidence())
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.stopPoller()
                self.running = false
                self.slide = sl
                self.base = bs
                if r == 0 && sl != 0 {
                    self.status = .ok
                    self.append(String(format: "[+] SLIDE = 0x%llx", sl))
                    self.append(String(format: "[+] BASE  = 0x%llx", bs))
                    self.append("[+] conf = \(cf)")
                } else {
                    self.status = .failed
                    self.append("[-] exploit failed (ret=\(r))")
                }
            }
        }
        thread.qualityOfService = QualityOfService.userInitiated
        thread.stackSize = 4 * 1024 * 1024
        thread.start()
    }

    func slideOnly() {
        guard !running else { return }
        running = true
        status = .running
        startPoller()

        let thread = Thread { [weak self] in
            let r = nk_detect_slide()
            let sl = nk_get_slide()
            let bs = nk_get_base()
            let cf = Int(nk_get_confidence())
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.stopPoller()
                self.running = false
                self.slide = sl
                self.base = bs
                if r == 0 && sl != 0 {
                    self.status = .ok
                    self.append(String(format: "[+] SLIDE = 0x%llx", sl))
                    self.append(String(format: "[+] BASE  = 0x%llx", bs))
                    self.append("[+] conf = \(cf)")
                } else {
                    self.status = .failed
                    self.append("[-] slide not resolved")
                }
            }
        }
        thread.qualityOfService = QualityOfService.userInitiated
        thread.stackSize = 4 * 1024 * 1024
        thread.start()
    }

    func respring() {
        show_respring = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            RespringView.attemptSystemRespring()
        }
    }

    func clear() { log = "" }
}