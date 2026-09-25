import Foundation
import AirliftFFI

/// Drives the RPPairing host: requests Local Network, keeps the app alive while
/// the user approves the PIN in Settings, advertises the service over Bonjour,
/// and runs `al_pairing_run_host` off the main thread.
final class PairingController: ObservableObject, @unchecked Sendable {

    nonisolated(unsafe) static let shared = PairingController()

    private let hostName = "natsuk1"
    private let hostModel = "Mac17,7"   // device sees a Mac-like pairing host
    private let bindAddress = "0.0.0.0"

    private var netService: NetService?
    private let localNetwork = LocalNetworkAuthorization()
    private let keepAlive = KeepAlive()

    private(set) var running = false
    var pairingStatus: String = "idle"
    var pairingPIN: String? = nil

    /// Path to the pairing file that was actively found or created.
    nonisolated(unsafe) static var customPairingFilePath: String? = nil

    /// Persisted altIRK keeps the host identity stable across pairings so a
    /// device that has already paired recognises this host.
    private static let altIRKKey = "natsuk1PairingHostAltIRK"
    private static var storedAltIRK: String {
        get { UserDefaults.standard.string(forKey: altIRKKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: altIRKKey) }
    }

    private var pairContinuation: CheckedContinuation<String, Error>?

    // MARK: - Public API

    enum PairingError: LocalizedError {
        case busy
        case localNetworkDenied
        case zeroBytes
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .busy: return "Pairing is already in progress."
            case .localNetworkDenied: return "Local Network permission is off. Enable it in Settings › natsuk1 › Local Network."
            case .zeroBytes: return "Pairing produced an empty file. Approve the pairing request, then try again."
            case let .failed(msg): return msg
            }
        }
    }

    /// Ensures the given pairing file is mirrored to canonical natsuk1_pairing.plist and natsuk1_pairing.plist.
    @discardableResult
    static func syncCanonicalPairingFile(from sourcePath: String) -> String {
        let fm = FileManager.default
        let dir = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let canonicalURL = dir.appendingPathComponent("natsuk1_pairing.plist")

        if let data = try? Data(contentsOf: URL(fileURLWithPath: sourcePath)), !data.isEmpty {
            if sourcePath != canonicalURL.path {
                try? data.write(to: canonicalURL, options: .atomic)
                try? fm.removeItem(atPath: sourcePath)
            }
        }

        if let files = try? fm.contentsOfDirectory(atPath: dir.path) {
            for f in files {
                guard f.hasSuffix(".plist")
                   || f.hasSuffix(".mobilepairing")
                   || f.hasSuffix(".mobilepair") else { continue }
                let path = dir.appendingPathComponent(f).path
                if path == canonicalURL.path { continue }
                try? fm.removeItem(atPath: path)
            }
        }

        customPairingFilePath = canonicalURL.path
        return canonicalURL.path
    }

    /// Path where the pairing file is written or read from.
    /// Checks for canonical natsuk1_pairing.plist, custom path, or any plist in Documents,
    /// automatically adopting and standardizing it.
    static func pairingFilePath() -> String {
        let fm = FileManager.default
        let dir = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let canonical = dir.appendingPathComponent("natsuk1_pairing.plist").path

        if fm.fileExists(atPath: canonical) {
            let size = (try? fm.attributesOfItem(atPath: canonical)[.size] as? Int) ?? 0
            if size > 0 {
                if let files = try? fm.contentsOfDirectory(atPath: dir.path) {
                    for f in files {
                        guard f.hasSuffix(".plist")
                           || f.hasSuffix(".mobilepairing")
                           || f.hasSuffix(".mobilepair") else { continue }
                        let path = dir.appendingPathComponent(f).path
                        if path == canonical { continue }
                        try? fm.removeItem(atPath: path)
                    }
                }
                return canonical
            }
        }

        if let custom = customPairingFilePath, fm.fileExists(atPath: custom) {
            let size = (try? fm.attributesOfItem(atPath: custom)[.size] as? Int) ?? 0
            if size > 0 {
                return syncCanonicalPairingFile(from: custom)
            }
        }

        if let files = try? fm.contentsOfDirectory(atPath: dir.path) {
            for candidate in files {
                guard candidate.hasSuffix(".plist")
                   || candidate.hasSuffix(".mobiledevicepairing")
                   || candidate.hasSuffix(".mobilepair") else { continue }
                let candidatePath = dir.appendingPathComponent(candidate).path
                let size = (try? fm.attributesOfItem(atPath: candidatePath)[.size] as? Int) ?? 0
                if size > 0 {
                    return syncCanonicalPairingFile(from: candidatePath)
                }
            }
        }
        return canonical
    }

    /// Start the host and resolve with the pairing-file path, or throw.
    func startAndWait() async throws -> String {
        // If already running, cancel previous to allow clean restart
        if running {
            softCancel()
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return try await withCheckedThrowingContinuation { cont in
            pairContinuation = cont
            start()
        }
    }

    func softCancel() {
        stopAdvertising()
        keepAlive.stopAll()
        running = false
        pairingPIN = nil
        pairingStatus = "Cancelled"
        resolve(.failure(CancellationError()))
    }

    private func resolve(_ result: Result<String, Error>) {
        guard let cont = pairContinuation else { return }
        pairContinuation = nil
        cont.resume(with: result)
    }

    func start() {
        stopAdvertising()
        keepAlive.stopAll()
        running = true
        pairingPIN = nil
        pairingStatus = "Starting local host…"

        Task {
            _ = await localNetwork.request()
            guard running else { return }

            keepAlive.startAudio()
            pairingStatus = "Broadcasting… open Settings to pair"
            runHost()
        }
    }

    // MARK: - Private

    private func runHost() {
        let bind = bindAddress
        let name = hostName
        let model = hostModel
        let outPath = Self.pairingFilePath()
        let altIRK = Self.storedAltIRK
        let ctx = UnsafeMutableRawPointer(
            Unmanaged.passRetained(self).toOpaque()
        )

        DispatchQueue.global(qos: .userInitiated).async {
            var result = ALPairResult()
            let rc = bind.withCString { bindC in
                name.withCString { nameC in
                    model.withCString { modelC in
                        outPath.withCString { outC in
                            altIRK.withCString { irkC in
                                al_pairing_run_host(
                                    bindC, 0, nameC, modelC, outC, irkC,
                                    pairReadyCallback, pairPinCallback, ctx, &result)
                            }
                        }
                    }
                }
            }

            let outcome: Outcome
            if rc == 0 {
                let issued = cStr(result.host_alt_irk_hex)
                if !issued.isEmpty { Self.storedAltIRK = issued }
                let devName = cStr(result.device_name)
                let filePath = cStr(result.pairing_file_path)
                outcome = .success(
                    name: devName.isEmpty ? "iPhone" : devName,
                    path: filePath.isEmpty ? outPath : filePath
                )
            } else {
                let msg = cStr(result.error)
                outcome = .failure(msg.isEmpty ? "pairing failed (rc=\(rc))" : msg)
            }
            al_pairing_result_free(&result)

            let box = RawPtrBox(ctx)
            DispatchQueue.main.async {
                Unmanaged<PairingController>.fromOpaque(box.ptr).release()
                self.finish(outcome)
            }
        }
    }

    private enum Outcome {
        case success(name: String, path: String)
        case failure(String)
    }

    private func finish(_ outcome: Outcome) {
        stopAdvertising()
        // Keep background alive for 5s so iOS doesn't kill the app before user returns from Settings
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.keepAlive.stopAll()
        }
        running = false
        pairingPIN = nil

        switch outcome {
        case let .success(name, path):
            let canonical = Self.syncCanonicalPairingFile(from: path)
            let size = (try? FileManager.default.attributesOfItem(atPath: canonical)[.size] as? Int) ?? 0
            if size == 0 {
                pairingStatus = "Failed: empty pairing file"
                resolve(.failure(PairingError.zeroBytes))
            } else {
                pairingStatus = "Paired: \(name) (\(size)B)"
                resolve(.success(canonical))
            }
        case let .failure(message):
            pairingStatus = "Failed: \(message)"
            resolve(.failure(PairingError.failed(message)))
        }
    }


    // MARK: Bonjour advertising

    fileprivate func startAdvertising(serviceID: String, port: Int32, txt: [String: Data]) {
        stopAdvertising()
        let service = NetService(
            domain: "",
            type: "_remotepairing-pairable-host._tcp.",
            name: serviceID,
            port: port
        )
        service.setTXTRecord(NetService.data(fromTXTRecord: txt))
        service.publish()
        netService = service
        pairingStatus = "Advertising — open Settings › Privacy & Security › Developer Mode"
    }

    fileprivate func presentPin(_ pin: String) {
        pairingPIN = pin
        pairingStatus = "Enter PIN \(pin) in Settings › Privacy & Security › Developer Mode › Pair with natsuk1"
    }

    private func stopAdvertising() {
        netService?.stop()
        netService = nil
    }
}

