ndation

s CarrierLabBridge: @unchecked Sendable {
 let shared = CarrierLabBridge()

arrierError: LocalizedError {
se noPairing
se notImplemented(String)
se remote(String)

r errorDescription: String? {
  switch self {
  case .noPairing: return "No pairing file. Pair via Airlift first."
  case .notImplemented(let s): return "Not implemented: " + s
  case .remote(let s): return s
  }



e let carrierRoot = "/var/mobile/Library/Carrier Bundles"
e let bundleLinks = "/var/mobile/Library/Carrier Bundles/BundleLinks"

arrierRootPath() -> String { carrierRoot }
undleLinksPath() -> String { bundleLinks }

riteFile(source: String, target: String) throws {
t pairing = PairingController.pairingFilePath()
ard FileManager.default.fileExists(atPath: pairing) else { throw CarrierError.noPairing }
r outJson: UnsafeMutablePointer<CChar>? = nil
r outErr: UnsafeMutablePointer<CChar>? = nil
t rc: Int32 = pairing.withCString { pc in
  source.withCString { sc in
      target.withCString { tc in
          al_exploit_run(pc, tc, nil, nil, &outJson, &outErr)
      }
  }

 let p = outJson { al_string_free(p) }
t errMsg = outErr.flatMap { String(cString: $0) } ?? ""
 let p = outErr { al_string_free(p) }
 rc != 0 { throw CarrierError.remote(errMsg.isEmpty ? "rc=\(rc)" : errMsg) }


eadFile(path: String) throws -> Data {
row CarrierError.notImplemented("al_read_file")


emovePath(_ path: String) throws {
row CarrierError.notImplemented("al_remove_path")


ymlink(link: String, target: String) throws {
row CarrierError.notImplemented("al_make_symlink")


