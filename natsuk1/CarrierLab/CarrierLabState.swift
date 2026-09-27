ndation
bine

s CarrierLabState: ObservableObject, @unchecked Sendable {
 let shared = CarrierLabState()

tatus: String, Codable { case clean, placing, placed, finished, failed }

 Session: Codable {
r status: Status
r startedAt: Date
r carrierBundlePath: String?
r originalBackupPath: String?
r ipccTriggerPath: String?
r lastError: String?


shed private(set) var session: Session?

e let root: URL
e let stateURL: URL
e let backupDir: URL

e init() {
t docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
ot = docs.appendingPathComponent("carrierlab", isDirectory: true)
ateURL = root.appendingPathComponent("state.json")
ckupDir = root.appendingPathComponent("backup", isDirectory: true)
y? FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
ad()


oad() {
ard let data = try? Data(contentsOf: stateURL),
    let s = try? JSONDecoder().decode(Session.self, from: data) else {
  session = nil
  return

ssion = s


ave(_ s: Session) {
ssion = s
t enc = JSONEncoder()
c.outputFormatting = [.prettyPrinted, .sortedKeys]
c.dateEncodingStrategy = .iso8601
 let d = try? enc.encode(s) { try? d.write(to: stateURL, options: .atomic) }


lear() {
ssion = nil
y? FileManager.default.removeItem(at: stateURL)


asBackup() -> Bool {
ard let s = session, let p = s.originalBackupPath else { return false }
turn FileManager.default.fileExists(atPath: p)


ackupURL() -> URL { backupDir }
ootURL() -> URL { root }

