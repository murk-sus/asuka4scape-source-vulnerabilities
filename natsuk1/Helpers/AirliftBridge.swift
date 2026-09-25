import Foundation
import Combine

final class AirliftBridge: ObservableObject, @unchecked Sendable {
    nonisolated(unsafe) static let shared = AirliftBridge()

    enum State: Equatable {
        case idle
        case pairing
        case ready(pairingPath: String)
        case running
        case done(ok: Bool, message: String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var pairPIN: String? = nil
    @Published private(set) var pairingStatus: String = ""
    @Published private(set) var exploitLog: [String] = []
    @Published var target: String = "/var/mobile/Library/SpringBoard"

    private var loggedLines: [String] = []

    private init() {
        al_log_init({ _, msg in
            guard let msg = msg else { return }
            let line = String(cString: msg)
            DispatchQueue.main.async {
                AirliftBridge.shared.appendLog(line)
            }
        }, nil)
    }

    nonisolated private func appendLog(_ s: String) {
        DispatchQueue.main.async {
            self.loggedLines.append(s)
            if self.loggedLines.count > 800 {
                self.loggedLines.removeFirst(self.loggedLines.count - 600)
            }
            self.exploitLog = self.loggedLines
        }
    }

    func logAccessibleFolders() {
        let fm = FileManager.default
        var lines: [String] = []
        lines.append("[paths] home: \(NSHomeDirectory())")
        lines.append("[paths] bundle: \(Bundle.main.bundlePath)")
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0].path
        lines.append("[paths] documents: \(docs)")
        if let lib = fm.urls(for: .libraryDirectory, in: .userDomainMask).first?.path {
            lines.append("[paths] library: \(lib)")
        }
        lines.append("[paths] tmp: \(NSTemporaryDirectory())")
        if let items = try? fm.contentsOfDirectory(atPath: docs) {
            lines.append("[docs] \(items.count) entries:")
            for f in items.prefix(80) { lines.append("[docs]   \(f)") }
        }
        let probes = [
            "/var/mobile", "/var/mobile/Library",
            "/private/var/mobile", "/private/var/mobile/Library",
            "/var/containers/Bundle/Application",
            "/private/var/containers/Bundle/Application",
            "/var/mobile/Containers/Data/Application",
            "/private/var/mobile/Containers/Data/Application",
            "/System/Library/PrivateFrameworks", "/var/jb",
        ]
        for p in probes {
            var isDir: ObjCBool = false
            let ok = fm.fileExists(atPath: p, isDirectory: &isDir)
            lines.append("[probe] \(p) exists=\(ok) dir=\(isDir.boolValue)")
        }
        for l in lines { appendLog(l) }
    }

    func clearLog() {
        loggedLines.removeAll()
        exploitLog = []
    }

    func pairingFilePath() -> String {
        return PairingController.pairingFilePath()
    }

    func hasPairing() -> Bool {
        let p = pairingFilePath()
        guard FileManager.default.fileExists(atPath: p) else { return false }
        let size = (try? FileManager.default.attributesOfItem(atPath: p)[.size] as? Int) ?? 0
        return size > 0
    }

    func runPairing() {
        guard !hasPairing() else {
            state = .ready(pairingPath: pairingFilePath())
            return
        }
        state = .pairing
        pairingStatus = "Starting host..."
        pairPIN = nil
        let ctrl = PairingController.shared
        Task {
            do {
                let path = try await ctrl.startAndWait()
                self.state = .ready(pairingPath: path)
                self.pairingStatus = "Paired"
                self.pairPIN = nil
            } catch is CancellationError {
                self.state = .idle
                self.pairingStatus = "Cancelled"
            } catch {
                self.state = .idle
                self.pairingStatus = "Failed: \(error.localizedDescription)"
            }
        }
        Task {
            while case .pairing = self.state {
                try? await Task.sleep(nanoseconds: 200_000_000)
                self.pairingStatus = ctrl.pairingStatus
                self.pairPIN = ctrl.pairingPIN
            }
        }
    }

    func cancelPairing() {
        PairingController.shared.softCancel()
        state = .idle
        pairingStatus = ""
        pairPIN = nil
    }

