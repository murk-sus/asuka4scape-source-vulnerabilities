import Foundation
import CoreTelephony

final class CarrierLabInstaller: @unchecked Sendable {
    static let shared = CarrierLabInstaller()

    private let state = CarrierLabState.shared
    private let bridge = CarrierLabBridge.shared
    // CarrierSIM (4pda): alias the SIM to the system Vodafone_hu bundle
    // (5G / VoWiFi / EVS, Apple-signed); the per-build Docomo IPCC after it
    // makes CommCenter rescan and pick the alias.
    private let vodafoneHu = "/System/Library/Carrier Bundles/iPhone/Vodafone_hu.bundle"

    struct CheckResult {
        let probe: CarrierLabBridge.ProbeResult
        let resourcesBundled: Bool
        let status: CarrierLabState.Status
    }

    private func carrierBundleURL() -> URL { Bundle.main.bundleURL.appendingPathComponent("CarrierAssets/CarrierLab.bundle") }
    private func docomoBundleURL() -> URL { Bundle.main.bundleURL.appendingPathComponent("CarrierAssets/Docomo_jp.bundle") }

    func check() -> CheckResult {
        let probe = bridge.probe()
        return CheckResult(probe: probe,
            resourcesBundled: FileManager.default.fileExists(atPath: carrierBundleURL().path),
            status: state.session?.status ?? .clean)
    }

    func plmns() -> [String] {
        var out: [String] = []
        for prov in (CTTelephonyNetworkInfo().serviceSubscriberCellularProviders ?? [:]).values {
            if let c = prov?.mobileCountryCode, let m = prov?.mobileNetworkCode,
               !c.isEmpty, !m.isEmpty, !out.contains(c + m) { out.append(c + m) }
        }
        return out
    }

    // Optional 15-digit IMSI from natsuk1_imsi.txt in the app's Documents.
    func imsi() -> String? {
        let p = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("natsuk1_imsi.txt").path
        guard let t = try? String(contentsOfFile: p, encoding: .utf8) else { return nil }
        let d = t.filter { $0.isNumber }
        return d.count == 15 ? d : nil
    }

    private func names() -> [String] {
        var n = plmns()
        if let i = imsi(), !n.contains(i) { n.append(i) }
        return n
    }

    @discardableResult
    func applyLinks() -> CarrierLabBridge.ProbeResult {
        let names = names()
        guard !names.isEmpty else {
            return CarrierLabBridge.ProbeResult(state: .ffiFailed("no SIM; drop the 15-digit IMSI into natsuk1_imsi.txt"), detail: "none")
        }
        let fm = FileManager.default
        let stage = fm.temporaryDirectory.appendingPathComponent("nklinks")
        try? fm.removeItem(at: stage)
        try? fm.createDirectory(at: stage, withIntermediateDirectories: true)
        var made: [String] = []
        for n in names {
            if (try? fm.createSymbolicLink(atPath: stage.appendingPathComponent(n).path,
                                           withDestinationPath: vodafoneHu)) != nil { made.append(n) }
        }
        guard !made.isEmpty else {
            return CarrierLabBridge.ProbeResult(state: .ffiFailed("symlink staging failed"), detail: "staging")
        }
        let r = bridge.injectFolder(sourceFolder: stage.path, targetFolder: bridge.bundleLinksPath(), folderName: "iPhone")
        state.appendLog("[5g] aliases=\(made.joined(separator: ",")) -> Vodafone_hu; \(r.ok ? "ok" : r.message); if 5G is absent: airplane mode 10s")
        return r
    }

    private func save(_ s: CarrierLabState.Status, _ err: String?) {
        state.save(CarrierLabState.Session(status: s, startedAt: Date(),
            carrierBundlePath: carrierBundleURL().path, originalBackupPath: state.backupURL().path,
            ipccTriggerPath: docomoBundleURL().path, lastError: err,
            aliases: s == .placed ? names() : nil))
    }

    func install() -> CarrierLabBridge.ProbeResult {
        guard FileManager.default.fileExists(atPath: carrierBundleURL().path),
              FileManager.default.fileExists(atPath: docomoBundleURL().path) else {
            return CarrierLabBridge.ProbeResult(state: .ffiFailed("carrier bundles missing"), detail: "missing")
        }
        let pre = bridge.probe()
        guard pre.ok else { return pre }
        save(.placing, nil)
        let r1 = bridge.injectFolder(sourceFolder: carrierBundleURL().path,
                                     targetFolder: bridge.bundleLinksPath(), folderName: "CarrierLab.bundle")
        if !r1.ok { save(.failed, r1.message); return r1 }
        let r2 = applyLinks()
        if !r2.ok { save(.failed, r2.message); return r2 }
        let r3 = bridge.injectFolder(sourceFolder: docomoBundleURL().path,
                                     targetFolder: bridge.carrierRootPath(), folderName: "Docomo_jp.bundle")
        if !r3.ok { save(.failed, r3.message); return r3 }
        save(.placed, nil)
        return CarrierLabBridge.ProbeResult(state: .ok, detail: "installed (5G link + trigger)")
    }

    func reload() -> CarrierLabBridge.ProbeResult {
        guard state.session?.status == .placed || state.session?.status == .finished else {
            return CarrierLabBridge.ProbeResult(state: .ffiFailed("Nothing to reload. Install first."), detail: "no session")
        }
        let r2 = applyLinks()
        if !r2.ok { return r2 }
        return bridge.injectFolder(sourceFolder: docomoBundleURL().path,
                                   targetFolder: bridge.carrierRootPath(), folderName: "Docomo_jp.bundle")
    }

    func finish() {
        guard let s = state.session else { return }
        var done = s
        done.status = .finished
        state.save(done)
    }

    func reset() { state.clear() }
}
