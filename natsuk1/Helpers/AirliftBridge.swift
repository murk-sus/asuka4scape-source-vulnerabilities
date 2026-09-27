import Foundation
import Combine

final class AirliftBridge: ObservableObject, @unchecked Sendable {
    static let shared = AirliftBridge()
    enum State: Equatable { case idle, pairing, ready(pairingPath: String), running, done(ok: Bool, message: String) }

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
            DispatchQueue.main.async { AirliftBridge.shared.appendLog(line) }
        }, nil)
    }

    private func appendLog(_ s: String) {
        DispatchQueue.main.async {
            self.loggedLines.append(s)
            if self.loggedLines.count > 800 { self.loggedLines.removeFirst(self.loggedLines.count - 600) }
            self.exploitLog = self.loggedLines
        }
    }

    func clearLog() {
        DispatchQueue.main.async {
            self.loggedLines.removeAll()
            self.exploitLog = []
        }
    }

    func pairingFilePath() -> String { PairingController.pairingFilePath() }

    func hasPairing() -> Bool {
        let p = pairingFilePath()
        guard FileManager.default.fileExists(atPath: p) else { return false }
        let size = (try? FileManager.default.attributesOfItem(atPath: p)[.size] as? Int) ?? 0
        return size > 0
    }

    private func setState(_ s: State) { DispatchQueue.main.async { self.state = s } }
    private func setStatus(_ s: String) { DispatchQueue.main.async { self.pairingStatus = s } }
    private func setPIN(_ p: String?) { DispatchQueue.main.async { self.pairPIN = p } }

    func runPairing() {
        guard !hasPairing() else {
            setState(.ready(pairingPath: pairingFilePath()))
            return
        }
        setState(.pairing)
        setStatus("Starting host...")
        setPIN(nil)
        let ctrl = PairingController.shared
        Task {
            do {
                let path = try await ctrl.startAndWait()
                self.setState(.ready(pairingPath: path))
                self.setStatus("Paired")
                self.setPIN(nil)
                try? self.generateMerged(rppPath: path)
            } catch is CancellationError {
                self.setState(.idle)
                self.setStatus("Cancelled")
            } catch {
                self.setState(.idle)
                self.setStatus("Failed: \(error.localizedDescription)")
            }
        }
        Task {
            var iterations = 0
            while iterations < 900 {
                let status = ctrl.pairingStatus
                let pin = ctrl.pairingPIN
                let running = ctrl.running
                self.setStatus(status)
                self.setPIN(pin)
                if !running { break }
                try? await Task.sleep(nanoseconds: 200_000_000)
                iterations += 1
            }
        }
    }

    private func generateMerged(rppPath: String) throws {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let out = docs.appendingPathComponent("ALTPairingFile.mobiledevicepairing")
        try PairingGenerator.shared.generateMergedPairing(
            rppPath: rppPath,
            outputPath: out.path
        )
    }

    func cancelPairing() {
        PairingController.shared.softCancel()
        setState(.idle)
        setStatus("")
        setPIN(nil)
    }

    func deletePairing() {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let candidates = [
            docs.appendingPathComponent("natsuk1_pairing.plist"),
            docs.appendingPathComponent("ALTPairingFile.mobiledevicepairing"),
            docs.appendingPathComponent("pairingFile.plist"),
        ]
        for url in candidates {
            if fm.fileExists(atPath: url.path) { try? fm.removeItem(at: url) }
        }
        if let custom = PairingController.customPairingFilePath, fm.fileExists(atPath: custom) {
            try? fm.removeItem(atPath: custom)
        }
        PairingController.customPairingFilePath = nil
        if let files = try? fm.contentsOfDirectory(atPath: docs.path) {
            for f in files {
                guard f.hasSuffix(".plist") || f.hasSuffix(".mobilepairing") || f.hasSuffix(".mobilepair") else { continue }
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
        bridge.appendLog("[exploit] path=\(pairingPath) target=\(t)")
        Task.detached {
            var outJson: UnsafeMutablePointer<CChar>? = nil
            var outError: UnsafeMutablePointer<CChar>? = nil
            let rc: Int32 = pairingPath.withCString { pc in
                t.withCString { tc in
                    al_exploit_run(pc, tc, nil, nil, &outJson, &outError)
                }
            }
            let jsonStr = outJson.flatMap { p -> String? in let s = String(cString: p); al_string_free(p); return s }
            let errStr = outError.flatMap { p -> String? in let s = String(cString: p); al_string_free(p); return s }
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

    func respring() {
        let pairingPath = pairingFilePath()
        guard FileManager.default.fileExists(atPath: pairingPath) else {
            appendLog("[respring] no pairing file")
            return
        }
        let bridge = self
        Task.detached {
            var outError: UnsafeMutablePointer<CChar>? = nil
            let rc: Int32 = pairingPath.withCString { pc in
                al_device_respring(pc, nil, nil, &outError)
            }
            let errStr = outError.flatMap { p -> String? in let s = String(cString: p); al_string_free(p); return s }
            if rc == 0 {
                bridge.appendLog("[respring] ok")
            } else {
                bridge.appendLog("[respring] rc=\(rc) \(errStr ?? "")")
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
                let containerStr = outContainer.flatMap { p -> String? in let s = String(cString: p); al_string_free(p); return s }
                if let p = outError { al_string_free(p) }
                if rc == 0, let c = containerStr { cont.resume(returning: c) }
                else { cont.resume(returning: nil) }
            }
        }
    }
}
