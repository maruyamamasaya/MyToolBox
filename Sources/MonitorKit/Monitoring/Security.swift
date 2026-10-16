import Foundation
import Darwin

public enum SecurityState: String, Sendable {
    case enabled = "有効", disabled = "無効", unavailable = "確認できない", checking = "確認中"
    case encrypting = "暗号化中", decrypting = "復号中"
    public var symbol: String {
        switch self {
        case .enabled: return "checkmark.shield.fill"
        case .disabled: return "shield.slash"
        case .unavailable: return "questionmark.diamond"
        case .checking: return "hourglass"
        case .encrypting, .decrypting: return "arrow.triangle.2.circlepath"
        }
    }
}

public enum SecurityItem: String, CaseIterable, Sendable, Identifiable {
    case firewall, fileVault, gatekeeper
    public var id: String { rawValue }
    public var title: String {
        switch self { case .firewall: return "ファイアウォール"; case .fileVault: return "FileVault"; case .gatekeeper: return "Gatekeeper" }
    }
    public var explanation: String {
        switch self {
        case .firewall: return "アプリへの不要な着信接続を制限します。"
        case .fileVault: return "起動ディスクのデータをログイン認証で保護します。内蔵ストレージ自体の暗号化とは異なります。"
        case .gatekeeper: return "ダウンロードしたアプリの署名・公証などを確認します。個別アプリの安全性の判定ではありません。"
        }
    }
    var command: (String, [String]) {
        switch self {
        case .firewall: return ("/usr/libexec/ApplicationFirewall/socketfilterfw", ["--getglobalstate"])
        case .fileVault: return ("/usr/bin/fdesetup", ["status"])
        case .gatekeeper: return ("/usr/sbin/spctl", ["--status"])
        }
    }
}

public struct SecurityReading: Sendable {
    public let item: SecurityItem
    public let state: SecurityState
    public let reason: String
    public let checkedAt: Date?
    public init(item: SecurityItem, state: SecurityState = .checking, reason: String = "", checkedAt: Date? = nil) {
        self.item = item; self.state = state; self.reason = reason; self.checkedAt = checkedAt
    }
}

struct SecurityCommandResult: Sendable {
    var output = ""
    var error = ""
    var code: Int32 = 0
    var failure: String? = nil
}

// Runs only on the dedicated collector actor. Files avoid pipe-buffer deadlocks.
// Each command has bounded runtime and captures stdout/stderr independently.
enum SecurityCommand {
    static func run(path: String, arguments: [String], timeout: TimeInterval = 5) -> SecurityCommandResult {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
            defer { try? FileManager.default.removeItem(at: directory) }
            let out = directory.appendingPathComponent("out"), err = directory.appendingPathComponent("err")
            FileManager.default.createFile(atPath: out.path, contents: nil, attributes: [.posixPermissions: 0o600])
            FileManager.default.createFile(atPath: err.path, contents: nil, attributes: [.posixPermissions: 0o600])
            let stdout = try FileHandle(forWritingTo: out), stderr = try FileHandle(forWritingTo: err)
            defer { try? stdout.close(); try? stderr.close() }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path); process.arguments = arguments
            process.environment = ["LC_ALL": "C", "LANG": "C", "PATH": "/usr/bin:/usr/sbin:/bin:/sbin"]
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = stdout; process.standardError = stderr
            try process.run()
            let deadline = ProcessInfo.processInfo.systemUptime + timeout
            while process.isRunning && ProcessInfo.processInfo.systemUptime < deadline { Thread.sleep(forTimeInterval: 0.02) }
            if process.isRunning {
                // SIGKILL is limited to our own timed-out read-only subprocess.
                kill(process.processIdentifier, SIGKILL)
                return SecurityCommandResult(failure: "タイムアウト（\(timeout)秒）")
            }
            func read(_ url: URL) -> String {
                guard let handle = try? FileHandle(forReadingFrom: url) else { return "" }
                defer { try? handle.close() }
                return String(decoding: (try? handle.read(upToCount: 16_384)) ?? Data(), as: UTF8.self)
            }
            return SecurityCommandResult(output: read(out), error: read(err), code: process.terminationStatus)
        } catch {
            return SecurityCommandResult(failure: "実行できません（未対応・実行権限・一時領域を確認）：\(error.localizedDescription)")
        }
    }
}

public actor SecurityCollector {
    public init() {}
    public func read() -> [SecurityReading] {
        SecurityItem.allCases.map { item in
            let (path, arguments) = item.command
            return Self.parse(item, result: SecurityCommand.run(path: path, arguments: arguments))
        }
    }
    static func parse(_ item: SecurityItem, result: SecurityCommandResult) -> SecurityReading {
        func reading(_ state: SecurityState, _ reason: String = "") -> SecurityReading {
            SecurityReading(item: item, state: state, reason: reason, checkedAt: Date())
        }
        if let failure = result.failure { return reading(.unavailable, failure) }
        let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        let diagnostic = (result.error + "\n" + output).trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = diagnostic.lowercased()
        if ["permission denied", "operation not permitted", "requires root", "must be root", "must run as root", "not authorized"].contains(where: lower.contains) {
            return reading(.unavailable, "通常権限では取得できません。管理者権限は要求しません。")
        }
        // A nonzero status never becomes an enabled result, even if stdout says On.
        if item == .fileVault && [0, 1, 2].contains(result.code) && result.error.isEmpty {
            let lines = output.components(separatedBy: .newlines)
            if lines.contains(where: { $0.hasPrefix("Encryption in progress") }) { return reading(.encrypting, output) }
            if lines.contains(where: { $0.hasPrefix("Decryption in progress") }) { return reading(.decrypting, output) }
            if output == "FileVault is Off.", [0, 1].contains(result.code) { return reading(.disabled) }
        }
        guard result.code == 0, result.error.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return reading(.unavailable, "取得失敗（終了コード \(result.code)）：\(diagnostic.isEmpty ? "詳細なし" : String(diagnostic.prefix(400)))")
        }
        switch (item, output) {
        case (.firewall, "Firewall is enabled. (State = 1)"), (.firewall, "Firewall is enabled. (State = 2)"), (.fileVault, "FileVault is On."), (.gatekeeper, "assessments enabled"): return reading(.enabled)
        case (.firewall, "Firewall is disabled. (State = 0)"), (.gatekeeper, "assessments disabled"): return reading(.disabled)
        default: return reading(.unavailable, "未対応または想定外の応答：\(String(output.prefix(400)))")
        }
    }
}
