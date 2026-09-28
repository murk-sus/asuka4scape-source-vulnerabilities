import Foundation
import CoreTelephony
import UIKit

final class CarrierLabInstaller: @unchecked Sendable {
    static let shared = CarrierLabInstaller()

    private let state = CarrierLabState.shared
    private let bridge = CarrierLabBridge.shared
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
            if let c = prov?.mobileCountryCode, let m = prov?.mobileNetworkCode, !c.isEmpty, !m.isEmpty, !out.contains(c + m) { out.append(c + m) }
        }
        return out
    }

    private func luhn(_ s: String) -> Bool {
        var sum = 0, alt = false
        for ch in s.reversed() { guard let v0 = ch.wholeNumberValue else { return false }; var v = v0; if alt { v = v > 4 ? v * 2 - 9 : v * 2 }; sum += v; alt.toggle() }
        return sum % 10 == 0
    }

    private func luhnDigit(_ s: String) -> String {
        var sum = 0, alt = true
        for ch in s.reversed() { var v = ch.wholeNumberValue ?? 0; if alt { v = v > 4 ? v * 2 - 9 : v * 2 }; sum += v; alt.toggle() }
        return String((10 - sum % 10) % 10)
    }

    // 15-digit IMSI, or ICCID (Settings>About); the check digit is recomputed.
    private func imsiFrom(_ raw: String) -> String? {
        let d = raw.filter { $0.isNumber }
        if d.count == 15 { return luhn(d) ? d : nil }
        if d.count == 19 || d.count == 20, d.hasPrefix("89") {
            let c14 = String(d.dropFirst(4).prefix(14))
            return c14 + luhnDigit(c14)
        }
        return nil
    }

    // Identity: copy the ICCID (Settings>General>About) or the IMSI.
    func imsi() -> String? {
        guard let i = imsiFrom(UIPasteboard.general.string ?? "") else { return nil }
        let ps = plmns()
        guard ps.isEmpty || ps.contains(String(i.prefix(5))) else { return nil }
        return i
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
            return CarrierLabBridge.ProbeResult(
                state: .ffiFailed("no SIM; copy the ICCID in Settings>About and tap again"),
                detail: "none")
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
        state.appendLog("[5g] \(made.joined(separator: ",")) -> Vodafone_hu; \(r.ok ? "ok" : r.message); if 5G absent: airplane mode 10s")
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
