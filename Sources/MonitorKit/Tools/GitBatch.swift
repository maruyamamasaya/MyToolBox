import Foundation
import Darwin

public enum GitBatchAction: String, Sendable { case inspect, check, start, finish }
public struct GitRepositoryStatus: Identifiable, Sendable {
    public var id: String { path }
    public let path: String
    public var name: String { URL(fileURLWithPath: path).lastPathComponent }
    public var branch = ""
    public var changes = ""
    public var ahead: Int?
    public var behind: Int?
    public var result = "未確認"
    public var detail = ""
    public var checkedAt = Date()
    public var succeeded = false
}

/// Argument arrays only: paths and commit messages never become shell code.
public actor GitBatchWorker {
    public init() {}
    public func discover(root: String) throws -> [String] {
        let url = URL(fileURLWithPath: root, isDirectory: true)
        return try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            .filter { child in
                let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                return values?.isDirectory == true && values?.isSymbolicLink != true && FileManager.default.fileExists(atPath: child.appendingPathComponent(".git").path)
            }.map(\.path).sorted()
    }
    public func run(paths: [String], action: GitBatchAction, message: String) -> [GitRepositoryStatus] {
        paths.map { process(path: $0, action: action, message: message) }
    }
    private func process(path: String, action: GitBatchAction, message: String) -> GitRepositoryStatus {
        var row = GitRepositoryStatus(path: path)
        func git(_ args: [String]) throws -> String { try GitBatchCommand.run(path: path, arguments: args) }
        func fetch() throws { _ = try git(["fetch", "--quiet", "--prune", "origin", "+refs/heads/*:refs/remotes/origin/*"]) }
        do {
            row.branch = try git(["symbolic-ref", "--quiet", "--short", "HEAD"]).trimmingCharacters(in: .newlines)
            guard !row.branch.isEmpty else { throw GitBatchError("ブランチを確認できません") }
            _ = try git(["rev-parse", "--verify", "HEAD"])
            _ = try git(["remote", "get-url", "origin"])
            for state in ["MERGE_HEAD", "CHERRY_PICK_HEAD", "REVERT_HEAD", "rebase-merge", "rebase-apply"] {
                let statePath = try git(["rev-parse", "--git-path", state]).trimmingCharacters(in: .newlines)
                let stateURL = URL(fileURLWithPath: statePath, relativeTo: URL(fileURLWithPath: path + "/"))
                if FileManager.default.fileExists(atPath: stateURL.path) { throw GitBatchError("Git操作が進行中です。手動で完了してください") }
            }
            if action != .inspect { try fetch() }
            let remote = "refs/remotes/origin/" + row.branch
            _ = try git(["rev-parse", "--verify", remote])
            func refresh() throws {
                row.changes = try git(["status", "--short", "--untracked-files=all"])
                let counts = try git(["rev-list", "--left-right", "--count", "HEAD..." + remote]).split(whereSeparator: { $0.isWhitespace }).compactMap { Int($0) }
                guard counts.count == 2 else { throw GitBatchError("履歴の差分を確認できません") }
                row.ahead = counts[0]; row.behind = counts[1]
            }
            try refresh()
            if action == .start {
                guard row.changes.isEmpty && row.ahead == 0 else { throw GitBatchError("未コミット変更または未送信コミットがあるため更新しません") }
                if (row.behind ?? 0) > 0 { _ = try git(["merge", "--ff-only", remote]) }
            } else if action == .finish {
                guard row.behind == 0 else { throw GitBatchError("リモートが先行・分岐しています。作業開始または手動解決が必要です") }
                guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw GitBatchError("コミットメッセージを入力してください") }
                if !row.changes.isEmpty {
                    _ = try git(["add", "-A"])
                    // A failed commit keeps the index and local work intact.
                    _ = try git(["commit", "-m", message])
                }
                try fetch()
                _ = try git(["merge-base", "--is-ancestor", remote, "HEAD"])
                let head = try git(["rev-parse", "HEAD"])
                let remoteHead = try git(["rev-parse", remote])
                if head != remoteHead { _ = try git(["-c", "push.followTags=false", "push", "origin", "HEAD:refs/heads/" + row.branch]) }
            }
            if action == .start || action == .finish { try fetch(); try refresh() }
            let synced = row.changes.isEmpty && row.ahead == 0 && row.behind == 0
            row.succeeded = synced
            row.result = synced ? (action == .inspect ? "ローカル参照と一致" : "同期済み") : "差分あり"
            row.detail = action == .inspect ? "通信なし。リモート参照は最後の取得時点です。" : "リモート取得後の状態です。"
        } catch {
            row.result = "停止・要確認"; row.detail = error.localizedDescription
            // Never retain stale counts after a partial operation or failed fetch.
            row.ahead = nil; row.behind = nil
        }
        row.checkedAt = Date()
        return row
    }
}
struct GitBatchError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
enum GitBatchCommand {
    static func run(path: String, arguments: [String], timeout: TimeInterval = 120) throws -> String {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("output")
        FileManager.default.createFile(atPath: file.path, contents: nil, attributes: [.posixPermissions: 0o600])
        let handle = try FileHandle(forWritingTo: file)
        defer { try? handle.close() }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["--no-pager", "-C", path] + arguments
        var env = ProcessInfo.processInfo.environment
        // Do not allow inherited Git routing variables to target a different repository.
        for key in env.keys where key.hasPrefix("GIT_") { env.removeValue(forKey: key) }
        env["GIT_TERMINAL_PROMPT"] = "0"; env["GIT_SSH_COMMAND"] = "/usr/bin/ssh -o BatchMode=yes -o ConnectTimeout=15"
        env["GIT_ASKPASS"] = "/usr/bin/false"; env["SSH_ASKPASS"] = "/usr/bin/false"
        env["LC_ALL"] = "C"; env["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin"
        process.environment = env
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = handle; process.standardError = handle
        try process.run()
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        while process.isRunning && ProcessInfo.processInfo.systemUptime < deadline { Thread.sleep(forTimeInterval: 0.025) }
        if process.isRunning {
            process.terminate()
            Thread.sleep(forTimeInterval: 0.1)
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            process.waitUntilExit()
            throw GitBatchError("処理がタイムアウトしました。反映済みの操作があり得るため、再実行前に状態を確認してください")
        }
        process.waitUntilExit()
        let reader = try FileHandle(forReadingFrom: file); defer { try? reader.close() }
        let data = try reader.read(upToCount: 1_048_577) ?? Data()
        guard data.count <= 1_048_576 else { throw GitBatchError("出力が1MiBを超えたため表示を中止しました") }
        let output = String(decoding: data, as: UTF8.self)
        guard process.terminationStatus == 0 else { throw GitBatchError(output.isEmpty ? "Gitを実行できません（終了コード \(process.terminationStatus)）" : output) }
        return output
    }
}
