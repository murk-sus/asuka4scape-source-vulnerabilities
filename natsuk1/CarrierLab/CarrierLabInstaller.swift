import Foundation

final class CarrierLabInstaller: @unchecked Sendable {
    static let shared = CarrierLabInstaller()

    private let state = CarrierLabState.shared
    private let bridge = CarrierLabBridge.shared

    struct CheckResult {
        let carrierRootExists: Bool
        let bundleLinksExists: Bool
        let currentLinks: [String]
        let backupPresent: Bool
        let status: CarrierLabState.Status
    }

    func check() throws -> CheckResult {
        let fm = FileManager.default
        let root = bridge.carrierRootPath()
        let links = bridge.bundleLinksPath()
        var entries: [String] = []
        if let e = try? fm.contentsOfDirectory(atPath: links) { entries = e }
        return CheckResult(
            carrierRootExists: fm.fileExists(atPath: root),
            bundleLinksExists: fm.fileExists(atPath: links),
            currentLinks: entries,
            backupPresent: state.hasBackup(),
            status: state.session?.status ?? .clean
        )
    }

    func install(sourceBundlePath: String, ipccPath: String) throws {
        if state.session != nil && !state.hasBackup() {
            throw NSError(domain: "carrierlab", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Session already placed. Run finish or reload."])
        }
        let s = CarrierLabState.Session(
            status: .placing,
            startedAt: Date(),
            carrierBundlePath: sourceBundlePath,
            originalBackupPath: state.backupURL().path,
            ipccTriggerPath: ipccPath,
            lastError: nil)
        state.save(s)

        do {
            try bridge.writeFile(source: sourceBundlePath, target: bridge.bundleLinksPath())
            try bridge.writeFile(source: ipccPath, target: bridge.carrierRootPath())
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

    func reload(ipccPath: String) throws {
        guard let s = state.session, s.status == .placed || s.status == .finished else {
            throw NSError(domain: "carrierlab", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Nothing to reload. Install first."])
        }
        try bridge.writeFile(source: ipccPath, target: bridge.carrierRootPath())
    }

    func finish() throws {
        guard let s = state.session else { return }
        var done = s
        done.status = .finished
        state.save(done)
    }
}
