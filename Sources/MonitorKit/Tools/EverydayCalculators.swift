import Foundation

/// Local numerical utilities. Floating point results are approximations.
public enum EverydayCalculators {
    public enum Failure: LocalizedError {
        case invalid(String)
        public var errorDescription: String? { if case .invalid(let message) = self { return message }; return nil }
    }
    public static func number(_ text: String) throws -> Double {
        var normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count <= 1000 else { throw Failure.invalid("数値は1,000文字以内です。") }
        if normalized.contains(",") {
            guard normalized.range(of: #"^[+-]?[0-9]{1,3}(?:,[0-9]{3})+(?:\.[0-9]*)?(?:[eE][+-]?[0-9]+)?$"#, options: .regularExpression) != nil else { throw Failure.invalid("桁区切りのカンマは3桁ごとに指定してください。") }
            normalized = normalized.replacingOccurrences(of: ",", with: "")
        }
        guard let value = Double(normalized), value.isFinite else { throw Failure.invalid("有限の数値を入力してください。") }
        return value
    }
    public static func finite(_ value: Double) throws -> Double {
        guard value.isFinite else { throw Failure.invalid("計算結果が数値の範囲を超えています。") }; return value
    }
    public static func display(_ value: Double, digits: Int = 10) -> String {
        if value != 0 && (abs(value) < pow(10, -Double(digits)) || abs(value) >= 1e15) { return String(format: "%.10g", value) }
        let formatter = NumberFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal; formatter.maximumFractionDigits = digits
        return formatter.string(from: NSNumber(value: value == 0 ? 0 : value)) ?? String(value)
    }
    public enum PercentageMode: String, CaseIterable { case change = "増減率", ratio = "割合", percent = "○%計算", reverse = "逆算" }
    public static func percentage(_ mode: PercentageMode, a: Double, b: Double) throws -> [(String, Double)] {
        guard a.isFinite, b.isFinite else { throw Failure.invalid("有限の数値を入力してください。") }
        let rows: [(String, Double)]
        switch mode {
        case .change:
            guard a != 0 else { throw Failure.invalid("変更前が0の増減率は計算できません。") }
            rows = [("増減率（%）", (b - a) / a * 100), ("差額", b - a), ("前年比（%）", b / a * 100), ("倍率", b / a)]
        case .ratio:
            guard a != 0 else { throw Failure.invalid("全体に0は指定できません。") }; rows = [("割合（%）", b / a * 100)]
        case .percent: rows = [("割合分の値", a * (b / 100)), ("増加後", a * (1 + b / 100)), ("減少後", a * (1 - b / 100))]
        case .reverse:
            guard a != -100 else { throw Failure.invalid("増減率−100%から元の値は逆算できません。") }; rows = [("元の値", b / (1 + a / 100))]
        }
        return try rows.map { ($0.0, try finite($0.1)) }
    }
    public struct UnitGroup {
        public let name: String
        public let units: [(String, Double)]
    }
    public static let unitGroups: [UnitGroup] = [
        .init(name: "長さ", units: [("mm", 0.001), ("cm", 0.01), ("m", 1), ("km", 1000), ("inch", 0.0254), ("feet", 0.3048), ("yard", 0.9144), ("mile", 1609.344)]),
        .init(name: "重さ", units: [("mg", 0.000001), ("g", 0.001), ("kg", 1), ("oz", 0.028349523125), ("lb", 0.45359237)]),
        .init(name: "面積", units: [("cm²", 0.0001), ("m²", 1), ("km²", 1e6), ("坪", 400.0 / 121), ("畳（1.62m²）", 1.62), ("acre", 4046.8564224)]),
        .init(name: "容量", units: [("mL", 0.001), ("L", 1), ("cc", 0.001), ("米 gallon", 3.785411784)]),
        .init(name: "温度", units: [("℃", 1), ("℉", 1), ("K", 1)]),
        .init(name: "データ容量", units: [("B", 0), ("KB", 1), ("MB", 2), ("GB", 3), ("TB", 4)]),
        .init(name: "時間", units: [("ミリ秒", 0.001), ("秒", 1), ("分", 60), ("時間", 3600), ("日", 86400)]),
        .init(name: "速度", units: [("m/s", 1), ("km/h", 1.0 / 3.6), ("mph", 0.44704), ("knot", 1852.0 / 3600)]),
        .init(name: "圧力", units: [("Pa", 1), ("hPa", 100), ("kPa", 1000), ("MPa", 1e6), ("bar", 100000), ("atm", 101325), ("psi", 6894.757293)]),
        .init(name: "通貨", units: ["JPY", "USD", "EUR", "GBP", "CNY", "KRW"].map { ($0, 1.0) })
    ]
    public static func convert(_ value: Double, group: Int, from: String, to: String, binary: Bool = true, rate: Double? = nil) throws -> Double {
        guard unitGroups.indices.contains(group), value.isFinite,
              let source = unitGroups[group].units.first(where: { $0.0 == from }),
              let target = unitGroups[group].units.first(where: { $0.0 == to }) else { throw Failure.invalid("数値・単位を確認してください。") }
        let result: Double
        switch unitGroups[group].name {
        case "温度":
            let c = from == "℃" ? value : from == "℉" ? (value - 32) * 5 / 9 : value - 273.15
            guard c >= -273.15 else { throw Failure.invalid("絶対零度未満には変換できません。") }
            result = to == "℃" ? c : to == "℉" ? c * 9 / 5 + 32 : c + 273.15
        case "データ容量": result = value * pow(binary ? 1024 : 1000, source.1 - target.1)
        case "通貨":
            if from == to { result = value }
            else { guard let rate, rate.isFinite, rate > 0 else { throw Failure.invalid("1 \(from) あたりの \(to) のレートを入力してください。") }; result = value * rate }
        default: result = value * (source.1 / target.1)
        }
        return try finite(result)
    }
    public struct Summary {
        public let rows: [(String, Double)]
        public let ignored: [String]
    }
    public static func summarize(_ text: String) throws -> Summary {
        guard text.utf8.count <= 500_000 else { throw Failure.invalid("入力は500KB以内にしてください。") }
        let tokens = text.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",、"))).filter { !$0.isEmpty }
        guard tokens.count <= 20_000 else { throw Failure.invalid("数値は20,000件以内にしてください。") }
        var values: [Double] = [], ignored: [String] = []
        for token in tokens { if let value = Double(token), value.isFinite { values.append(value) } else { ignored.append(token) } }
        guard !values.isEmpty else { throw Failure.invalid("集計できる数値がありません。") }
        values.sort(); let n = values.count
        // Compensated sum limits loss from adding numbers of different magnitudes.
        var sum = 0.0, correction = 0.0
        for value in values { let y = value - correction; let next = sum + y; correction = (next - sum) - y; sum = next }
        let median = n % 2 == 1 ? values[n / 2] : values[n / 2 - 1] / 2 + values[n / 2] / 2
        let rows: [(String, Double)] = [("合計", sum), ("平均", sum / Double(n)), ("件数", Double(n)), ("最大", values[n - 1]), ("最小", values[0]), ("中央値", median), ("範囲", values[n - 1] - values[0])]
        return Summary(rows: try rows.map { ($0.0, try finite($0.1)) }, ignored: ignored)
    }
    /// Recursive descent; no eval, script engine, or expression execution.
    public static func expression(_ text: String) throws -> Double {
        guard text.count <= 1000 else { throw Failure.invalid("式は1,000文字以内にしてください。") }
        var parser = ExpressionParser(text); return try parser.run()
    }
    private struct ExpressionParser {
        var chars: [Character]; var index = 0; var depth = 0
        init(_ text: String) { chars = Array(text.replacingOccurrences(of: "×", with: "*").replacingOccurrences(of: "÷", with: "/").replacingOccurrences(of: "−", with: "-")) }
        mutating func space() { while index < chars.count && chars[index].isWhitespace { index += 1 } }
        mutating func take(_ char: Character) -> Bool { space(); if index < chars.count && chars[index] == char { index += 1; return true }; return false }
        mutating func run() throws -> Double { let value = try sum(); space(); guard index == chars.count else { throw Failure.invalid("式に使用できない文字があります。") }; return try finite(value) }
        mutating func sum() throws -> Double {
            var value = try product()
            while true { if take("+") { value = try finite(value + product()) } else if take("-") { value = try finite(value - product()) } else { return value } }
        }
        mutating func product() throws -> Double {
            var value = try atom()
            while true {
                if take("*") { value = try finite(value * atom()) }
                else if take("/") { let divisor = try atom(); guard divisor != 0 else { throw Failure.invalid("0では割れません。") }; value = try finite(value / divisor) }
                else { return value }
            }
        }
        mutating func atom() throws -> Double {
            depth += 1; defer { depth -= 1 }
            guard depth <= 64 else { throw Failure.invalid("括弧・符号の入れ子が深すぎます。") }
            if take("+") { return try atom() }; if take("-") { return try -atom() }
            if take("(") { let v = try sum(); guard take(")") else { throw Failure.invalid("閉じ括弧が必要です。") }; return v }
            space(); let start = index
            while index < chars.count && (chars[index].isASCII && chars[index].isNumber || chars[index] == "." || chars[index] == ",") { index += 1 }
            if index < chars.count && (chars[index] == "e" || chars[index] == "E") {
                index += 1; if index < chars.count && (chars[index] == "+" || chars[index] == "-") { index += 1 }
                while index < chars.count && chars[index].isASCII && chars[index].isNumber { index += 1 }
            }
            guard start != index else { throw Failure.invalid("数値または括弧を入力してください。") }
            return try number(String(chars[start..<index]))
        }
    }
}
