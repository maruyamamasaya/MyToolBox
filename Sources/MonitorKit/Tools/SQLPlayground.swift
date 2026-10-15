import Foundation
import SQLite3

public struct SQLResult: Sendable {
    public let columns: [String]
    public let rows: [[String?]]
    public let changes: Int
    public let truncated: Bool
}

/// Owned by one worker actor (or a single synchronous test). Never opens a file database.
public final class SQLMemoryDatabase {
    private var database: OpaquePointer?
    private final class Budget {
        let deadline: TimeInterval
        var ticks = 0
        init(seconds: TimeInterval) { deadline = ProcessInfo.processInfo.systemUptime + max(0, seconds) }
    }
    public static let sampleQuery = "SELECT department, COUNT(*) AS people, ROUND(AVG(salary), 0) AS average_salary\nFROM employees\nWHERE active = 1\nGROUP BY department\nORDER BY average_salary DESC;"
    private static let seed = """
    CREATE TABLE employees (id INTEGER PRIMARY KEY, name TEXT, department TEXT, salary INTEGER, active INTEGER);
    INSERT INTO employees VALUES
      (1, '田中', '開発', 520000, 1), (2, '佐藤', '開発', 480000, 1),
      (3, '鈴木', '営業', 460000, 1), (4, '高橋', '営業', 430000, 0);
    CREATE TABLE projects (id INTEGER PRIMARY KEY, name TEXT, employee_id INTEGER);
    INSERT INTO projects VALUES (1, 'Webサイト更新', 1), (2, 'マニュアル作成', 3);
    """
    public init() throws {
        var handle: OpaquePointer?
        let code = sqlite3_open_v2(":memory:", &handle, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_NOMUTEX, nil)
        guard code == SQLITE_OK, let handle else {
            if let handle { sqlite3_close(handle) }
            throw SQLToolError.invalid("一時データベースを作成できませんでした。")
        }
        database = handle
        do {
            try control("PRAGMA temp_store=MEMORY; PRAGMA page_size=4096; PRAGMA max_page_count=4096;")
            sqlite3_limit(handle, SQLITE_LIMIT_LENGTH, 1_000_000)
            sqlite3_limit(handle, SQLITE_LIMIT_SQL_LENGTH, 200_000)
            sqlite3_limit(handle, SQLITE_LIMIT_COLUMN, 64)
            sqlite3_limit(handle, SQLITE_LIMIT_EXPR_DEPTH, 100)
            sqlite3_limit(handle, SQLITE_LIMIT_COMPOUND_SELECT, 10)
            sqlite3_limit(handle, SQLITE_LIMIT_TRIGGER_DEPTH, 16)
            try control(Self.seed)
        } catch { sqlite3_close(handle); database = nil; throw error }
    }
    deinit { if let database { sqlite3_close(database) } }
    private func control(_ sql: String) throws {
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else { throw failure() }
    }
    private func failure() -> SQLToolError {
        if sqlite3_errcode(database) == SQLITE_INTERRUPT { return .invalid("実行時間または処理量の上限に達しました。変更を取り消しました。") }
        return .invalid(database.map { String(cString: sqlite3_errmsg($0)) } ?? "データベースが閉じられています。")
    }
    public func schema() throws -> [SQLResult] {
        try execute("SELECT name, sql FROM sqlite_schema WHERE type IN ('table', 'view') AND name NOT LIKE 'sqlite_%' ORDER BY name;")
    }
    /// Each batch succeeds as a unit. Explicit transaction control is intentionally unavailable.
    public func execute(_ sql: String, seconds: TimeInterval = 2) throws -> [SQLResult] {
        guard let database else { throw failure() }
        guard sql.utf8.count <= 200_000, !sql.contains("\0") else { throw SQLToolError.invalid("SQLはNUL文字を含まない200 KB以内にしてください。") }
        try control("SAVEPOINT toolbox_batch")
        let budget = Budget(seconds: seconds)
        sqlite3_progress_handler(database, 1000, { context in
            guard let context else { return 1 }
            let budget = Unmanaged<Budget>.fromOpaque(context).takeUnretainedValue()
            budget.ticks += 1
            return budget.ticks >= 10_000 || ProcessInfo.processInfo.systemUptime >= budget.deadline ? 1 : 0
        }, Unmanaged.passUnretained(budget).toOpaque())
        sqlite3_set_authorizer(database, { _, action, _, second, _, _ in
            switch action {
            case SQLITE_ATTACH, SQLITE_DETACH, SQLITE_PRAGMA, SQLITE_TRANSACTION, SQLITE_SAVEPOINT, SQLITE_CREATE_VTABLE, SQLITE_DROP_VTABLE:
                return SQLITE_DENY
            case SQLITE_FUNCTION:
                let name = second.map { String(cString: $0).lowercased() } ?? ""
                return ["load_extension", "readfile", "writefile"].contains(name) ? SQLITE_DENY : SQLITE_OK
            default: return SQLITE_OK
            }
        }, nil)
        var success = false
        defer {
            sqlite3_set_authorizer(database, nil, nil)
            sqlite3_progress_handler(database, 0, nil, nil)
            withExtendedLifetime(budget) {}
            if !success { try? control("ROLLBACK TO toolbox_batch") }
            try? control("RELEASE toolbox_batch")
        }
        var results: [SQLResult] = [], outputBytes = 0
        try sql.withCString { base in
            var cursor = base
            while cursor.pointee != 0 {
                guard ProcessInfo.processInfo.systemUptime < budget.deadline else { throw SQLToolError.invalid("実行時間の上限（2秒）に達しました。変更を取り消しました。") }
                var statement: OpaquePointer?, tail: UnsafePointer<CChar>?
                let code = sqlite3_prepare_v2(database, cursor, -1, &statement, &tail)
                guard code == SQLITE_OK else { throw failure() }
                guard let next = tail, next > cursor else { if let statement { sqlite3_finalize(statement) }; break }
                cursor = next
                guard let statement else { continue }
                defer { sqlite3_finalize(statement) }
                guard results.count < 20 else { throw SQLToolError.invalid("1回に実行できるSQL文は20個までです。変更を取り消しました。") }
                let count = sqlite3_column_count(statement)
                let columns = (0..<count).map { String(cString: sqlite3_column_name(statement, $0)) }
                var rows: [[String?]] = [], truncated = false
                let before = sqlite3_total_changes(database)
                while true {
                    let step = sqlite3_step(statement)
                    if step == SQLITE_DONE { break }
                    guard step == SQLITE_ROW else { throw failure() }
                    if rows.count >= 500 { truncated = true; continue }
                    var row: [String?] = []
                    for col in 0..<count {
                        if sqlite3_column_type(statement, col) == SQLITE_NULL { row.append(nil) }
                        else if sqlite3_column_type(statement, col) == SQLITE_BLOB {
                            let size = sqlite3_column_bytes(statement, col)
                            row.append("[BLOB \(size) bytes]"); outputBytes += 32
                        } else {
                            let size = Int(sqlite3_column_bytes(statement, col)); outputBytes += size
                            guard outputBytes <= 2_000_000 else { throw SQLToolError.invalid("結果が2 MBを超えました。列や件数を絞り込んでください。変更を取り消しました。") }
                            let value = sqlite3_column_text(statement, col)
                            row.append(value.map { String(decoding: UnsafeBufferPointer(start: $0, count: size), as: UTF8.self) } ?? "")
                        }
                    }
                    rows.append(row)
                }
                results.append(SQLResult(columns: columns, rows: rows, changes: Int(sqlite3_total_changes(database) - before), truncated: truncated))
            }
        }
        guard !results.isEmpty else { throw SQLToolError.invalid("実行するSQLを入力してください。") }
        success = true
        return results
    }
}

public actor SQLPlaygroundWorker {
    private var database: SQLMemoryDatabase?
    public init() {}
    public func execute(_ sql: String) throws -> (results: [SQLResult], schema: [SQLResult]) {
        if database == nil { database = try SQLMemoryDatabase() }
        guard let database else { throw SQLToolError.invalid("データベースを作成できませんでした。") }
        let results = try database.execute(sql)
        return (results, (try? database.schema()) ?? [])
    }
    public func reset() throws -> [SQLResult] {
        database = try SQLMemoryDatabase()
        return try database!.schema()
    }
    public func close() { database = nil }
}
