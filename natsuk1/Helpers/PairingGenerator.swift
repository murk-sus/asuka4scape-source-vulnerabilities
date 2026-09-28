import Foundation

struct PairingError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

final class PairingGenerator {
    static let shared = PairingGenerator()
    private init() {}

    private let hostName = "natsuk1"

    @discardableResult
    func generateMergedPairing(rppPath: String, outputPath: String) throws -> String {
        LockdownPair.resetCancel()

        guard let rpp = try? Data(contentsOf: URL(fileURLWithPath: rppPath)), !rpp.isEmpty else {
            throw PairingError(message: "pairing record missing at \(rppPath)")
        }
        let kind = PairingFileKind.of(data: rpp)
        guard kind.hasRemotePairing else {
            throw PairingError(message: "not an RPPairing record, pair again from Airlift")
        }
        if kind.hasLockdown {
            return try write(rpp, outputPath: outputPath, sourcePath: rppPath)
        }

        var lockdown = CompositePairingFile.cachedLockdownRecord(forUDID: kind.udid)
        if lockdown == nil {
            PairingController.shared.pairingStatus = "Minting lockdown record..."
            do {
                let record = try LockdownPair.mintRecord(
                    hosts: LockdownPair.candidateHosts(),
                    hostID: CompositePairingFile.hostID,
                    systemBUID: CompositePairingFile.systemBUID,
                    hostName: hostName)
                CompositePairingFile.storeLockdownRecord(record, forUDID: kind.udid)
                lockdown = record
            } catch {
                if LockdownPair.cancelled { throw PairingError(message: "cancelled") }
                throw PairingError(message: (error as? LocalizedError)?.errorDescription
                                   ?? String(describing: error))
            }
        }
        guard let lockdown else {
            throw PairingError(message: "lockdown record unavailable")
        }

        let merged = try CompositePairingFile.merge(lockdown: lockdown, rpPairing: rpp, udid: kind.udid)
        let canonical = try write(merged, outputPath: outputPath, sourcePath: rppPath)
        PairingController.shared.pairingStatus = "Pairing file ready"
        return canonical
    }

    private func write(_ data: Data, outputPath: String, sourcePath: String) throws -> String {
        if outputPath != sourcePath {
            try? data.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
        }
        let canonical = PairingController.syncCanonicalPairingFile(from: sourcePath)
        do {
            try data.write(to: URL(fileURLWithPath: canonical), options: .atomic)
        } catch {
            throw PairingError(message: error.localizedDescription)
        }
        return canonical
    }
}
