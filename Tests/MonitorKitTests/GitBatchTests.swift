import XCTest
@testable import MonitorKit

final class GitBatchTests: XCTestCase {
    func testLocalRemoteLifecycleAndBlocking() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        func command(_ path: URL, _ args: [String]) throws -> String { try GitBatchCommand.run(path: path.path, arguments: args) }
        let bare = root.appendingPathComponent("origin.git"), repos = root.appendingPathComponent("repos"), local = repos.appendingPathComponent("space 日本語 repo"), other = root.appendingPathComponent("other")
        try FileManager.default.createDirectory(at: repos, withIntermediateDirectories: true)
        _ = try command(root, ["init", "--bare", "--initial-branch=main", bare.path])
        _ = try command(root, ["clone", bare.path, local.path])
        for repo in [local] {
            _ = try command(repo, ["config", "user.email", "test@example.invalid"])
            _ = try command(repo, ["config", "user.name", "Local Test"])
            _ = try command(repo, ["config", "commit.gpgsign", "false"])
        }
        let file = local.appendingPathComponent("hello.txt")
        try "first".write(to: file, atomically: true, encoding: .utf8)
        _ = try command(local, ["add", "-A"]); _ = try command(local, ["commit", "-m", "initial"])
        _ = try command(local, ["push", "origin", "main"])
        _ = try command(root, ["clone", bare.path, other.path])
        _ = try command(other, ["config", "user.email", "test@example.invalid"])
        _ = try command(other, ["config", "user.name", "Local Test"])
        _ = try command(other, ["config", "commit.gpgsign", "false"])
        let worker = GitBatchWorker()
        let discovered = try await worker.discover(root: repos.path)
        XCTAssertEqual(discovered.count, 1)
        XCTAssertEqual(URL(fileURLWithPath: discovered[0]).lastPathComponent, local.lastPathComponent)
        var rows = await worker.run(paths: discovered, action: .check, message: "")
        XCTAssertTrue(rows[0].succeeded)
        try "dirty".write(to: file, atomically: true, encoding: .utf8)
        rows = await worker.run(paths: discovered, action: .start, message: "")
        XCTAssertFalse(rows[0].succeeded); XCTAssertTrue(rows[0].detail.contains("未コミット"))
        // Shell syntax stays literal in a commit message.
        let message = "literal $(touch should-not-exist) `echo test`"
        rows = await worker.run(paths: discovered, action: .finish, message: message)
        XCTAssertTrue(rows[0].succeeded, rows[0].detail)
        XCTAssertEqual(try command(local, ["log", "-1", "--format=%s"]).trimmingCharacters(in: .newlines), message)
        XCTAssertFalse(FileManager.default.fileExists(atPath: local.appendingPathComponent("should-not-exist").path))
        _ = try command(other, ["pull", "--ff-only"])
        try "remote".write(to: other.appendingPathComponent("hello.txt"), atomically: true, encoding: .utf8)
        _ = try command(other, ["commit", "-am", "remote update"]); _ = try command(other, ["push", "origin", "main"])
        rows = await worker.run(paths: discovered, action: .finish, message: "must block")
        XCTAssertFalse(rows[0].succeeded); XCTAssertTrue(rows[0].detail.contains("先行"))
        rows = await worker.run(paths: discovered, action: .start, message: "")
        XCTAssertTrue(rows[0].succeeded, rows[0].detail)
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "remote")
        _ = try command(local, ["checkout", "--detach"])
        rows = await worker.run(paths: discovered, action: .check, message: "")
        XCTAssertFalse(rows[0].succeeded); XCTAssertNil(rows[0].ahead)
    }
    func testEmptyRepositoryAndCommandFailures() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try GitBatchCommand.run(path: root.path, arguments: ["init", "--initial-branch=main"])
        let worker = GitBatchWorker()
        let rows = await worker.run(paths: [root.path], action: .inspect, message: "")
        XCTAssertFalse(rows[0].succeeded); XCTAssertNil(rows[0].behind)
        XCTAssertThrowsError(try GitBatchCommand.run(path: root.path, arguments: ["not-a-real-command"]))
        XCTAssertThrowsError(try GitBatchCommand.run(path: root.path, arguments: ["status"], timeout: -1))
    }
}
