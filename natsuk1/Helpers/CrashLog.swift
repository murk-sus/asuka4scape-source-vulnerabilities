import Foundation
import UIKit

final class CrashLog: @unchecked Sendable {
    static let shared = CrashLog()

    private let queue = DispatchQueue(label: "natsuk1.crashlog")
    private var handle: FileHandle?
    private var currentSize: Int = 0
    private let maxBytes: Int = 1024 * 1024
    private var installed = false
    private let shutdownMarker = "[SHUTDOWN]"

    private var docsDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    private var liveURL: URL { docsDir.appendingPathComponent("natsuk1-live.log") }
    private var crashURL: URL { docsDir.appendingPathComponent("natsuk1-crash.log") }

    private init() {}

    func install() {
        queue.sync {
            guard !installed else { return }
            installed = true
            _detectPrevCrash()
            _open()
            _installHandlers()
        }
    }

    private func _detectPrevCrash() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: liveURL.path) else { return }
        let data = (try? Data(contentsOf: liveURL)) ?? Data()
        guard !data.isEmpty else { return }
        let s = String(data: data, encoding: .utf8) ?? ""
        let tail = s.split(separator: "\n").suffix(3).joined(separator: "\n")
        if !tail.contains(shutdownMarker) {
            try? fm.removeItem(at: crashURL)
            try? fm.copyItem(at: liveURL, to: crashURL)
        }
    }

    private func _open() {
        let fm = FileManager.default
        try? fm.removeItem(at: liveURL)
        fm.createFile(atPath: liveURL.path, contents: nil)
        handle = try? FileHandle(forWritingTo: liveURL)
        currentSize = 0
        let stamp = ISO8601DateFormatter().string(from: Date())
        _write("[BOOT] \(stamp)\n")
    }

    private func _installHandlers() {
        NSSetUncaughtExceptionHandler { ex in
            let head = "[FATAL] NSException \(ex.name.rawValue): \(ex.reason ?? "")\n"
            let stk = ex.callStackSymbols.joined(separator: "\n") + "\n"
            CrashLog.shared._write(head + stk)
            CrashLog.shared._flush()
        }
        for sig in [SIGSEGV, SIGABRT, SIGBUS, SIGILL, SIGTRAP, SIGFPE] {
            signal(sig, { s in
                CrashLog.shared._write("[FATAL] signal \(s)\n")
                CrashLog.shared._flush()
                signal(s, SIG_DFL)
                raise(s)
            })
        }
    }

    func writeLine(_ s: String) {
        queue.async { [weak self] in
            self?._write(s + "\n")
        }
    }

    func markCleanShutdown() {
        queue.async { [weak self] in
            guard let self else { return }
            if self.handle == nil { return }
            self._write(self.shutdownMarker + "\n")
            self._flush()
        }
    }

    private func _write(_ s: String) {
        NSLog("%@", s.trimmingCharacters(in: .newlines))
        guard let h = handle, let d = s.data(using: .utf8) else { return }
        _ = try? h.write(contentsOf: d)
        currentSize += d.count
        if currentSize > maxBytes { _rotate() }
    }

    private func _rotate() {
        _ = try? handle?.close()
        handle = nil
        let fm = FileManager.default
        try? fm.removeItem(at: liveURL)
        fm.createFile(atPath: liveURL.path, contents: nil)
        handle = try? FileHandle(forWritingTo: liveURL)
        currentSize = 0
        _write("[ROTATE]\n")
    }

    private func _flush() {
        try? handle?.synchronize()
    }

    func recoverPreviousSession() -> String? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: crashURL.path) else { return nil }
        guard let data = try? Data(contentsOf: crashURL) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func clearPreviousCrash() {
        try? FileManager.default.removeItem(at: crashURL)
    }
}
