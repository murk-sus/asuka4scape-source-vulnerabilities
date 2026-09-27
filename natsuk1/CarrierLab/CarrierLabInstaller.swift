import Foundation

final class CarrierLabInstaller: @unchecked Sendable {
    static let shared = CarrierLabInstaller()

    private let state = CarrierLabState.shared
    private let bridge = CarrierLabBridge.shared

    struct CheckResult {
        let probe: CarrierLabBridge.ProbeResult
        let carrierUserRootExists: Bool
        let carrierRootExists: Bool
        let resourcesBundled: Bool
        let sourceFiles: Int
        let sourceBytes: Int
        let backupPresent: Bool
        let status: CarrierLabState.Status
    }

    struct InstallResult {
        let ok: Bool
        let message: String
        let slotsWritten: [String]
        let failures: [String]
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
        let tree = bridge.localTreeSummary(carrierBundleURL().path)
        return CheckResult(
            probe: probe,
            carrierUserRootExists: fm.fileExists(atPath: CarrierLabBridge.carrierUserRoot),
            carrierRootExists: fm.fileExists(atPath: CarrierLabBridge.carrierRoot),
            resourcesBundled: fm.fileExists(atPath: carrierBundleURL().path)
                && fm.fileExists(atPath: docomoBundleURL().path),
            sourceFiles: tree.files,
            sourceBytes: tree.bytes,
            backupPresent: state.hasBackup(),
            status: state.session?.status ?? .clean)
    }

    func diagnose() -> [String] {
        let fm = FileManager.default
        var lines: [String] = []
        let pairing = bridge.findPairingFile()
        lines.append("[diagnose] pairing=\(pairing ?? "none")")
        if let p = pairing {
            let size = (try? fm.attributesOfItem(atPath: p)[.size] as? Int) ?? 0
            let kind = PairingFileKind.of(path: p)
            lines.append("[diagnose] bytes=\(size) rpPairing=\(kind.hasRemotePairing) "
                + "lockdown=\(kind.hasLockdown) udid=\(kind.udid ?? "-")")
        }
        lines.append("[diagnose] vpn=\(NetworkStatus.loopbackVPNUp()) peer=\(NetworkStatus.tunnelIP() ?? "-") "
            + "local=\(NetworkStatus.deviceIP() ?? "-")")
        lines.append("[diagnose] userRoot=\(CarrierLabBridge.carrierUserRoot) "
            + "exists=\(fm.fileExists(atPath: CarrierLabBridge.carrierUserRoot))")
        lines.append("[diagnose] iphoneRoot=\(CarrierLabBridge.carrierRoot) "
            + "exists=\(fm.fileExists(atPath: CarrierLabBridge.carrierRoot))")
        lines.append("[diagnose] slots=\(state.slots.joined(separator: ","))")
        let src = carrierBundleURL().path
        let tree = bridge.localTreeSummary(src)
        lines.append("[diagnose] source=\(src) files=\(tree.files) bytes=\(tree.bytes)")
        for n in tree.names { lines.append("[diagnose]   \(n)") }
        let doc = docomoBundleURL().path
        let docTree = bridge.localTreeSummary(doc)
        lines.append("[diagnose] trigger=\(doc) files=\(docTree.files) bytes=\(docTree.bytes)")
        return lines
    }

    private func preflight(_ source: String) -> String? {
        let summary = bridge.localTreeSummary(source)
        if summary.isEmpty {
            return "no files in directory: \(source) is empty or is not a directory"
        }
        return nil
    }

    func install() -> InstallResult {
        let fm = FileManager.default
        let carrierBundle = carrierBundleURL()
        let docomoBundle = docomoBundleURL()
        guard fm.fileExists(atPath: carrierBundle.path) else {
            return InstallResult(ok: false, message: "CarrierLab.bundle missing", slotsWritten: [], failures: [])
        }
        guard fm.fileExists(atPath: docomoBundle.path) else {
            return InstallResult(ok: false, message: "Docomo_jp.bundle missing", slotsWritten: [], failures: [])
        }
        let pre = bridge.probe()
        guard pre.ok else {
            return InstallResult(ok: false, message: pre.message, slotsWritten: [], failures: [])
        }
        if let problem = preflight(carrierBundle.path) {
            return InstallResult(ok: false, message: problem, slotsWritten: [], failures: [problem])
        }

        let slots = state.slots
        state.save(CarrierLabState.Session(
            status: .placing,
            startedAt: Date(),
            carrierBundlePath: carrierBundle.path,
            originalBackupPath: state.backupURL().path,
            ipccTriggerPath: docomoBundle.path,
            lastError: nil,
            aliases: nil,
            slots: slots))

        var written: [String] = []
        var failures: [String] = []

        for slot in slots {
            let r = bridge.injectFolder(sourceFolder: carrierBundle.path,
                                        targetParent: CarrierLabBridge.carrierUserRoot,
                                        destName: slot)
            if r.ok {
                written.append(slot)
                state.appendLog("[install] slot \(slot) ok")
            } else {
                failures.append("\(slot): \(r.message)")
                state.appendLog("[install] slot \(slot) failed: \(r.message)")
            }
        }

        if !failures.isEmpty {
            state.save(CarrierLabState.Session(
                status: .failed,
                startedAt: Date(),
                carrierBundlePath: carrierBundle.path,
                originalBackupPath: state.backupURL().path,
                ipccTriggerPath: docomoBundle.path,
                lastError: failures.joined(separator: " | "),
                aliases: nil,
                slots: written))
            return InstallResult(ok: false,
                                 message: failures.joined(separator: " | "),
                                 slotsWritten: written,
                                 failures: failures)
        }

        let trigger = bridge.injectFolder(sourceFolder: docomoBundle.path,
                                          targetParent: CarrierLabBridge.carrierRoot,
                                          destName: "Docomo_jp.bundle")
        if !trigger.ok {
            state.save(CarrierLabState.Session(
                status: .failed,
                startedAt: Date(),
                carrierBundlePath: carrierBundle.path,
                originalBackupPath: state.backupURL().path,
                ipccTriggerPath: docomoBundle.path,
                lastError: trigger.message,
                aliases: nil,
                slots: written))
            return InstallResult(ok: false, message: trigger.message, slotsWritten: written, failures: [trigger.message])
        }

        state.save(CarrierLabState.Session(
            status: .placed,
            startedAt: Date(),
            carrierBundlePath: carrierBundle.path,
            originalBackupPath: state.backupURL().path,
            ipccTriggerPath: docomoBundle.path,
            lastError: nil,
            aliases: nil,
            slots: written))
        state.appendLog("[install] placed into \(written.joined(separator: ","))")
        return InstallResult(ok: true, message: "installed", slotsWritten: written, failures: [])
    }

    func reload() -> InstallResult {
        guard let s = state.session, s.status == .placed || s.status == .finished else {
            return InstallResult(ok: false, message: "Nothing to reload. Install first.",
                                 slotsWritten: [], failures: [])
        }
        let trigger = bridge.injectFolder(sourceFolder: docomoBundleURL().path,
                                          targetParent: CarrierLabBridge.carrierRoot,
                                          destName: "Docomo_jp.bundle")
        state.appendLog(trigger.ok ? "[reload] trigger ok" : "[reload] trigger failed: \(trigger.message)")
        return InstallResult(ok: trigger.ok, message: trigger.message,
                             slotsWritten: s.slots ?? [], failures: trigger.ok ? [] : [trigger.message])
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