// MARK: - C callbacks

nonisolated(unsafe) private let pairReadyCallback: ALPairReadyCb = { ctx, serviceID, port, keys, vals, count in
    guard let ctx = ctx, let serviceID = serviceID else { return }
    let controller = Unmanaged<PairingController>.fromOpaque(ctx).takeUnretainedValue()
    let id = String(cString: serviceID)

    var txt: [String: Data] = [:]
    if let keys = keys, let vals = vals {
        for i in 0..<Int(count) {
            guard let k = keys[i], let v = vals[i] else { continue }
            txt[String(cString: k)] = Data(String(cString: v).utf8)
        }
    }
    DispatchQueue.main.async {
        controller.startAdvertising(serviceID: id, port: Int32(port), txt: txt)
    }
}

nonisolated(unsafe) private let pairPinCallback: ALPairPinCb = { pin, ctx in
    guard let ctx = ctx, let pin = pin else { return }
    let controller = Unmanaged<PairingController>.fromOpaque(ctx).takeUnretainedValue()
    let pinString = String(cString: pin)
    DispatchQueue.main.async {
        controller.presentPin(pinString)
    }
}

private func cStr(_ ptr: UnsafeMutablePointer<CChar>?) -> String {
    guard let ptr = ptr else { return "" }
    return String(cString: ptr)
}


final class RawPtrBox: @unchecked Sendable {
    let ptr: UnsafeMutableRawPointer
    init(_ ptr: UnsafeMutableRawPointer) { self.ptr = ptr }
}
