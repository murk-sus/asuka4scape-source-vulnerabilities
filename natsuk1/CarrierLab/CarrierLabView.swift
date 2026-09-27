ftUI

rierLabView: View {
Object private var clState = CarrierLabState.shared
 private var logText: String = ""
 private var busy: Bool = false
 private var showInstall = false
 private var confirmText = ""
 private var carrierSource: String = ""

dy: some View {
st {
  Section {
      HStack {
          Text("Status")
          Spacer()
          Text(statusText)
              .font(.system(.body, design: .monospaced))
              .foregroundStyle(statusColor)
      }
      if let s = clState.session {
          HStack {
              Text("Started")
              Spacer()
              Text(s.startedAt.formatted()).font(.caption).foregroundStyle(.secondary)
          }
          if let e = s.lastError {
              Text(e).font(.caption).foregroundStyle(.red)
          }
      }
  } header: { Label("CarrierLab", systemImage: "antenna.radiowaves.left.and.right") }

  Section {
      TextField("Source .bundle path", text: $carrierSource)
          .font(.system(.footnote, design: .monospaced))
          .autocorrectionDisabled()
          .textInputAutocapitalization(.never)
  } header: { Label("Source", systemImage: "folder") }

  Section {
      Button { runCheck() } label: { Text("Check") }.disabled(busy)
      Button { showInstall = true } label: { Text("Install") }.disabled(busy)
      Button { runReload() } label: { Text("Reload") }.disabled(busy)
      Button { runFinish() } label: { Text("Finish") }.disabled(busy)
  } header: { Label("Actions", systemImage: "wrench") }

  Section {
      ScrollView {
          Text(logText.isEmpty ? "no output" : logText)
              .font(.system(size: 10, design: .monospaced))
              .frame(maxWidth: .infinity, alignment: .leading)
      }
      .frame(minHeight: 200, maxHeight: 400)
  } header: { Label("Log", systemImage: "terminal") }

istStyle(.insetGrouped)
avigationTitle("CarrierLab")
avigationBarTitleDisplayMode(.inline)
lert("Confirm install", isPresented: $showInstall) {
  TextField("Type INSTALL", text: $confirmText)
  Button("Cancel", role: .cancel) { confirmText = "" }
  Button("Install", role: .destructive) {
      if confirmText == "INSTALL" { runInstall() }
      confirmText = ""
  }
message: {
  Text("Modifies operator files. No guaranteed rollback.")



e var statusText: String {
State.session?.status.rawValue ?? "clean"


e var statusColor: Color {
itch clState.session?.status {
se .placed, .finished: return .green
se .placing: return .orange
se .failed: return .red
fault: return .secondary



e func append(_ s: String) { logText += s + "\n" }

e func runCheck() {
sy = true
 {
  let r = try CarrierLabInstaller.shared.check()
  append("[check] carrierRoot=\(r.carrierRootExists) bundleLinks=\(r.bundleLinksExists) backup=\(r.backupPresent) status=\(r.status.rawValue)")
  append("[check] links=\(r.currentLinks.joined(separator: ", "))")
catch {
  append("[check] error: \(error.localizedDescription)")

sy = false


e func runInstall() {
sy = true
t src = carrierSource.isEmpty ? Bundle.main.bundlePath + "/CarrierLab.bundle" : carrierSource
t ipcc = Bundle.main.bundlePath + "/ipcc"
 {
  try CarrierLabInstaller.shared.install(sourceBundlePath: src, ipccPath: ipcc)
  append("[install] ok")
catch {
  append("[install] error: \(error.localizedDescription)")

sy = false


e func runReload() {
sy = true
 {
  try CarrierLabInstaller.shared.reload(ipccPath: Bundle.main.bundlePath + "/ipcc")
  append("[reload] ok")
catch {
  append("[reload] error: \(error.localizedDescription)")

sy = false


e func runFinish() {
sy = true
 {
  try CarrierLabInstaller.shared.finish()
  append("[finish] ok")
catch {
  append("[finish] error: \(error.localizedDescription)")

sy = false


