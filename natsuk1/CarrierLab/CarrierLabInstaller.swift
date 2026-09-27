import Foundation

final class CarrierLabInstaller: @unchecked Sendable {
    static let shared = CarrierLabInstaller()

    private let state = CarrierLabState.shared
    private let bridge = CarrierLabBridge.shared

    struct CheckResult {
        let probe: CarrierLabBridge.ProbeResult
        let carrierRootExists: Bool
        let bundleLinksExists: Bool
        let resourcesBundled: Bool
        let backupPresent: Bool
        let status: CarrierLabState.Status
    }

    func carrierBundleURL() -> URL {
        Bundle.main.bundleURL.appendingPathComponent("CarrierAssets/CarrierLab.bundle")
    }

    func docomoBundleURL() -> URL {
        Bundle.main.bundleURL.appendingPathComponent("CarrierAssets/Docomo_jp.bundle")
    }

    func check() -> CheckResult {
        let fm = FileManager.default
        let probe = bridge.probe()
        return CheckResult(
            probe: probe,
            carrierRootExists: fm.fileExists(atPath: bridge.carrierRootPath()),
            bundleLinksExists: fm.fileExists(atPath: bridge.bundleLinksPath()),
            resourcesBundled: fm.fileExists(atPath: carrierBundleURL().path),
            backupPresent: state.hasBackup(),
            status: state.session?.status ?? .clean
        )
    }

    func install() -> CarrierLabBridge.ProbeResult {
        let carrierBundle = carrierBundleURL()
        let docomoBundle = docomoBundleURL()
        guard FileManager.default.fileExists(atPath: carrierBundle.path) else {
            return CarrierLabBridge.ProbeResult(state: .ffiFailed("CarrierLab.bundle missing"), detail: "missing")
        }
        guard FileManager.default.fileExists(atPath: docomoBundle.path) else {
            return CarrierLabBridge.ProbeResult(state: .ffiFailed("Docomo_jp.bundle missing"), detail: "missing")
        }
        let pre = bridge.probe()
        guard pre.ok else { return pre }

        let s = CarrierLabState.Session(
            status: .placing,
            startedAt: Date(),
            carrierBundlePath: carrierBundle.path,
            originalBackupPath: state.backupURL().path,
            ipccTriggerPath: docomoBundle.path,
            lastError: nil,
            aliases: ["25001", "25001_GID1-AA"])
        state.save(s)

        let r1 = bridge.injectFolder(
            sourceFolder: carrierBundle.path,
            targetFolder: bridge.carrierRootPath(),
            folderName: "CarrierLab.bundle")
        if !r1.ok {
            var bad = s
            bad.status = .failed
            bad.lastError = r1.message
            state.save(bad)
            return r1
        }

        let r2 = bridge.injectFolder(
            sourceFolder: docomoBundle.path,
            targetFolder: bridge.carrierRootPath(),
            folderName: "Docomo_jp.bundle")
        if !r2.ok {
            var bad = s
            bad.status = .failed
            bad.lastError = r2.message
            state.save(bad)
            return r2
        }

        let r3 = bridge.installSymlinks(
            names: ["25001", "25001_GID1-AA"],
            destination: bridge.bundleLinksPath())

        var done = s
        done.status = r3.ok ? .placed : .failed
        if !r3.ok { done.lastError = r3.message }
        state.save(done)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            AirliftBridge.shared.respring()
        }
        return CarrierLabBridge.ProbeResult(state: .ok, detail: "installed, links=\(r3.ok)")
    }

    func reload() -> CarrierLabBridge.ProbeResult {
        guard let s = state.session, s.status == .placed || s.status == .finished else {
            return CarrierLabBridge.ProbeResult(state: .ffiFailed("Nothing to reload. Install first."), detail: "no session")
        }
        _ = s
        let r = bridge.injectFolder(
            sourceFolder: docomoBundleURL().path,
            targetFolder: bridge.carrierRootPath(),
            folderName: "Docomo_jp.bundle")
        if r.ok {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                AirliftBridge.shared.respring()
            }
        }
        return r
    }

    func finish() {
        guard let s = state.session else { return }
        var done = s
        done.status = .finished
        state.save(done)
    }

    func reset() {
        state.clear()
    }
}
