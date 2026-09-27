import Foundation

final class PairingGenerator {
    static let shared = PairingGenerator()
    private init() {}

    private let hostName = "natsuk1"

    enum GeneratorError: LocalizedError {
        case missingFile(String)
        case notAPlist(String)
        case noRemotePairing
        case cancelled
        case lockdownUnavailable(String)
        case mergeFailed(String)
        case writeFailed(String)

        var errorDescription: String? {
            switch self {
            case let .missingFile(s):
                return "Pairing file missing: \(s)"
            case let .notAPlist(s):
                return "Pairing file is not a plist: \(s)"
            case .noRemotePairing:
                return "The pairing record has no public_key / private_key / identifier, "
                    + "so it is not an RPPairing record. Pair again from the Airlift screen."
            case .cancelled:
                return "Cancelled."
            case let .lockdownUnavailable(reason):
                return "The classic lockdown half was not issued, so the file still lacks "
                    + "DeviceCertificate and Airlift's Lockdown fallback will fail. \(reason)"
            case let .mergeFailed(reason):
                return "The two pairing records could not be merged: \(reason)"
            case let .writeFailed(reason):
                return "Write failed: \(reason)"
            }
        }
    }

    private func status(_ text: String) {
        PairingController.shared.pairingStatus = text
    }

    static func cancelMinting() {
        LockdownPair.requestCancel()
        PairingController.shared.pairingStatus = "Cancelling..."
    }

    @discardableResult
    func generateMergedPairing(rppPath: String, outputPath: String) throws -> String {
        LockdownPair.resetCancel()

        let fm = FileManager.default
        guard fm.fileExists(atPath: rppPath) else {
            throw GeneratorError.missingFile(rppPath)
        }
        guard let rpp = try? Data(contentsOf: URL(fileURLWithPath: rppPath)), !rpp.isEmpty else {
            throw GeneratorError.missingFile("empty or unreadable: \(rppPath)")
        }
        guard let plist = try? PropertyListSerialization.propertyList(
            from: rpp, options: [], format: nil) as? [String: Any], !plist.isEmpty else {
            throw GeneratorError.notAPlist(rppPath)
        }

        let kind = PairingFileKind.of(data: rpp)

        if kind.hasLockdown {
            status("Pairing file already carries a lockdown record.")
            return try write(merged: rpp, outputPath: outputPath, sourcePath: rppPath)
        }
        guard kind.hasRemotePairing else {
            throw GeneratorError.noRemotePairing
        }

        var lockdownRecord = CompositePairingFile.cachedLockdownRecord(forUDID: kind.udid)
        var mintFailure: String?

        if lockdownRecord == nil {
            status("Minting lockdown record...")
            do {
                let record = try LockdownPair.mintRecord(
                    hosts: LockdownPair.candidateHosts(),
                    hostID: CompositePairingFile.hostID,
                    systemBUID: CompositePairingFile.systemBUID,
                    hostName: hostName,
                    progress: { [weak self] text in self?.status(text) })
                CompositePairingFile.storeLockdownRecord(record, forUDID: kind.udid)
                lockdownRecord = record
                status("Lockdown record minted (\(record.count) bytes).")
            } catch {
                if LockdownPair.cancelled {
                    throw GeneratorError.cancelled
                }
                mintFailure = (error as? LocalizedError)?.errorDescription
                    ?? String(describing: error)
            }
        } else {
            status("Reusing the stored lockdown record.")
        }

        let merged: Data
        if let lockdownRecord {
            do {
                merged = try CompositePairingFile.merge(
                    lockdown: lockdownRecord, rpPairing: rpp, udid: kind.udid)
            } catch {
                throw GeneratorError.mergeFailed(
                    (error as? LocalizedError)?.errorDescription ?? String(describing: error))
            }
        } else {
            merged = rpp
        }

        let canonical = try write(merged: merged, outputPath: outputPath, sourcePath: rppPath)

        if let mintFailure {
            throw GeneratorError.lockdownUnavailable(mintFailure)
        }
        return canonical
    }

    private func write(merged: Data, outputPath: String, sourcePath: String) throws -> String {
        if outputPath != sourcePath {
            do {
                try merged.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
            } catch {
                throw GeneratorError.writeFailed(error.localizedDescription)
            }
        }
        let canonical = PairingController.syncCanonicalPairingFile(from: sourcePath)
        do {
            try merged.write(to: URL(fileURLWithPath: canonical), options: .atomic)
        } catch {
            throw GeneratorError.writeFailed(error.localizedDescription)
        }
        return canonical
    }
}
