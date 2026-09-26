import SwiftUI
import UIKit
import Foundation

final class LockedBuffer: @unchecked Sendable {
    nonisolated(unsafe) static let shared = LockedBuffer()
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
    let _line = String(decoding: bytes, as: UTF8.self)
    LockedBuffer.shared.append(_line)
    CrashLog.shared.writeLine(_line)
    AppState.shared.parseLogLine(_line) /* natsuk1-crashlog-v1 */
}

private func osVersionString() -> String {
    let v = ProcessInfo.processInfo.operatingSystemVersion
    return "\(v.majorVersion).\(v.minorVersion)"
}
private func appVersionString() -> String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
}
private var isSupportedIOS: Bool {
    ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 27
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
            "auto_run": false, "keep_alive_audio": false,
            "keep_alive_location": false, "lang": "en"])
    }

    var body: some View {
        Group {
            if isSupportedIOS {
                ContentView()
                    .environmentObject(state)
                    .environmentObject(offsets)
                    .environmentObject(airlift)
                    .onAppear {
                        CrashLog.shared.install()
                        if let prev = CrashLog.shared.recoverPreviousSession(), !prev.isEmpty {
                            AppState.shared.previousCrash = prev
                        }
                        nk_set_log(cCallback)
                        if state.log.isEmpty {
                            state.append("[*] natsuk1 v\(appVersionString())")
                            state.append("[*] iOS \(osVersionString()) / arm64e")
                            state.append("")
                        }
                        if keep_alive_audio { KeepAlive.shared.startAudio() }
                        if keep_alive_location { KeepAlive.shared.startLocation() }
                        if auto_run {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { state.run() }
                        }
                    }
                    .onChange(of: keep_alive_audio) { _, v in
                        if v { KeepAlive.shared.startAudio() } else { KeepAlive.shared.stopAudio() }
                    }
                    .onChange(of: keep_alive_location) { _, v in
                        if v { KeepAlive.shared.startLocation() } else { KeepAlive.shared.stopLocation() }
                    }
                    .sheet(isPresented: $state.showCrashLog) {
                        CrashLogView().environmentObject(state)
                    }
                    .onChange(of: scenePhase) { _, phase in
                        if phase == .background {
                            CrashLog.shared.markCleanShutdown()
                        }
                    }
                    .overlay {
                        if state.show_respring {
                            RespringView().brightness(-1.0).ignoresSafeArea()
                        }
                    }
            } else {
                NotSupportedView(version: osVersionString())
            }
        }
    }
}

struct NotSupportedView: View {
    let version: String
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48)).foregroundStyle(.orange)
            Text("Not supported for iOS \(version)")
                .font(.title3).fontWeight(.semibold).multilineTextAlignment(.center)
            Text("natsuk1 runs on iOS 27 only.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
    }
}

final class AppState: ObservableObject, @unchecked Sendable {
    @Published var slide: String = "\u{2014}"
    @Published var base: String = "\u{2014}"
    @Published var previousCrash: String? = nil
    @Published var showCrashLog: Bool = false

    func parseLogLine(_ line: String) {
        if let v = Self.extractHex(line, keys: ["slide=0x", "SLIDE = 0x", "slide = 0x"]) {
            if self.slide != v {
                DispatchQueue.main.async { self.slide = v }
            }
        }
        if let v = Self.extractHex(line, keys: ["base=0x", "BASE = 0x", "base = 0x"]) {
            if self.base != v {
                DispatchQueue.main.async { self.base = v }
            }
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
    nonisolated(unsafe) static let shared = AppState()
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
    @Published var log: String = ""
    @Published var status: Status = .idle
    @Published var running: Bool = false
    @Published var show_respring: Bool = false
    @Published var lang: String { didSet { UserDefaults.standard.set(lang, forKey: "lang") } }

    private init() {
        self.lang = UserDefaults.standard.string(forKey: "lang") ?? "en"
        startFlusher()
    }
    func t(_ en: String, _ ru: String) -> String { lang == "ru" ? ru : en }

    private func startFlusher() {
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(300))
                guard let self else { return }
                let chunk = LockedBuffer.shared.drain()
                guard !chunk.isEmpty else { continue }
                var newLog = self.log
                newLog += chunk
                if newLog.count > 30000 { newLog = String(newLog.suffix(20000)) }
                self.log = newLog
            }
        }
    }
    func append(_ s: String) { LockedBuffer.shared.append(s) }
    func run() {
        if running { return }
        running = true; status = .running
        Task.detached {
            _ = nk_full_exploit()
            await MainActor.run {
                AppState.shared.running = false
                AppState.shared.status = .ok
            }
        }
    }
    func necp_run() {
        if running { return }
        running = true; status = .running
        Task.detached {
            let rc = nk_necp_run()
            await MainActor.run {
                AppState.shared.running = false
                AppState.shared.status = (rc == 0) ? .ok : .failed
            }
        }
    }
    func respring() { show_respring = true }
    func clear() { LockedBuffer.shared.clear(); log = "" }
}
