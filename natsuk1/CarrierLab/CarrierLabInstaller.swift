ndation

s CarrierLabInstaller: @unchecked Sendable {
 let shared = CarrierLabInstaller()

e let state = CarrierLabState.shared
e let bridge = CarrierLabBridge.shared

 CheckResult {
t carrierRootExists: Bool
t bundleLinksExists: Bool
t currentLinks: [String]
t backupPresent: Bool
t status: CarrierLabState.Status


heck() throws -> CheckResult {
t fm = FileManager.default
t root = bridge.carrierRootPath()
t links = bridge.bundleLinksPath()
r entries: [String] = []
 let e = try? fm.contentsOfDirectory(atPath: links) { entries = e }
turn CheckResult(
  carrierRootExists: fm.fileExists(atPath: root),
  bundleLinksExists: fm.fileExists(atPath: links),
  currentLinks: entries,
  backupPresent: state.hasBackup(),
  status: state.session?.status ?? .clean



nstall(sourceBundlePath: String, ipccPath: String) throws {
 state.session != nil && !state.hasBackup() {
  throw NSError(domain: "carrierlab", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Session already placed. Run finish or reload."])

t s = CarrierLabState.Session(
  status: .placing,
  startedAt: Date(),
  carrierBundlePath: sourceBundlePath,
  originalBackupPath: state.backupURL().path,
  ipccTriggerPath: ipccPath,
  lastError: nil)
ate.save(s)

 {
  try bridge.writeFile(source: sourceBundlePath, target: bridge.bundleLinksPath())
  try bridge.writeFile(source: ipccPath, target: bridge.carrierRootPath())
  var done = s
  done.status = .placed
  state.save(done)
catch {
  var bad = s
  bad.status = .failed
  bad.lastError = error.localizedDescription
  state.save(bad)
  throw error



eload(ipccPath: String) throws {
ard let s = state.session, s.status == .placed || s.status == .finished else {
  throw NSError(domain: "carrierlab", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Nothing to reload. Install first."])

y bridge.writeFile(source: ipccPath, target: bridge.carrierRootPath())


inish() throws {
ard let s = state.session else { return }
r done = s
ne.status = .finished
ate.save(done)


