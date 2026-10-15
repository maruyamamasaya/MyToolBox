import Foundation

public struct LogPreferences: Codable, Equatable, Sendable {
    public var enabled = false
    public var interval: Double = 10
    public var retentionDays = 7
    public init() {}
    public static func load(from defaults: UserDefaults = .standard) -> Self {
        guard let data = defaults.data(forKey: "monitor.logging.v1"), var p = try? JSONDecoder().decode(Self.self, from: data) else { return Self() }
        if ![1.0, 10, 60].contains(p.interval) { p.interval = 10 }
        if ![1, 7, 30].contains(p.retentionDays) { p.retentionDays = 7 }
        return p
    }
    public func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: "monitor.logging.v1") }
    }
}

/// Serial local writer. Records observations, not averages; no extra OS sampling.
public actor MonitoringLog {
    public static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MyToolBox/Logs", isDirectory: true)
    }
    private let directory: URL
    private let session = UUID().uuidString
    private var last: Double?
    private var lastCleanup: Date?
    public init(directory: URL = MonitoringLog.directory) { self.directory = directory }
    public func reset() { last = nil }
    public struct Record: Codable {
        public var schema = 1
        public var session: String
        public var snapshot: Snapshot
    }
    public static func summary(_ snapshot: Snapshot) -> Snapshot {
        let fields: [String: Set<String>] = [
            "cpu": ["使用率", "Pコア使用率", "Eコア使用率"],
            "gpu": ["使用率"],
            "memory": ["総容量", "使用容量（推定）", "利用可能容量（推定）", "使用率", "プレッシャー", "スワップ使用"],
            "storage": ["総容量", "空き容量", "使用率", "読込速度", "書込速度"],
            "network": ["受信速度", "送信速度", "累積受信", "累積送信"],
            "battery": ["残量", "充電中", "電源接続"],
            "sensors": ["CPU温度", "GPU温度", "CPU Pコア温度", "CPU Eコア温度", "ファン1回転数", "ファン2回転数"]
        ]
        var result = snapshot
        result.readings = snapshot.readings.compactMap { reading in
            guard let names = fields[reading.id] else { return nil }
            let metrics = Dictionary(uniqueKeysWithValues: names.map { ($0, reading.metrics[$0] ?? Metric(.unavailable, "監視モジュールから値が提供されていません")) })
            let notes = reading.id == "network" ? reading.notes.filter { $0.hasPrefix("選択:") } : []
            return Reading(reading.id, reading.title, metrics, notes: notes)
        }
        return result
    }
    /// Returns true only after one JSONL observation was successfully appended.
    public func append(_ snapshot: Snapshot, preferences: LogPreferences) throws -> Bool {
        guard preferences.enabled else { last = nil; return false }
        guard snapshot.uptime.isFinite else { return false }
        if let last, snapshot.uptime >= last, snapshot.uptime - last < max(1, preferences.interval) { return false }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0); formatter.dateFormat = "yyyy-MM-dd"
        let name = "monitor-" + formatter.string(from: snapshot.date) + ".jsonl"
        let file = directory.appendingPathComponent(name)
        if !FileManager.default.fileExists(atPath: file.path) {
            guard FileManager.default.createFile(atPath: file.path, contents: nil, attributes: [.posixPermissions: 0o600]) else {
                throw CocoaError(.fileWriteUnknown)
            }
        }
        let values = try file.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else { throw CocoaError(.fileWriteNoPermission) }
        // Bound disk usage even with a fast interval; stop visibly rather than silently truncate.
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.sortedKeys]
        var data = try encoder.encode(Record(session: session, snapshot: Self.summary(snapshot)))
        data.append(0x0A)
        guard (values.fileSize ?? 0) + data.count <= 32 * 1024 * 1024 else { throw CocoaError(.fileWriteOutOfSpace) }
        let handle = try FileHandle(forWritingTo: file); defer { try? handle.close() }
        try handle.seekToEnd(); try handle.write(contentsOf: data)
        last = snapshot.uptime
        if lastCleanup == nil || abs(snapshot.date.timeIntervalSince(lastCleanup!)) >= 3600 {
            try prune(at: snapshot.date, days: preferences.retentionDays, formatter: formatter)
            lastCleanup = snapshot.date
        }
        return true
    }
    private func prune(at date: Date, days: Int, formatter: DateFormatter) throws {
        let cutoff = date.addingTimeInterval(-Double(max(1, min(30, days))) * 86400)
        for file in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey]) {
            let name = file.lastPathComponent
            guard name.hasPrefix("monitor-"), name.hasSuffix(".jsonl"), name.count == 24,
                  let day = formatter.date(from: String(name.dropFirst(8).dropLast(6))),
                  day.addingTimeInterval(86400) <= cutoff else { continue }
            let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else { continue }
            try FileManager.default.removeItem(at: file)
        }
    }
}
