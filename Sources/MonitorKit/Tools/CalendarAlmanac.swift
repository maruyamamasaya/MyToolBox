import Foundation

/// Local JST calendar annotations based on NAOJ's published 2023–2027 ephemerides.
public enum CalendarAlmanac {
    public struct Annotation: Equatable {
        public let rokuyo: String?
        public let solarTerm: String?
        public let moonPhase: String?
        /// Elapsed days from the preceding new moon to noon JST.
        public let moonAge: Double?
    }
    public static let supportedYears = 2024...2027
    private static let formatter: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = BusinessDays.calendar; f.timeZone = BusinessDays.calendar.timeZone
        f.dateFormat = "yyyy-MM-dd'T'HH:mm"; return f
    }()
    private static let phases = AlmanacData.phases.map { (date: formatter.date(from: $0.0)!, name: $0.1) }
    private static let lunarMonths = AlmanacData.lunarMonths.map { (date: formatter.date(from: $0.0 + "T00:00")!, month: $0.1) }

    public static func annotation(for date: Date) -> Annotation {
        let c = BusinessDays.calendar
        guard supportedYears.contains(c.component(.year, from: date)) else {
            return Annotation(rokuyo: nil, solarTerm: nil, moonPhase: nil, moonAge: nil)
        }
        let start = c.startOfDay(for: date)
        let noon = c.date(byAdding: .hour, value: 12, to: start)!
        let newMoon = phases.last { $0.name == "朔" && $0.date <= noon }
        let lunar = lunarMonths.last { $0.date <= start }
        let rokuyo = lunar.map {
            let day = c.dateComponents([.day], from: $0.date, to: start).day! + 1
            return ["大安", "赤口", "先勝", "友引", "先負", "仏滅"][($0.month + day) % 6]
        }
        let phase = phases.first { c.isDate($0.date, inSameDayAs: start) }.map {
            ["朔": "● 新月", "望": "○ 満月", "上弦": "◐ 上弦", "下弦": "◑ 下弦"][$0.name]!
        }
        return Annotation(rokuyo: rokuyo, solarTerm: AlmanacData.terms[BusinessDays.key(date)], moonPhase: phase,
                          moonAge: newMoon.map { noon.timeIntervalSince($0.date) / 86400 })
    }
}
