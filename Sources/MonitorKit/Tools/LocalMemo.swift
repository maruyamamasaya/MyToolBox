import Foundation

public struct LocalMemoNote: Codable, Identifiable, Equatable {
    public var id: String
    public var title: String
    public var content: String
    public var createdAt: String
    public var updatedAt: String
    public init(now: Date = Date()) {
        id = UUID().uuidString; title = ""; content = ""
        createdAt = LocalMemoArchive.timestamp(now); updatedAt = createdAt
    }
    public var displayTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "無題のメモ" : title }
}

public struct LocalMemoSnapshot: Codable, Identifiable {
    public var id: String
    public var createdAt: String
    public var notes: [LocalMemoNote]
    public init(notes: [LocalMemoNote], now: Date = Date()) {
        id = UUID().uuidString; createdAt = LocalMemoArchive.timestamp(now); self.notes = notes
    }
}

public struct LocalMemoArchive: Codable {
    public var version = 1
    public var notes: [LocalMemoNote] = []
    public var history: [LocalMemoSnapshot] = []
    public init() {}
    public static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
    public static func date(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
    public static func validate(_ notes: [LocalMemoNote]) throws {
        guard Set(notes.map(\.id)).count == notes.count,
              notes.allSatisfy({ !$0.id.isEmpty && date($0.createdAt) != nil && date($0.updatedAt) != nil }) else {
            throw MemoError.invalid
        }
    }
    public static func importNotes(_ data: Data) throws -> [LocalMemoNote] {
        guard data.count <= 20 * 1024 * 1024 else { throw MemoError.tooLarge }
        let decoder = JSONDecoder()
        let notes: [LocalMemoNote]
        if let array = try? decoder.decode([LocalMemoNote].self, from: data) { notes = array }
        else { notes = try decoder.decode(Backup.self, from: data).notes }
        try validate(notes); return notes
    }
    public static func backup(_ notes: [LocalMemoNote]) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(Backup(version: 1, exportedAt: timestamp(Date()), notes: notes))
    }
    public mutating func snapshot(now: Date = Date()) {
        history.insert(LocalMemoSnapshot(notes: notes, now: now), at: 0)
        history = Array(history.prefix(5))
    }
    private struct Backup: Codable {
        var version: Int?
        var exportedAt: String?
        var notes: [LocalMemoNote]
    }
    public enum MemoError: LocalizedError {
        case invalid, tooLarge, version
        public var errorDescription: String? {
            switch self {
            case .invalid: return "メモのID・日時・重複を確認してください。"
            case .tooLarge: return "JSONは20 MiB以下を選択してください。"
            case .version: return "対応していない保存形式です。"
            }
        }
    }
}
