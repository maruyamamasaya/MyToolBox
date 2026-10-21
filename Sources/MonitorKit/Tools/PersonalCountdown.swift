import Foundation

public struct PersonalCountdown: Codable, Equatable, Identifiable {
    public enum Kind: String, Codable, CaseIterable { case date = "日付まで", hours = "目標時間まで", elapsed = "開始からの時間" }
    public var id = UUID()
    public var title = ""
    public var kind: Kind = .date
    public var date = Date()
    public var targetHours: Double = 10_000
    public var completedHours: Double = 0
    public var hoursPerDay: Double = 2
    public init() {}
    public static func sortedByRemainingDays(_ entries: [Self], now: Date) -> [Self] {
        entries.enumerated().sorted {
            let left = $0.element.remainingDays(now: now)
            let right = $1.element.remainingDays(now: now)
            return left == right ? $0.offset < $1.offset : left < right
        }.map(\.element)
    }
    public func validate() throws {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ToolFailure.message("名前を入力してください") }
        guard date.timeIntervalSince1970.isFinite else { throw ToolFailure.message("有効な日付を指定してください") }
        if kind != .date {
            guard targetHours.isFinite, targetHours > 0, targetHours <= 100_000_000 else { throw ToolFailure.message("目標時間は0より大きく1億以下にしてください") }
            if kind == .hours {
                guard completedHours.isFinite, completedHours >= 0, hoursPerDay.isFinite, hoursPerDay > 0, hoursPerDay <= 24, (max(0, targetHours - completedHours) / hoursPerDay).isFinite, max(0, targetHours - completedHours) / hoursPerDay <= 100_000_000 else { throw ToolFailure.message("累計は0以上、1日の時間は0より大きく24以下にしてください") }
            }
        }
    }
    public func remainingDays(now: Date, calendar: Calendar = BusinessDays.calendar) -> Int {
        let end = targetDate ?? date
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: end)).day ?? 0
    }
    public mutating func updateCompletedHours(_ hours: Double) throws {
        guard kind == .hours else { throw ToolFailure.message("時間目標を選択してください") }
        var updated = self
        updated.completedHours = hours
        try updated.validate()
        self = updated
    }
    public var targetDate: Date? {
        switch kind {
        case .date: return date
        case .elapsed: return BusinessDays.calendar.startOfDay(for: date).addingTimeInterval(targetHours * 3600)
        case .hours:
            guard targetHours.isFinite, completedHours.isFinite, hoursPerDay.isFinite, hoursPerDay > 0, (max(0, targetHours - completedHours) / hoursPerDay).isFinite else { return nil }
            return BusinessDays.calendar.startOfDay(for: date).addingTimeInterval(max(0, targetHours - completedHours) / hoursPerDay * 86_400)
        }
    }
}

public enum PersonalCountdownStore {
    public static let key = "tools.personalCalendar.countdowns.v1"
    public static func load(defaults: UserDefaults = .standard) throws -> [PersonalCountdown] {
        guard let data = defaults.data(forKey: key) else { return [] }
        let entries = try JSONDecoder().decode([PersonalCountdown].self, from: data)
        for entry in entries { try entry.validate() }
        guard Set(entries.map(\.id)).count == entries.count else { throw ToolFailure.message("保存データのIDが重複しています") }
        return entries
    }
    public static func save(_ entries: [PersonalCountdown], defaults: UserDefaults = .standard) throws {
        for entry in entries { try entry.validate() }
        defaults.set(try JSONEncoder().encode(entries), forKey: key)
    }
}
