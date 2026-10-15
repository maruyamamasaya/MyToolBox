import Foundation
public struct BusinessDays {
    public static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Tokyo")!; return c
    }
    public static func key(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
    public struct Result: Equatable { public var total = 0, weekends = 0, holidays = 0, business = 0 }
    public let holidays: [String: String]
    public init(data: Data) throws { holidays = try JSONDecoder().decode([String: String].self, from: data) }
    public func calculate(start: Date, end: Date, custom: Set<String> = []) throws -> Result {
        let c = Self.calendar, first = c.startOfDay(for: start), last = c.startOfDay(for: end)
        guard first <= last else { throw ToolFailure.message("終了日は開始日以降を指定してください") }
        guard (1955...2027).contains(c.component(.year, from: first)), (1955...2027).contains(c.component(.year, from: last)) else { throw ToolFailure.message("同梱の祝日データは1955〜2027年に対応しています") }
        var result = Result(), day = first
        while day <= last {
            result.total += 1
            if [1,7].contains(c.component(.weekday, from: day)) { result.weekends += 1 }
            else if holidays[Self.key(day)] != nil || custom.contains(Self.key(day)) { result.holidays += 1 }
            else { result.business += 1 }
            day = c.date(byAdding: .day, value: 1, to: day)!
        }
        return result
    }
}
