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
            aliases: nil)
        state.save(s)

        let r1 = bridge.writeFile(source: carrierBundle.path, target: bridge.bundleLinksPath() + "/CarrierLab.bundle")
        if !r1.ok {
            var bad = s
            bad.status = .failed
            bad.lastError = r1.message
            state.save(bad)
            return r1
        }
        let r2 = bridge.writeFile(source: docomoBundle.path, target: bridge.carrierRootPath() + "/Docomo_jp.bundle")
        if !r2.ok {
            var bad = s
            bad.status = .failed
            bad.lastError = r2.message
            state.save(bad)
            return r2
        }
        var done = s
        done.status = .placed
        state.save(done)
        return CarrierLabBridge.ProbeResult(state: .ok, detail: "installed")
    }

    func reload() -> CarrierLabBridge.ProbeResult {
        guard let s = state.session, s.status == .placed || s.status == .finished else {
            return CarrierLabBridge.ProbeResult(state: .ffiFailed("Nothing to reload. Install first."), detail: "no session")
        }
        _ = s
        return bridge.writeFile(source: docomoBundleURL().path, target: bridge.carrierRootPath() + "/Docomo_jp.bundle")
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
