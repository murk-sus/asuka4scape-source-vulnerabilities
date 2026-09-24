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

@main
struct natsuk1App: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var log: String = ""
    @Published var running: Bool = false
    @Published var lang: Lang = .en

    @Published var slide: UInt64 = 0
    @Published var base: UInt64 = 0
    @Published var confidence: Int = 0
    @Published var hasKread: Bool = false
    @Published var hasKwrite: Bool = false
    @Published var hasRoot: Bool = false

    init() {
        nk_set_log(2)
    }

    func t(_ en: String, _ ru: String) -> String {
        lang == .ru ? ru : en
    }

    func append(_ s: String) {
        if log.isEmpty {
            log = s
        } else {
            log += "\n" + s
        }
    }

    func clearLog() {
        log = ""
    }

    func clear() {
        clearLog()
    }

    func run() {
        guard !running else { return }
        running = true
        clearLog()
        append("[+] natsuk1 v3.1")
        append("[+] target iOS 27.0 / arm64e")

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
                self.append("[+] slide = 0x\(String(s, radix: 16))")
                self.append("[+] base  = 0x\(String(b, radix: 16))")
                self.append("[+] conf = \(c)")
                self.running = false
            }
        }
    }

    func detectOnly() {
        guard !running else { return }
        running = true
        clearLog()
        append("[+] natsuk1 KASLR detect")

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
                self.append("[+] slide = 0x\(String(s, radix: 16))")
                self.append("[+] base  = 0x\(String(b, radix: 16))")
                self.append("[+] conf = \(c)")
                self.running = false
            }
        }
    }

    func slideOnly() {
        detectOnly()
    }

    func respring() {
        append("[+] respring requested")
        Respring.run()
    }
}