    func deletePairing() {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        var removed: [String] = []
        let canonicalURL = docs.appendingPathComponent("natsuk1_pairing.plist")
        if fm.fileExists(atPath: canonicalURL.path) {
            try? fm.removeItem(at: canonicalURL)
            removed.append("natsuk1_pairing.plist")
        }
        if let custom = PairingController.customPairingFilePath {
            if fm.fileExists(atPath: custom) {
                try? fm.removeItem(atPath: custom)
                removed.append((custom as NSString).lastPathComponent)
            }
        }
        PairingController.customPairingFilePath = nil
        if let files = try? fm.contentsOfDirectory(atPath: docs.path) {
            for f in files {
                guard f.hasSuffix(".plist")
                   || f.hasSuffix(".mobilepairing")
                   || f.hasSuffix(".mobilepair") else { continue }
                try? fm.removeItem(at: docs.appendingPathComponent(f))
                removed.append(f)
            }
        }
        UserDefaults.standard.removeObject(forKey: "natsuk1PairingHostAltIRK")
        state = .idle
        pairingStatus = ""
        pairPIN = nil
        appendLog("[delete] removed: \(removed.isEmpty ? "none" : removed.joined(separator: ", "))")
        appendLog("[delete] hasPairing now: \(hasPairing())")
    }

    func runExploit() {
        let pairingPath = pairingFilePath()
        guard FileManager.default.fileExists(atPath: pairingPath) else {
            state = .done(ok: false, message: "No pairing file")
            return
        }
        state = .running
        loggedLines.removeAll()
        exploitLog = []
        appendLog("[exploit] start path=\(pairingPath) target=\(target)")
        let targetDir = target
        Task.detached {
            var outJson: UnsafeMutablePointer<CChar>? = nil
            var outError: UnsafeMutablePointer<CChar>? = nil
            let rc: Int32 = pairingPath.withCString { pc in
                targetDir.withCString { tc in
                    al_exploit_run(pc, tc, nil, nil, &outJson, &outError)
                }
            }
            let jsonStr = outJson.flatMap { p -> String? in
                let s = String(cString: p); al_string_free(p); return s
            }
            let errStr = outError.flatMap { p -> String? in
                let s = String(cString: p); al_string_free(p); return s
            }
            await MainActor.run {
                if rc == 0 {
                    let msg = jsonStr ?? "Canary write confirmed"
                    self.appendLog("[exploit] ok: \(msg)")
                    self.state = .done(ok: true, message: msg)
                } else {
                    let msg = errStr ?? "rc=\(rc)"
                    self.appendLog("[exploit] fail rc=\(rc): \(msg)")
                    self.state = .done(ok: false, message: msg)
                }
            }
        }
    }

    func respring() {
        let pairingPath = pairingFilePath()
        guard FileManager.default.fileExists(atPath: pairingPath) else {
            appendLog("[respring] no pairing file at \(pairingPath)")
            return
        }
        appendLog("[respring] invoking with \(pairingPath)")
        Task.detached { [weak self] in
            var outError: UnsafeMutablePointer<CChar>? = nil
            let rc: Int32 = pairingPath.withCString { pc in
                al_device_respring(pc, nil, nil, &outError)
            }
            let errStr = outError.flatMap { p -> String? in
                let s = String(cString: p); al_string_free(p); return s
            }
            await MainActor.run {
                if rc == 0 {
                    self?.appendLog("[respring] ok")
                } else {
                    self?.appendLog("[respring] rc=\(rc) \(errStr ?? "")")
                }
            }
        }
    }

    func findContainer(bundleID: String) async -> String? {
        let pairingPath = pairingFilePath()
        guard FileManager.default.fileExists(atPath: pairingPath) else { return nil }
        return await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                var outContainer: UnsafeMutablePointer<CChar>? = nil
                var outError: UnsafeMutablePointer<CChar>? = nil
                let rc: Int32 = pairingPath.withCString { pc in
                    bundleID.withCString { bc in
                        al_find_app_container(pc, bc, nil, nil, &outContainer, &outError)
                    }
                }
                let containerStr = outContainer.flatMap { p -> String? in
                    let s = String(cString: p); al_string_free(p); return s
                }
                if let p = outError { al_string_free(p) }
                if rc == 0, let c = containerStr {
                    cont.resume(returning: c)
                } else {
                    cont.resume(returning: nil)
                }
            }
        }
    }
}
