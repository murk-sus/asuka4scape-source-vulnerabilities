import Foundation

final class CarrierLabInstaller: @unchecked Sendable {
    static let shared = CarrierLabInstaller()

    private let state = CarrierLabState.shared
    private let bridge = CarrierLabBridge.shared

    struct CheckResult {
        let airliftOK: Bool
        let airliftMessage: String
        let carrierRootExists: Bool
        let bundleLinksExists: Bool
        let resourcesBundled: Bool
        let backupPresent: Bool
        let status: CarrierLabState.Status
    }

    func check() throws -> CheckResult {
        let fm = FileManager.default
        let (ok, msg) = bridge.probe()
        let root = bridge.carrierRootPath()
        let links = bridge.bundleLinksPath()
        let bundle = Bundle.main.bundleURL.appendingPathComponent("CarrierAssets/CarrierLab.bundle")
        return CheckResult(
            airliftOK: ok,
            airliftMessage: msg,
            carrierRootExists: fm.fileExists(atPath: root),
            bundleLinksExists: fm.fileExists(atPath: links),
            resourcesBundled: fm.fileExists(atPath: bundle.path),
            backupPresent: state.hasBackup(),
            status: state.session?.status ?? .clean
        )
    }

    func install() throws {
        let bundleRoot = Bundle.main.bundleURL.appendingPathComponent("CarrierAssets")
        let carrierBundle = bundleRoot.appendingPathComponent("CarrierLab.bundle")
        let docomoBundle = bundleRoot.appendingPathComponent("Docomo_jp.bundle")
        guard FileManager.default.fileExists(atPath: carrierBundle.path) else {
            throw NSError(domain: "carrierlab", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "CarrierLab.bundle отсутствует в бандле"])
        }
        guard FileManager.default.fileExists(atPath: docomoBundle.path) else {
            throw NSError(domain: "carrierlab", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Docomo_jp.bundle отсутствует в бандле"])
        }

        let (ok, msg) = bridge.probe()
        guard ok else {
            throw NSError(domain: "carrierlab", code: 4,
                          userInfo: [NSLocalizedDescriptionKey: "Airlift недоступен: \(msg)"])
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

        do {
            try bridge.writeFile(source: carrierBundle.path,
                                 target: bridge.bundleLinksPath() + "/CarrierLab.bundle")
            var done = s
            done.status = .placed
            state.save(done)
        } catch {
            var bad = s
            bad.status = .failed
            bad.lastError = error.localizedDescription
            state.save(bad)
            throw error
        }
    }

    func reload() throws {
        guard let s = state.session, s.status == .placed || s.status == .finished else {
            throw NSError(domain: "carrierlab", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Нечего перечитывать. Сначала Install."])
        }
        let docomoBundle = Bundle.main.bundleURL
            .appendingPathComponent("CarrierAssets/Docomo_jp.bundle")
        try bridge.writeFile(source: docomoBundle.path,
                             target: bridge.carrierRootPath() + "/Docomo_jp.bundle")
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
