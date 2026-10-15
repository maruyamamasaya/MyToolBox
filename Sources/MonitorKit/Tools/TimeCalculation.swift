import Foundation

public enum TimeCalculation {
    public enum Failure: LocalizedError {
        case invalid(String)
        public var errorDescription: String? { if case .invalid(let message) = self { return message }; return nil }
    }
    public static func minutes(_ text: String) throws -> Int {
        let parts = text.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy({ $0.isASCII && $0.isNumber }) }),
              let hour = Int(parts[0]), let minute = Int(parts[1]), (0...23).contains(hour), (0...59).contains(minute) else {
            throw Failure.invalid("時刻は00:00〜23:59で入力してください。")
        }
        return hour * 60 + minute
    }
    public static func interval(_ start: String, _ end: String) throws -> Int {
        let difference = try minutes(end) - minutes(start)
        return difference < 0 ? difference + 1440 : difference
    }
    public static func work(_ start: String, _ end: String, rest: String) throws -> (gross: Int, net: Int) {
        let gross = try interval(start, end), pause = try minutes(rest)
        guard pause <= gross else { throw Failure.invalid("休憩が実時間を超えています。") }
        return (gross, gross - pause)
    }
    public static func total(_ text: String) throws -> Int {
        let lines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !lines.isEmpty, lines.count <= 1000 else { throw Failure.invalid("時間帯を1〜1000行で入力してください。") }
        return try lines.enumerated().reduce(0) { sum, line in
            let normalized = line.element.replacingOccurrences(of: "〜", with: "-").replacingOccurrences(of: "～", with: "-").replacingOccurrences(of: "–", with: "-")
            let parts = normalized.components(separatedBy: "-")
            guard parts.count == 2 else { throw Failure.invalid("\(line.offset + 1)行目：開始 - 終了の形式にしてください。") }
            return try sum + interval(parts[0], parts[1])
        }
    }
    public static func display(_ minutes: Int) -> String { "\(minutes / 60)時間\(String(format: "%02d", minutes % 60))分" }
    public static func report(_ minutes: Int) -> String { "\(display(minutes))\n\(String(format: "%.2f", Double(minutes) / 60))時間\n\(minutes)分" }
}
