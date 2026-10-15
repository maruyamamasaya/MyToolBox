import Foundation

public enum TechnicalCalculators {
    public enum Failure: LocalizedError {
        case invalid(String)
        public var errorDescription: String? { if case .invalid(let text) = self { return text }; return nil }
    }
    public static let units = ["B", "KB", "MB", "GB", "TB", "KiB", "MiB", "GiB", "TiB"]
    public static func factor(_ unit: String) -> Double {
        let values: [Double] = [1, 1e3, 1e6, 1e9, 1e12, 1024, 1048576, 1073741824, 1099511627776]
        return units.firstIndex(of: unit).map { values[$0] } ?? 1
    }
    public static func number(_ text: String, positive: Bool = false) throws -> Double {
        var normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.contains(",") {
            guard normalized.range(of: #"^[+]?[0-9]{1,3}(?:,[0-9]{3})+(?:\.[0-9]*)?(?:[eE][+-]?[0-9]+)?$"#, options: .regularExpression) != nil else {
                throw Failure.invalid("桁区切りのカンマは3桁ごとに指定してください。")
            }
            normalized = normalized.replacingOccurrences(of: ",", with: "")
        }
        guard let value = Double(normalized), value.isFinite,
              positive ? value > 0 : value >= 0 else { throw Failure.invalid(positive ? "0より大きい有限の数値を入力してください。" : "0以上の有限の数値を入力してください。") }
        return value
    }
    public static func bytes(_ text: String, unit: String? = nil) throws -> Double {
        let value: Double
        if let unit { value = try number(text) * factor(unit) }
        else {
            let pattern = #"^\s*([+]?(?:(?:[0-9]{1,3}(?:,[0-9]{3})+|[0-9]+)(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?)\s*([A-Za-z]*)\s*$"#
            let regex = try NSRegularExpression(pattern: pattern)
            let range = NSRange(text.startIndex..., in: text)
            guard let match = regex.firstMatch(in: text, range: range), let nr = Range(match.range(at: 1), in: text), let ur = Range(match.range(at: 2), in: text) else { throw Failure.invalid("例: 1 MB、1024 KiB の形式で入力してください。") }
            let suffix = String(text[ur])
            guard let normalized = units.first(where: { $0.lowercased() == suffix.lowercased() }) ?? (suffix.isEmpty ? "B" : nil) else { throw Failure.invalid("容量の単位を確認してください。") }
            value = try number(String(text[nr])) * factor(normalized)
        }
        return try finite(value)
    }
    public static func finite(_ value: Double) throws -> Double {
        guard value.isFinite else { throw Failure.invalid("計算可能な範囲を超えています。") }; return value
    }
    public static func display(_ value: Double) -> String {
        if value != 0 && (abs(value) < 0.000001 || abs(value) >= 1e16) { return String(format: "%.8g", value) }
        return value.formatted(.number.precision(.fractionLength(0...8)))
    }
    // Repeated long division keeps integers exact without a third-party big integer dependency.
    public static func base(_ raw: String, from: Int, to: Int) throws -> String {
        guard (2...60).contains(from), (2...60).contains(to) else { throw Failure.invalid("基数は2〜60で指定してください。") }
        let alphabet = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwx")
        var source = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard source.count <= 1024 else { throw Failure.invalid("入力は1024桁以内にしてください。") }
        let negative = source.hasPrefix("-")
        if source.hasPrefix("-") || source.hasPrefix("+") { source.removeFirst() }
        if from == 2 && source.lowercased().hasPrefix("0b") || from == 16 && source.lowercased().hasPrefix("0x") { source.removeFirst(2) }
        if from == 10 { source = source.replacingOccurrences(of: ",", with: "") }
        if from <= 36 { source = source.uppercased() }
        guard !source.isEmpty else { throw Failure.invalid("整数を入力してください。") }
        var digits = try source.map { character -> Int in
            guard let digit = alphabet.firstIndex(of: character), digit < from else { throw Failure.invalid("\(from)進数では「\(character)」を使用できません。") }; return digit
        }
        var result = ""
        while !digits.isEmpty {
            var quotient: [Int] = [], remainder = 0
            for digit in digits {
                let value = remainder * from + digit
                if !quotient.isEmpty || value / to != 0 { quotient.append(value / to) }
                remainder = value % to
            }
            result.append(alphabet[remainder]); digits = quotient
        }
        let output = String(result.reversed())
        return negative && output != "0" ? "-" + output : output
    }
    public struct RAIDResult {
        public let raw, usable, efficiency: Double
        public let faults: String
    }
    public static func raid(level: Int, count: Int, size: Double) throws -> RAIDResult {
        let minimum = [0: 2, 1: 2, 5: 3, 6: 4, 10: 4]
        guard let min = minimum[level], count >= min, count <= 1000 else { throw Failure.invalid("RAID構成に必要な台数（最大1000台）を指定してください。") }
        guard level != 10 || count.isMultiple(of: 2) else { throw Failure.invalid("RAID 10には偶数台が必要です。") }
        guard size.isFinite, size > 0 else { throw Failure.invalid("ディスク容量は0より大きくしてください。") }
        let usableCount = level == 1 ? 1 : level == 5 ? count - 1 : level == 6 ? count - 2 : level == 10 ? count / 2 : count
        let raw = try finite(Double(count) * size), usable = try finite(Double(usableCount) * size)
        let faults = level == 0 ? "0台" : level == 1 ? "\(count - 1)台" : level == 5 ? "1台" : level == 6 ? "2台" : "各ミラーペア1台（同じペアの2台故障は不可）"
        return RAIDResult(raw: raw, usable: usable, efficiency: usable / raw * 100, faults: faults)
    }
    public static func bandwidth(bytes: Double, seconds: Double) throws -> Double {
        guard bytes.isFinite, bytes > 0, seconds.isFinite, seconds > 0 else { throw Failure.invalid("容量と時間は0より大きくしてください。") }
        return try finite(bytes / seconds * 8)
    }
    public static func transferTime(bytes: Double, bitsPerSecond: Double) throws -> Double {
        guard bytes.isFinite, bytes > 0, bitsPerSecond.isFinite, bitsPerSecond > 0 else { throw Failure.invalid("容量と帯域幅は0より大きくしてください。") }
        return try finite(bytes / bitsPerSecond * 8)
    }
    public static func downtime(rate: Double, days: Double) throws -> Double {
        guard rate.isFinite, (0...100).contains(rate), days.isFinite, days > 0 else { throw Failure.invalid("稼働率は0〜100%で入力してください。") }
        return try finite(days * 86400 * ((100 - rate) / 100))
    }
    public static func duration(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "—" }
        if seconds < 1 { return display(seconds) + "秒" }
        if seconds >= Double(Int.max / 2) { return display(seconds) + "秒" }
        var rest = Int(seconds.rounded())
        var parts: [String] = []
        for (unit, label) in [(86400, "日"), (3600, "時間"), (60, "分"), (1, "秒")] {
            if rest >= unit { parts.append("\(rest / unit)\(label)"); rest %= unit }
        }
        return parts.joined(separator: " ")
    }
}
