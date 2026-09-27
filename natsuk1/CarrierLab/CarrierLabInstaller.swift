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

    func check() throws -> CheckResult {
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

    func install() throws {
        let carrierBundle = carrierBundleURL()
        let docomoBundle = docomoBundleURL()
        guard FileManager.default.fileExists(atPath: carrierBundle.path) else {
            throw NSError(domain: "carrierlab", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "CarrierLab.bundle missing from app bundle"])
        }
        guard FileManager.default.fileExists(atPath: docomoBundle.path) else {
            throw NSError(domain: "carrierlab", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Docomo_jp.bundle missing from app bundle"])
        }

        let s = CarrierLabState.Session(
            status: .placing,
            startedAt: Date(),
            carrierBundlePath: carrierBundle.path,
            originalBackupPath: state.backupURL().path,
            ipccTriggerPath: docomoBundle.path,
            lastError: nil,
            aliases: nil)
        state.save(s)

        let r1 = bridge.writeFile(source: carrierBundle.path,
                                  target: bridge.bundleLinksPath() + "/CarrierLab.bundle")
        guard r1.ok else {
            var bad = s
            bad.status = .failed
            bad.lastError = r1.message
            state.save(bad)
            throw NSError(domain: "carrierlab", code: 4,
                          userInfo: [NSLocalizedDescriptionKey: r1.message])
        }

        let r2 = bridge.writeFile(source: docomoBundle.path,
                                  target: bridge.carrierRootPath() + "/Docomo_jp.bundle")
        guard r2.ok else {
            var bad = s
            bad.status = .failed
            bad.lastError = r2.message
            state.save(bad)
            throw NSError(domain: "carrierlab", code: 4,
                          userInfo: [NSLocalizedDescriptionKey: r2.message])
        }

        var done = s
        done.status = .placed
        state.save(done)
    }

    func reload() throws {
        guard let s = state.session, s.status == .placed || s.status == .finished else {
            throw NSError(domain: "carrierlab", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Nothing to reload. Install first."])
        }
        let r = bridge.writeFile(source: docomoBundleURL().path,
                                 target: bridge.carrierRootPath() + "/Docomo_jp.bundle")
        guard r.ok else {
            throw NSError(domain: "carrierlab", code: 4,
                          userInfo: [NSLocalizedDescriptionKey: r.message])
        }
        _ = s
    }

    func finish() throws {
        guard let s = state.session else { return }
        var done = s
        done.status = .finished
        state.save(done)
    }

    func reset() throws {
        state.clear()
    }
}
