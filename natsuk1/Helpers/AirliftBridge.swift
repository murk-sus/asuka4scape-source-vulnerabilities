import Foundation
import Combine

final class AirliftBridge: ObservableObject, @unchecked Sendable {
    static let shared = AirliftBridge()

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
    private var pairingBusy = false
    private var statusTimer: Timer?

    private init() {
        al_log_init({ _, msg in
            guard let msg = msg else { return }
            let line = String(cString: msg)
            DispatchQueue.main.async { AirliftBridge.shared.appendLog(line) }
        }, nil)
    }

    private func appendLog(_ s: String) {
        DispatchQueue.main.async {
            self.loggedLines.append(s)
            if self.loggedLines.count > 800 {
                self.loggedLines.removeFirst(self.loggedLines.count - 600)
            }
            self.exploitLog = self.loggedLines
        }
    }

    func clearLog() {
        DispatchQueue.main.async {
            self.loggedLines.removeAll()
            self.exploitLog = []
        }
    }

    private static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
    }

    func pairingFilePath() -> String { PairingController.pairingFilePath() }

    func hasPairing() -> Bool {
        PairingFileKind.of(path: pairingFilePath()).hasLockdown
    }

    var pairingKind: PairingFileKind {
        PairingFileKind.of(path: pairingFilePath())
    }

    func pairingFileExists() -> Bool {
        let p = pairingFilePath()
        guard FileManager.default.fileExists(atPath: p) else { return false }
        let size = (try? FileManager.default.attributesOfItem(atPath: p)[.size] as? Int) ?? 0
        return size > 0
    }

    private func setState(_ s: State) { DispatchQueue.main.async { self.state = s } }
    private func setStatus(_ s: String) { DispatchQueue.main.async { self.pairingStatus = s } }
    private func setPIN(_ p: String?) { DispatchQueue.main.async { self.pairPIN = p } }

    private static func fileMTime(_ path: String) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate]) as? Date
    }

    func runPairing() {
        guard !hasPairing() else {
            setState(.ready(pairingPath: pairingFilePath()))
            return
        }
        setState(.pairing)
        setStatus("Starting host...")
        setPIN(nil)
        pairingBusy = true

        let ctrl = PairingController.shared
        let path = pairingFilePath()
        let mtimeBefore = Self.fileMTime(path)

        DispatchQueue.main.async {
            if ctrl.running { ctrl.softCancel() }
            self.statusTimer?.invalidate()
            var sawRunning = false
            var idleTicks = 0
            var ticks = 0

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { ctrl.start() }

                    var finishing = false
                    self.statusTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] t in
                        guard let self = self else { t.invalidate(); return }
                        ticks += 1
                        self.setStatus(ctrl.pairingStatus)
                        self.setPIN(ctrl.pairingPIN)

                        if ctrl.running {
                            sawRunning = true
                            idleTicks = 0
                        } else {
                            idleTicks += 1
                        }

                        if !finishing {
                            let startedThenStopped = sawRunning && !ctrl.running
                            let neverStarted = !sawRunning && idleTicks > 50
                            let gaveUp = ticks > 3600
                            if startedThenStopped || neverStarted || gaveUp {
                                finishing = true
                                self.finishPairing(path: path, mtimeBefore: mtimeBefore, neverStarted: neverStarted)
                            }
                        }

                        if !self.pairingBusy {
                            t.invalidate()
                            self.statusTimer = nil
                        }
                    }
        }
    }

    private func finishPairing(path: String, mtimeBefore: Date?, neverStarted: Bool) {
        DispatchQueue.global(qos: .userInitiated).async {
            if neverStarted {
                self.setState(.idle)
                self.setStatus("Pairing host did not start. Check Local Network permission.")
                self.pairingBusy = false
                return
            }
            let kind = PairingFileKind.of(path: path)
            let mtime = AirliftBridge.fileMTime(path)
            let fresh = mtime != nil && mtime != mtimeBefore
            if kind.hasRemotePairing && fresh {
                        self.setStatus("Minting lockdown record...")
                        do {
                            try self.generateMerged(rppPath: path)
                            self.setState(.ready(pairingPath: path))
                            self.setStatus("Pairing file ready")
                        } catch {
                            self.setState(.idle)
                            if LockdownPair.cancelled {
                                self.setStatus("Cancelled")
                            } else {
                                self.setStatus("Failed: \(error.localizedDescription)")
                            }
                        }
            } else {
                self.setState(.idle)
                self.setStatus("No new pairing record was written. \(PairingController.shared.pairingStatus)")
            }
            self.setPIN(nil)
            self.pairingBusy = false
        }
    }

    private func generateMerged(rppPath: String) throws {
        let out = Self.documents.appendingPathComponent("ALTPairingFile.mobiledevicepairing")
        try PairingGenerator.shared.generateMergedPairing(
            rppPath: rppPath,
            outputPath: out.path
        )
    }

    func cancelPairing() {
        PairingGenerator.cancelMinting()
        PairingController.shared.softCancel()
        pairingBusy = false
        DispatchQueue.main.async {
            self.statusTimer?.invalidate()
            self.statusTimer = nil
            self.state = .idle
            self.pairingStatus = "Cancelled"
            self.pairPIN = nil
        }
    }

    func deletePairing() {
        let fm = FileManager.default
        let docs = Self.documents
        let candidates = [
            docs.appendingPathComponent("natsuk1_pairing.plist"),
            docs.appendingPathComponent("ALTPairingFile.mobiledevicepairing"),
            docs.appendingPathComponent("pairingFile.plist"),
        ]
        for url in candidates where fm.fileExists(atPath: url.path) {
            try? fm.removeItem(at: url)
        }
        if let custom = PairingController.customPairingFilePath, fm.fileExists(atPath: custom) {
            try? fm.removeItem(atPath: custom)
        }
        PairingController.customPairingFilePath = nil
        if let files = try? fm.contentsOfDirectory(atPath: docs.path) {
            for f in files {
                guard f.hasSuffix(".plist")
                    || f.hasSuffix(".mobilepairing")
                    || f.hasSuffix(".mobilepair") else { continue }
                try? fm.removeItem(at: docs.appendingPathComponent(f))
            }
        }
        UserDefaults.standard.removeObject(forKey: "natsuk1PairingHostAltIRK")
        UserDefaults.standard.removeObject(forKey: "natsuk1PairingPath")
        setState(.idle)
        setStatus("")
        setPIN(nil)
    }

    func runExploit() {
        let pairingPath = pairingFilePath()
        guard FileManager.default.fileExists(atPath: pairingPath) else {
            setState(.done(ok: false, message: "No pairing file"))
            return
        }
        setState(.running)
        DispatchQueue.main.async {
            self.loggedLines.removeAll()
            self.exploitLog = []
        }
        let t = target
        let bridge = self
        appendLog("[exploit] path=\(pairingPath) target=\(t)")
        DispatchQueue.global(qos: .userInitiated).async {
            var outJson: UnsafeMutablePointer<CChar>? = nil
            var outError: UnsafeMutablePointer<CChar>? = nil
            let rc: Int32 = pairingPath.withCString { pc in
                t.withCString { tc in
                    al_exploit_run(pc, tc, nil, nil, &outJson, &outError)
                }
            }
            let jsonStr = outJson.flatMap { p -> String? in
                let s = String(cString: p); al_string_free(p); return s
            }
            let errStr = outError.flatMap { p -> String? in
                let s = String(cString: p); al_string_free(p); return s
            }
            if rc == 0 {
                let msg = jsonStr ?? "OK"
                bridge.appendLog("[exploit] ok: \(msg)")
                bridge.setState(.done(ok: true, message: msg))
            } else {
                let msg = errStr ?? "rc=\(rc)"
                bridge.appendLog("[exploit] fail: \(msg)")
                bridge.setState(.done(ok: false, message: msg))
            }
        }
    }

    func cancelExploit() {
        appendLog("[exploit] cancel requested")
        setState(.done(ok: false, message: "cancelled"))
    }
}
