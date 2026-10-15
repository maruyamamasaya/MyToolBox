import Foundation

/// Local date selection and formatting, matching the source Calendar tool's hourly output.
public struct ScheduleCandidates: Equatable {
    public enum Mode: String, CaseIterable { case single = "1日だけ", multiple = "複数の候補日" }
    public struct Hours: Equatable {
        public var start: Int
        public var end: Int
        public init(start: Int = 12, end: Int = 13) { self.start = start; self.end = end }
        public var valid: Bool { (0...23).contains(start) && (0...23).contains(end) && start < end }
        public static func label(_ hour: Int) -> String { String(format: "%02d：00", hour) }
    }
    /// A two-click range chooser: reverse clicks normalize, equal endpoints stay pending.
    public struct HourSelection: Equatable {
        public static let bounds = 9...21
        public private(set) var anchor: Int?
        public init() {}
        public mutating func click(_ hour: Int) -> Hours? {
            guard Self.bounds.contains(hour) else { return nil }
            guard let anchor else { self.anchor = hour; return nil }
            guard anchor != hour else { return nil }
            self.anchor = nil
            return Hours(start: min(anchor, hour), end: max(anchor, hour))
        }
        public mutating func cancel() { anchor = nil }
    }
    public var mode: Mode = .single {
        didSet {
            if mode == .single, let first = dates.first { selected = [first] }
        }
    }
    public var defaults = Hours()
    public private(set) var selected: Set<Date> = []
    private var hours: [Date: Hours] = [:]
    public init() {}
    public var dates: [Date] { selected.sorted() }
    public mutating func choose(_ date: Date) {
        let day = BusinessDays.calendar.startOfDay(for: date)
        if mode == .single { selected = [day] }
        else if selected.contains(day) { selected.remove(day); return }
        else { selected.insert(day) }
        if hours[day] == nil { hours[day] = defaults }
    }
    public func time(for date: Date) -> Hours { hours[BusinessDays.calendar.startOfDay(for: date)] ?? defaults }
    public mutating func setTime(_ value: Hours, for date: Date) { hours[BusinessDays.calendar.startOfDay(for: date)] = value }
    public mutating func remove(_ date: Date) { selected.remove(BusinessDays.calendar.startOfDay(for: date)) }
    public mutating func clear() { selected.removeAll(); hours.removeAll() }
    public var invalidDates: [Date] { dates.filter { !time(for: $0).valid } }
    public func formatted() throws -> String {
        guard invalidDates.isEmpty else { throw ToolFailure.message("終了時間は開始時間より後にしてください（0〜23時）") }
        return dates.map { date in
            let c = BusinessDays.calendar.dateComponents([.month, .day, .weekday], from: date)
            let time = time(for: date), weekday = ["日", "月", "火", "水", "木", "金", "土"][c.weekday! - 1]
            return (mode == .multiple ? "・" : "") + "\(c.month!)月\(c.day!)日（\(weekday)）　\(Hours.label(time.start))　〜　\(Hours.label(time.end))"
        }.joined(separator: "\n")
    }
}
