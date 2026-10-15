import Foundation

public enum ServerUtilities {
    public typealias Failure = EverydayCalculators.Failure
    public struct Permission {
        public let value: Int
        public var octal: String { String(format: "%03o", value) }
        public var symbolic: String {
            var chars: [Character] = []
            for (group, shift) in [6, 3, 0].enumerated() {
                let bits = (value >> shift) & 7
                chars.append(bits & 4 != 0 ? "r" : "-"); chars.append(bits & 2 != 0 ? "w" : "-")
                let special = value & (1 << (11 - group)) != 0, execute = bits & 1 != 0
                chars.append(special ? (group == 2 ? (execute ? "t" : "T") : (execute ? "s" : "S")) : (execute ? "x" : "-"))
            }; return String(chars)
        }
        public var details: [String] {
            zip(["所有者", "グループ", "その他"], [6, 3, 0]).map { name, shift in
                let bits = (value >> shift) & 7
                let actions = [(4, "読み取り"), (2, "書き込み"), (1, "実行／ディレクトリ通過")].filter { bits & $0.0 != 0 }.map { $0.1 }
                return name + ": " + (actions.isEmpty ? "権限なし" : actions.joined(separator: "・"))
            }
        }
    }
    public static func permission(_ raw: String) throws -> Permission {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if (3...4).contains(text.count), text.allSatisfy({ ("0"..."7").contains(String($0)) }), let value = Int(text, radix: 8) { return Permission(value: value) }
        let chars = Array(text)
        guard chars.count == 9 else { throw Failure.invalid("755、4755、rwxr-xr-xのように入力してください。") }
        var value = 0
        for group in 0..<3 {
            let offset = group * 3, shift = 6 - group * 3
            guard chars[offset] == "r" || chars[offset] == "-", chars[offset + 1] == "w" || chars[offset + 1] == "-" else { throw Failure.invalid("権限記号の順序はrwxです。") }
            if chars[offset] == "r" { value |= 4 << shift }; if chars[offset + 1] == "w" { value |= 2 << shift }
            let x = chars[offset + 2], lower: Character = group == 2 ? "t" : "s", upper: Character = group == 2 ? "T" : "S"
            guard x == "x" || x == "-" || x == lower || x == upper else { throw Failure.invalid("実行・特殊ビットの記号を確認してください。") }
            if x == "x" || x == lower { value |= 1 << shift }; if x == lower || x == upper { value |= 1 << (11 - group) }
        }; return Permission(value: value)
    }
    public struct Cron {
        public let fields: [String]
        public let values: [Set<Int>]
        public var descriptions: [String] {
            let names = ["分", "時", "日", "月", "曜日"]
            let weekdays = ["日", "月", "火", "水", "木", "金", "土"]
            return fields.indices.map { i in
                let expanded = fields[i] == "*" ? "すべて" : values[i].sorted().map { i == 4 ? weekdays[$0] + "曜" : String($0) }.joined(separator: "、")
                return "\(names[i]): \(expanded)（\(fields[i])）"
            }
        }
        public var summary: String {
            let weekdays = ["日曜日", "月曜日", "火曜日", "水曜日", "木曜日", "金曜日", "土曜日"]
            let fixedMinutes = fields[0].allSatisfy { $0.isNumber || $0 == "," }
            let fixedHours = fields[1].allSatisfy { $0.isNumber || $0 == "," }
            let time = fixedMinutes && fixedHours ? values[1].sorted().flatMap { hour in
                values[0].sorted().map { "\(hour):" + String(format: "%02d", $0) }
            }.joined(separator: "、") : ""
            if Array(fields.suffix(3)) == ["*", "*", "*"] {
                if fields[0].range(of: #"^\*/[0-9]+$"#, options: .regularExpression) != nil && fields[1] == "*" { return String(fields[0].dropFirst(2)) + "分ごとに実行" }
                if !time.isEmpty { return "毎日 " + time + " に実行" }
            }
            if fields[2] == "*" && fields[3] == "*" && !time.isEmpty {
                let days = fields[4] == "1-5" ? "平日の毎日" : "毎週" + values[4].sorted().map { weekdays[$0] }.joined(separator: "・")
                return days + " " + time + " に実行"
            }
            if fields[3] == "*" && fields[4] == "*" && fields[2] != "*" && !time.isEmpty {
                return "毎月" + values[2].sorted().map(String.init).joined(separator: "・") + "日 " + time + " に実行"
            }
            let dayRule = !fields[2].hasPrefix("*") && !fields[4].hasPrefix("*") ? "日と曜日はいずれかに一致" : "日と曜日は両方に一致"
            return descriptions.joined(separator: " ／ ") + "。" + dayRule + "で実行"
        }
        /// Standard five-field cron: restricted day-of-month/day-of-week use OR.
        public func next(after date: Date, timeZone: TimeZone, count: Int = 5) -> [Date] {
            var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timeZone
            var day = calendar.startOfDay(for: date), result: [Date] = []
            for _ in 0..<2928 { // Eight years covers a leap-day expression across a non-leap century.
                let c = calendar.dateComponents([.month, .day, .weekday], from: day)
                let dom = values[2].contains(c.day!), dow = values[4].contains(c.weekday! - 1)
                let domAny = fields[2].hasPrefix("*"), dowAny = fields[4].hasPrefix("*")
                let matchesDay = domAny || dowAny ? dom && dow : dom || dow
                if values[3].contains(c.month!) && matchesDay {
                    for hour in values[1].sorted() { for minute in values[0].sorted() {
                        let components = DateComponents(hour: hour, minute: minute, second: 0)
                        // Calendar handles nonexistent wall times; only exact matching times are retained.
                        if let candidate = calendar.nextDate(after: day.addingTimeInterval(-1), matching: components, matchingPolicy: .strict, repeatedTimePolicy: .first), calendar.isDate(candidate, inSameDayAs: day), candidate > date {
                            result.append(candidate); if result.count >= max(1, min(count, 20)) { return result }
                        }
                    } }
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }; day = next
            }; return result
        }
    }
    public static func cron(_ text: String) throws -> Cron {
        guard text.count <= 256 else { throw Failure.invalid("Cron式は256文字以内です。") }
        let fields = text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard fields.count == 5 else { throw Failure.invalid("分・時・日・月・曜日の5フィールドを入力してください。") }
        let ranges = [0...59, 0...23, 1...31, 1...12, 0...6], names = ["分", "時", "日", "月", "曜日"]
        var all: [Set<Int>] = []
        func integer(_ text: Substring) -> Int? { !text.isEmpty && text.allSatisfy({ $0.isASCII && $0.isNumber }) ? Int(text) : nil }
        for (i, field) in fields.enumerated() {
            var values = Set<Int>()
            for item in field.split(separator: ",", omittingEmptySubsequences: false) {
                let stepParts = item.split(separator: "/", omittingEmptySubsequences: false)
                guard stepParts.count <= 2, let base = stepParts.first else { throw Failure.invalid("\(names[i])の書式を確認してください。") }
                let step: Int
                if stepParts.count == 2 { guard let n = integer(stepParts[1]), n > 0, n <= ranges[i].count else { throw Failure.invalid("\(names[i])の間隔を確認してください。") }; step = n } else { step = 1 }
                let start: Int, end: Int
                if base == "*" { start = ranges[i].lowerBound; end = ranges[i].upperBound }
                else {
                    let pair = base.split(separator: "-", omittingEmptySubsequences: false)
                    guard (1...2).contains(pair.count), let first = integer(pair[0]), let last = integer(pair[pair.count - 1]), first <= last, ranges[i].contains(first), ranges[i].contains(last), stepParts.count == 1 || pair.count == 2 else { throw Failure.invalid("\(names[i])は\(ranges[i].lowerBound)〜\(ranges[i].upperBound)。数値・範囲・*・リスト・*/nに対応します。") }
                    start = first; end = last
                }
                values.formUnion(stride(from: start, through: end, by: step))
            }; all.append(values)
        }; return Cron(fields: fields, values: all)
    }
    public enum EpochUnit: String, CaseIterable { case automatic = "自動判定", seconds = "秒", milliseconds = "ミリ秒" }
    public static func epoch(_ text: String, unit: EpochUnit) throws -> Date {
        let raw = try EverydayCalculators.number(text)
        let milliseconds = unit == .milliseconds || (unit == .automatic && abs(raw) >= 1e11)
        let seconds = milliseconds ? raw / 1000 : raw
        let date = Date(timeIntervalSince1970: seconds)
        guard seconds >= -62_135_596_800, seconds <= 253_402_300_799.999 else { throw Failure.invalid("対応範囲は西暦1〜9999年です。") }; return date
    }
    public static func date(_ text: String, timeZone: TimeZone) throws -> Date {
        var text = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "T", with: " ")
        if text.count == 16 { text += ":00" }
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone; formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"; formatter.isLenient = false
        guard let date = formatter.date(from: text), formatter.string(from: date) == text,
              date.timeIntervalSince1970 >= -62_135_596_800, date.timeIntervalSince1970 <= 253_402_300_799 else { throw Failure.invalid("日時はyyyy-MM-dd HH:mm:ss形式・西暦1〜9999年で入力してください。") }; return date
    }
    public static func dateText(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.calendar = Calendar(identifier: .gregorian); formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZZ"; return formatter.string(from: date)
    }
}
