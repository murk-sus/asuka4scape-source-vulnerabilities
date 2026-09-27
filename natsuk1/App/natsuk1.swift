import SwiftUI
import UIKit
import Foundation

final class LockedBuffer: @unchecked Sendable {
    static let shared = LockedBuffer()
    private let lock = NSLock()
    private var value: String = ""
    private init() {}

    func append(_ s: String) {
        lock.lock(); value += s + "\n"
        if value.count > 10000 { value = String(value.suffix(6000)) }
        lock.unlock()
    }

    func drain() -> String { lock.lock(); let v = value; value = ""; lock.unlock(); return v }

    func clear() { lock.lock(); value = ""; lock.unlock() }
}

private let cCallback: @convention(c) (UnsafePointer<CChar>?) -> Void = { line in
    guard let line = line else { return }
    var bytes: [UInt8] = []
    var p = line
    while p.pointee != 0 { bytes.append(UInt8(bitPattern: p.pointee)); p = p.advanced(by: 1) }
    let text = String(decoding: bytes, as: UTF8.self)
    LockedBuffer.shared.append(text)
    AppState.shared.parseLogLine(text)
}

private func osVersionString() -> String {
    let v = ProcessInfo.processInfo.operatingSystemVersion
    return "\(v.majorVersion).\(v.minorVersion)"
}

private func appVersionString() -> String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
}

final class RespringEscape: NSObject {
    static let shared = RespringEscape()
    weak var host: UIViewController?

    @objc func dismiss(_ gesture: UITapGestureRecognizer) {
        host?.dismiss(animated: false)
        host = nil
    }
}

@main
struct natsuk1App: App {
    var body: some Scene { WindowGroup { RootView() } }
}

struct RootView: View {
    @StateObject private var state = AppState.shared
    @StateObject private var offsets = OffsetsStore.shared
    @StateObject private var airlift = AirliftBridge.shared
    @AppStorage("auto_run") private var auto_run = false
    @AppStorage("keep_alive_audio") private var keep_alive_audio = false
    @AppStorage("keep_alive_location") private var keep_alive_location = false
    @Environment(\.scenePhase) private var scenePhase

    init() {
        UserDefaults.standard.register(defaults: [
            "auto_run": false,
            "keep_alive_audio": false,
            "keep_alive_location": false,
            "lang": "en",
        ])
    }

    var body: some View {
        ContentView()
            .environmentObject(state)
            .environmentObject(offsets)
            .environmentObject(airlift)
            .environmentObject(CarrierLabState.shared)
            .onAppear {
                nk_set_log(cCallback)
                if state.log.isEmpty {
                    state.append("[*] natsuk1 v\(appVersionString())")
                    state.append("[*] iOS \(osVersionString()) / arm64e")
                    state.append("")
                }
                if keep_alive_audio { KeepAlive.shared.startAudio() }
                if keep_alive_location { KeepAlive.shared.startLocation() }
                if auto_run { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { state.run() } }
            }
            .onChange(of: keep_alive_audio) { _, v in
                if v { KeepAlive.shared.startAudio() } else { KeepAlive.shared.stopAudio() }
            }
            .onChange(of: keep_alive_location) { _, v in
                if v { KeepAlive.shared.startLocation() } else { KeepAlive.shared.stopLocation() }
            }
    }
}

final class AppState: ObservableObject, @unchecked Sendable {
    static let shared = AppState()

    @Published var slide: String = "-"
    @Published var base: String = "-"
    @Published var log: String = ""
    @Published var status: Status = .idle
    @Published var running: Bool = false
    @Published var lang: String { didSet { UserDefaults.standard.set(lang, forKey: "lang") } }

    enum Status {
        case idle, running, ok, failed
        var color: Color {
            switch self {
            case .idle: return .secondary
            case .running: return .orange
            case .ok: return .green
            case .failed: return .red
            }
        }
    }

    private var flusher: Timer?

    private init() {
        self.lang = UserDefaults.standard.string(forKey: "lang") ?? "en"
        startFlusher()
    }

    func t(_ en: String, _ ru: String) -> String { lang == "ru" ? ru : en }

    func parseLogLine(_ line: String) {
        if let v = Self.extractHex(line, keys: ["slide=0x", "SLIDE = 0x", "slide = 0x"]) {
            DispatchQueue.main.async { if self.slide != v { self.slide = v } }
        }
        if let v = Self.extractHex(line, keys: ["base=0x", "BASE = 0x", "base = 0x"]) {
            DispatchQueue.main.async { if self.base != v { self.base = v } }
        }
    }

    private static func extractHex(_ s: String, keys: [String]) -> String? {
        for k in keys {
            if let r = s.range(of: k) {
                var hex = ""
                for c in s[r.upperBound...] {
                    if c.isHexDigit { hex.append(c) } else { break }
                }
                if !hex.isEmpty { return "0x" + hex }
            }
        }
        return nil
    }

    private func startFlusher() {
        flusher?.invalidate()
        flusher = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let chunk = LockedBuffer.shared.drain()
            if chunk.isEmpty { return }
            DispatchQueue.main.async {
                var newLog = self.log
                newLog += chunk
                if newLog.count > 30000 { newLog = String(newLog.suffix(20000)) }
                self.log = newLog
            }
        }
    }

    func append(_ s: String) { LockedBuffer.shared.append(s) }

    func run() {
        DispatchQueue.main.async {
            guard !self.running else { return }
            self.running = true
            self.status = .running
            let state = self
            DispatchQueue.global(qos: .userInitiated).async {
                let rc = nk_full_exploit()
                DispatchQueue.main.async {
                    state.running = false
                    state.status = (rc == 0) ? .ok : .failed
                }
            }
        }
    }

    func respring() {
        DispatchQueue.main.async {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first,
                  let root = window.rootViewController else { return }
            let host = UIHostingController(rootView: RespringView().ignoresSafeArea())
            host.modalPresentationStyle = .fullScreen
            host.view.backgroundColor = .black
            let escape = UITapGestureRecognizer(target: RespringEscape.shared,
                                                action: #selector(RespringEscape.dismiss(_:)))
            escape.numberOfTapsRequired = 2
            escape.cancelsTouchesInView = false
            host.view.addGestureRecognizer(escape)
            RespringEscape.shared.host = host
            root.present(host, animated: false)
        }
    }

    func clear() {
        LockedBuffer.shared.clear()
        DispatchQueue.main.async { self.log = "" }
    }

    func cancel() {
        append("[*] cancel requested")
    }
}
