import SwiftUI

/// Actual GitBatchModel against temporary local repositories only.
@main struct VerifyGitSelection {
 @MainActor static func main() async throws {
  NSApplication.shared.setActivationPolicy(.prohibited)
  let folder = FileManager.default.temporaryDirectory.appendingPathComponent("GitSelection-" + UUID().uuidString).resolvingSymlinksInPath()
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: folder) }
  let suite = "test.git.selection.\(UUID().uuidString)", defaults: UserDefaults
  defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let repos = folder.appendingPathComponent("repos"), hooks = folder.appendingPathComponent("no-hooks")
  try FileManager.default.createDirectory(at: repos, withIntermediateDirectories: true)
  try FileManager.default.createDirectory(at: hooks, withIntermediateDirectories: true)
  func git(_ path: URL, _ args: [String]) throws -> String {
   try GitBatchCommand.run(path: path.path, arguments: ["-c", "core.hooksPath=" + hooks.path, "-c", "init.templateDir=", "-c", "commit.gpgsign=false", "-c", "user.name=Test", "-c", "user.email=test@example.invalid"] + args)
  }
  func wait(_ model: GitBatchModel) async throws {
   let deadline = Date().addingTimeInterval(30)
   while model.busy { guard Date() < deadline else { fatalError("timeout") }; try await Task.sleep(for: .milliseconds(20)) }
  }
  let origin = folder.appendingPathComponent("origin.git"), peer = folder.appendingPathComponent("peer")
  _ = try git(folder, ["init", "--bare", "--initial-branch=main", origin.path])
  _ = try git(folder, ["clone", origin.path, peer.path])
  try "initial".write(to: peer.appendingPathComponent("sample.txt"), atomically: true, encoding: .utf8)
  _ = try git(peer, ["add", "."]); _ = try git(peer, ["commit", "-m", "initial"]); _ = try git(peer, ["push", "origin", "main"])
  let first = repos.appendingPathComponent("checked"), second = repos.appendingPathComponent("unchecked")
  for url in [first, second] { _ = try git(folder, ["clone", origin.path, url.path]) }
  let oldHead = try git(second, ["rev-parse", "HEAD"])
  try "updated".write(to: peer.appendingPathComponent("sample.txt"), atomically: true, encoding: .utf8)
  _ = try git(peer, ["commit", "-am", "remote update"]); _ = try git(peer, ["push", "origin", "main"])
  let model = GitBatchModel(defaults: defaults); model.root = repos.path
  model.load(); try await wait(model)
  precondition(model.rows.count == 2 && model.selected.isEmpty)
  var confirmations = 0
  model.run(.start, decide: { confirmations += 1; return true })
  precondition(!model.busy && confirmations == 0)
  let firstPath = model.rows.first { $0.name == "checked" }!.path
  let secondPath = model.rows.first { $0.name == "unchecked" }!.path
  model.selected = [firstPath]
  let uncheckedRow = model.rows.first { $0.path == secondPath }!
  model.run(.start, decide: { confirmations += 1; return true }); try await wait(model)
  let firstHead = try git(first, ["rev-parse", "HEAD"]), secondHead = try git(second, ["rev-parse", "HEAD"])
  precondition(firstHead != oldHead && secondHead == oldHead && confirmations == 1)
  precondition(!FileManager.default.fileExists(atPath: second.appendingPathComponent(".git/FETCH_HEAD").path))
  precondition(model.rows.first { $0.path == secondPath }!.checkedAt == uncheckedRow.checkedAt)
  model.load(); try await wait(model); precondition(model.selected == [firstPath])
  model.selected = []; model.load(); try await wait(model); precondition(model.selected.isEmpty)
  print("PASS initial opt-in, empty-selection no-op, checked-only fetch/ff update, unchecked HEAD/FETCH_HEAD/status preserved, reload preserves selection and deselection")
 }
}
