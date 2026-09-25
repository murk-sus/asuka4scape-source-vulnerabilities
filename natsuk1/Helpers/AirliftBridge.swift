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
            if self.loggedLines.count > 500 {
                self.loggedLines.removeFirst(self.loggedLines.count - 400)
            }
            self.exploitLog = self.loggedLines
        }
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
        try? FileManager.default.removeItem(atPath: pairingFilePath())
        PairingController.customPairingFilePath = nil
        state = .idle
        pairingStatus = ""
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
                    self.state = .done(ok: true, message: msg)
                } else {
                    let msg = errStr ?? "rc=\(rc)"
                    self.state = .done(ok: false, message: msg)
                }
            }
        }
    }

    func respring() {
        let pairingPath = PairingController.pairingFilePath()
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
