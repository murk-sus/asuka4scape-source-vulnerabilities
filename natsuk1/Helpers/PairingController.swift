import Foundation
final class PairingController: ObservableObject, @unchecked Sendable {

    static let shared = PairingController()

    private let hostName = "natsuk1"
    private let hostModel = "Mac17,7"   
    private let bindAddress = "0.0.0.0"

    private var netService: NetService?
    private let localNetwork = LocalNetworkAuthorization()
    private let keepAlive = KeepAlive()

    @Published private(set) var running = false
    @Published var pairingStatus: String = "idle"
    @Published var pairingPIN: String? = nil

    nonisolated(unsafe) static var customPairingFilePath: String? = nil

    private static let altIRKKey = "aircardPairingHostAltIRK"
    private static var storedAltIRK: String {
        get { UserDefaults.standard.string(forKey: altIRKKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: altIRKKey) }
    }

    private var pairContinuation: CheckedContinuation<String, Error>?

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

    @discardableResult
    static func syncCanonicalPairingFile(from sourcePath: String) -> String {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let aircardURL = dir.appendingPathComponent("aircard_pairing.plist")
        let airliftURL = dir.appendingPathComponent("airlift_pairing.plist")

        if let data = try? Data(contentsOf: URL(fileURLWithPath: sourcePath)), !data.isEmpty {
            if sourcePath != aircardURL.path {
                try? data.write(to: aircardURL, options: .atomic)
            }
            if sourcePath != airliftURL.path {
                try? data.write(to: airliftURL, options: .atomic)
            }
            customPairingFilePath = aircardURL.path
            return aircardURL.path
        }
        return sourcePath
    }

    static func pairingFilePath() -> String {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let aircardPath = dir.appendingPathComponent("aircard_pairing.plist").path
        if FileManager.default.fileExists(atPath: aircardPath) {
            let size = (try? FileManager.default.attributesOfItem(atPath: aircardPath)[.size] as? Int) ?? 0
            if size > 0 { return aircardPath }
        }

        let airliftPath = dir.appendingPathComponent("airlift_pairing.plist").path
        if FileManager.default.fileExists(atPath: airliftPath) {
            let size = (try? FileManager.default.attributesOfItem(atPath: airliftPath)[.size] as? Int) ?? 0
            if size > 0 {
                _ = syncCanonicalPairingFile(from: airliftPath)
                return aircardPath
            }
        }

        if let custom = customPairingFilePath, FileManager.default.fileExists(atPath: custom) {
            let size = (try? FileManager.default.attributesOfItem(atPath: custom)[.size] as? Int) ?? 0
            if size > 0 {
                _ = syncCanonicalPairingFile(from: custom)
                return aircardPath
            }
        }

        if let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path) {
            let plists = files.filter {
                $0.hasSuffix(".plist") || $0.hasSuffix(".mobiledevicepairing") || $0.hasSuffix(".mobilepair")
            }
            for candidate in plists {
                let candidatePath = dir.appendingPathComponent(candidate).path
                let size = (try? FileManager.default.attributesOfItem(atPath: candidatePath)[.size] as? Int) ?? 0
                if size > 0 {
                    _ = syncCanonicalPairingFile(from: candidatePath)
                    return aircardPath
                }
            }
        }

        return aircardPath
    }

    func startAndWait() async throws -> String {

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

    private func runHost() {
        let bind = bindAddress
        let name = hostName
        let model = hostModel
        let outPath = Self.pairingFilePath()
        let altIRK = Self.storedAltIRK
        nonisolated(unsafe) let ctx = UnsafeMutableRawPointer(
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

            DispatchQueue.main.async {
                Unmanaged<PairingController>.fromOpaque(ctx).release()
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

private let pairReadyCallback: ALPairReadyCb = { ctx, serviceID, port, keys, vals, count in
    guard let ctx = ctx, let serviceID = serviceID else { return }
    let id = String(cString: serviceID)
    let box = UnmanagedBox(ctx)

    var txt: [String: Data] = [:]
    if let keys = keys, let vals = vals {
        for i in 0..<Int(count) {
            guard let k = keys[i], let v = vals[i] else { continue }
            txt[String(cString: k)] = Data(String(cString: v).utf8)
        }
    }
    DispatchQueue.main.async {
        let controller = Unmanaged<PairingController>.fromOpaque(box.value).takeUnretainedValue()
        controller.startAdvertising(serviceID: id, port: Int32(port), txt: txt)
    }
}

private let pairPinCallback: ALPairPinCb = { pin, ctx in
    guard let ctx = ctx, let pin = pin else { return }
    let pinString = String(cString: pin)
    let box = UnmanagedBox(ctx)
    DispatchQueue.main.async {
        let controller = Unmanaged<PairingController>.fromOpaque(box.value).takeUnretainedValue()
        controller.presentPin(pinString)
    }
}

private func cStr(_ ptr: UnsafeMutablePointer<CChar>?) -> String {
    guard let ptr = ptr else { return "" }
    return String(cString: ptr)
}

final class UnmanagedBox: @unchecked Sendable {
    let value: UnsafeMutableRawPointer
    init(_ value: UnsafeMutableRawPointer) { self.value = value }
}
