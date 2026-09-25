import SwiftUI
import UIKit
import Foundation

private let cCallback: @convention(c) (UnsafePointer<CChar>?) -> Void = { line in
    guard let line = line else { return }
    var bytes: [UInt8] = []
    var p = line
    while p.pointee != 0 {
        bytes.append(UInt8(bitPattern: p.pointee))
        p = p.advanced(by: 1)
    }
    let s = String(decoding: bytes, as: UTF8.self)
    Task { @MainActor in
        AppState.shared.append(s)
    }
}

private func osVersionString() -> String {
    let v = ProcessInfo.processInfo.operatingSystemVersion
    return "\(v.majorVersion).\(v.minorVersion)"
}

private var isSupportedIOS: Bool {
    ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 27
}

@main
struct natsuk1App: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    @StateObject private var state = AppState.shared
    @StateObject private var offsets = OffsetsStore.shared
    @AppStorage("auto_run") private var auto_run = false
    @AppStorage("keep_alive_audio") private var keep_alive_audio = false
    @AppStorage("keep_alive_location") private var keep_alive_location = false

    init() {
        UserDefaults.standard.register(defaults: [
            "auto_run": false,
            "keep_alive_audio": false,
            "keep_alive_location": false,
            "lang": "en",
        ])
    }

    var body: some View {
        Group {
            if isSupportedIOS {
                ContentView()
                    .environmentObject(state)
                    .environmentObject(offsets)
                    .onAppear {
                        nk_set_log(cCallback)
                        if state.log.isEmpty {
                            state.append("[*] natsuk1 v6.0")
                            state.append("[*] iOS \(osVersionString()) / arm64e")
                            if let version = OffsetsStore.activeVersion {
                                state.append("[*] offsets: \(version.device) / iOS \(version.ios) (\(version.build))")
                            }
                            state.append("")
                        }
                        if keep_alive_audio { KeepAlive.shared.startAudio() }
                        if keep_alive_location { KeepAlive.shared.startLocation() }
                        if auto_run {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                state.run()
                            }
                        }
                    }
                    .onChange(of: keep_alive_audio) { _, value in
                        if value { KeepAlive.shared.startAudio() } else { KeepAlive.shared.stopAudio() }
                    }
                    .onChange(of: keep_alive_location) { _, value in
                        if value { KeepAlive.shared.startLocation() } else { KeepAlive.shared.stopLocation() }
                    }
                    .overlay {
                        if state.show_respring {
                            RespringView()
                                .brightness(-1.0)
                                .ignoresSafeArea()
                        }
                    }
            } else {
                NotSupportedView(version: osVersionString())
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct NotSupportedView: View {
    let version: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.orange)
            Text("Not supported for iOS \(version)")
                .font(.title3)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            Text("natsuk1 runs on iOS 27 only.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}

final class AppState: ObservableObject {
    nonisolated(unsafe) static let shared = AppState()

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
