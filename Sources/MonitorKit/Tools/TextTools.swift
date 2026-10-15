import Foundation

public enum TextToolLimits {
    public static func input(_ text: String) throws {
        guard text.utf8.count <= 1_048_576 else { throw ToolFailure.message("入力は1MiB以下にしてください") }
    }
    public static func output(_ text: String) throws -> String {
        guard text.utf8.count <= 4_194_304 else { throw ToolFailure.message("変換結果が4MiBを超えます。入力や設定を減らしてください") }
        return text
    }
    public static func normalized(_ text: String) -> String { text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n") }
}
public enum SequentialText {
    public struct Options: Sendable, Equatable {
        public var start: Int64 = 1
        public var increment: Int64 = 1
        public var digits = 1
        public var prefix = ""
        public var suffix = ""
        public var separator = ". "
        public var atEnd = false
        public var numberEmptyLines = false
        public init() {}
    }
    public struct Result: Sendable { public let output: String; public let lines: Int; public let numbered: Int }
    public static func generate(_ input: String, options: Options) throws -> Result {
        try TextToolLimits.input(input)
        guard (1...12).contains(options.digits), options.prefix.utf8.count <= 1024, options.suffix.utf8.count <= 1024, options.separator.utf8.count <= 128 else { throw ToolFailure.message("桁数は1〜12、前後の文字は各1024バイト、区切りは128バイト以内です") }
        guard !input.isEmpty else { return Result(output: "", lines: 0, numbered: 0) }
        let lines = TextToolLimits.normalized(input).components(separatedBy: "\n")
        guard lines.count <= 20_000 else { throw ToolFailure.message("最大20,000行です") }
        var number = options.start, numbered = 0, output: [String] = [], bytes = 0
        for line in lines {
            let value: String
            if line.isEmpty && !options.numberEmptyLines { value = "" }
            else {
                if numbered > 0 {
                    let next = number.addingReportingOverflow(options.increment)
                    guard !next.overflow else { throw ToolFailure.message("連番が64ビット整数の範囲を超えます") }; number = next.partialValue
                }
                let magnitude = String(number.magnitude)
                let serial = (number < 0 ? "-" : "") + String(repeating: "0", count: max(0, options.digits - magnitude.count)) + magnitude
                value = options.prefix + (options.atEnd ? line + options.separator + serial : serial + options.separator + line) + options.suffix
                numbered += 1
            }
            bytes += value.utf8.count + 1
            guard bytes <= 4_194_304 else { throw ToolFailure.message("変換結果が4MiBを超えます") }
            output.append(value)
        }
        return Result(output: output.joined(separator: "\n"), lines: lines.count, numbered: numbered)
    }
}
public enum ClipboardTable {
    public enum Delimiter: String, Sendable { case tab = "タブ区切り", comma = "カンマ区切り", space = "スペース区切り", newline = "改行（1列）" }
    public enum Format: String, CaseIterable, Sendable { case comma = "カンマ区切り", tab = "タブ区切り", space = "スペース区切り", newline = "改行", markdown = "Markdown Table", sqlValues = "SQL IN（値のみ）", sqlIn = "SQL IN（IN付き）" }
    public enum Quote: String, CaseIterable, Sendable { case none = "なし", double = "ダブルクォート", single = "シングルクォート" }
    public struct Options: Sendable, Equatable {
        public var trim = true, removeEmpty = false, removeDuplicates = false, collapseSpaces = false
        public var format: Format = .comma
        public var quote: Quote = .none
        public init() {}
    }
    public struct Parsed: Sendable { public let delimiter: Delimiter; public let rows: [[String]] }
    public static func parse(_ input: String) throws -> Parsed {
        try TextToolLimits.input(input)
        guard !input.isEmpty else { return Parsed(delimiter: .newline, rows: []) }
        let text = TextToolLimits.normalized(input)
        let delimiter: Delimiter
        let rows: [[String]]
        if text.contains("\t") { delimiter = .tab; rows = try CSVDocument.parse(text, delimiter: "\t") }
        else if text.contains(",") { delimiter = .comma; rows = try CSVDocument.parse(text) }
        else {
            let lines = text.components(separatedBy: "\n")
            guard lines.count <= 20_000 else { throw ToolFailure.message("最大20,000行です") }
            let nonempty = lines.filter { !$0.isEmpty }
            let spaces = !nonempty.isEmpty && nonempty.allSatisfy { $0.split(whereSeparator: \.isWhitespace).count > 1 }
            delimiter = spaces ? .space : .newline
            rows = lines.map { line in spaces ? (line.split(whereSeparator: \.isWhitespace).isEmpty ? [""] : line.split(whereSeparator: \.isWhitespace).map(String.init)) : [line] }
        }
        let width = rows.map(\.count).max() ?? 0
        guard width <= 200, rows.count * width <= 200_000 else { throw ToolFailure.message("最大200列・200,000セルです") }
        return Parsed(delimiter: delimiter, rows: rows.map { $0 + Array(repeating: "", count: width - $0.count) })
    }
    public static func format(_ rows: [[String]], columns: Set<Int>, options: Options) throws -> String {
        guard rows.count <= 20_000, (rows.map(\.count).max() ?? 0) <= 200, rows.reduce(0, { $0 + $1.count }) <= 200_000 else { throw ToolFailure.message("データが上限を超えています") }
        guard !columns.isEmpty else { return "" }
        var seen: Set<[String]> = []
        var data: [[String]] = []
        var bytes = 0
        for row in rows {
            var cleaned: [String] = []
            for i in row.indices where columns.contains(i) {
                var value = row[i]
                if options.trim { value = value.trimmingCharacters(in: .whitespacesAndNewlines) }
                if options.collapseSpaces { value = value.replacingOccurrences(of: "[ 　]+", with: " ", options: .regularExpression) }
                bytes += value.utf8.count
                guard bytes <= 1_048_576 else { throw ToolFailure.message("編集後の入力が1MiBを超えています") }
                cleaned.append(value)
            }
            if options.removeEmpty && cleaned.allSatisfy(\.isEmpty) { continue }
            if options.removeDuplicates && !seen.insert(cleaned).inserted { continue }
            data.append(cleaned)
        }
        func quoted(_ value: String) -> String {
            guard options.quote != .none else { return value }
            let mark = options.quote == .double ? "\"" : "'"
            return mark + value.replacingOccurrences(of: mark, with: mark + mark) + mark
        }
        let output: String
        switch options.format {
        case .markdown:
            func line(_ row: [String]) -> String { "| " + row.map { $0.replacingOccurrences(of: "|", with: "\\|").replacingOccurrences(of: "\n", with: "<br>") }.joined(separator: " | ") + " |" }
            if let first = data.first { output = ([line(first), line(first.map { _ in "---" })] + data.dropFirst().map(line)).joined(separator: "\n") } else { output = "" }
        case .sqlValues, .sqlIn:
            let values = data.flatMap { $0 }.map { "'" + $0.replacingOccurrences(of: "'", with: "''") + "'" }.joined(separator: ",")
            output = options.format == .sqlIn ? "IN (" + values + ")" : values
        case .newline: output = data.flatMap { $0 }.map(quoted).joined(separator: "\n")
        case .comma, .tab, .space:
            let separator = options.format == .comma ? "," : options.format == .tab ? "\t" : " "
            output = data.map { $0.map(quoted).joined(separator: separator) }.joined(separator: "\n")
        }
        return try TextToolLimits.output(output)
    }
}
public enum TextCleaner {
    public static func clean(_ input: String) throws -> String {
        try TextToolLimits.input(input)
        var text = TextToolLimits.normalized(input).replacingOccurrences(of: "\u{00A0}", with: " ").replacingOccurrences(of: "\u{200B}", with: "").replacingOccurrences(of: "\u{FEFF}", with: "")
        text = text.replacingOccurrences(of: "\\n(?:[^\\S\\n]*\\n)+", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?m)^([^\\S\\n]*・)[^\\S\\n]*\\n[^\\S\\n]*(?=[^\\s・])", with: "$1", options: .regularExpression)
        return text
    }
}
