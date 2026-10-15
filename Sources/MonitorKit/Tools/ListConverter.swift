import Foundation
public enum ListConverter {
    public enum Input: String, CaseIterable, Sendable { case auto = "自動判定", newline = "改行", comma = "カンマ", tab = "タブ", space = "空白", semicolon = "セミコロン", json = "JSON配列", custom = "カスタム" }
    public enum Format: String, CaseIterable, Sendable { case newline = "改行区切り", comma = "カンマ区切り", space = "スペース区切り", commaSpace = "カンマ＋スペース", single = "シングルクォート", double = "ダブルクォート（JSON式）", sql = "SQL IN", json = "JSON配列" }
    public enum Order: String, CaseIterable, Sendable { case original = "元の順", ascending = "自然順・昇順", descending = "自然順・降順" }
    public struct Options: Equatable, Sendable {
        public var input: Input = .auto
        public var format: Format = .newline
        public var order: Order = .original
        public var separator = "", prefix = "", suffix = ""
        public var trim = true, removeEmpty = true, deduplicate = false
        public init() {}
    }
    public struct Result: Sendable { public let output: String; public let inputCount: Int; public let count: Int }
    private static func split(_ text: String, separator: String) throws -> [String] {
        guard !separator.isEmpty else { return [text] }
        var values: [String] = [], item = "", quote: Character?, i = text.startIndex
        while i < text.endIndex {
            let c = text[i], next = text.index(after: i)
            if let active = quote {
                if c == active {
                    if next < text.endIndex && text[next] == active { item.append(c); i = text.index(after: next); continue }
                    quote = nil
                } else { item.append(c) }
            } else if (c == "\"" || c == "'"), item.trimmingCharacters(in: .whitespaces).isEmpty { quote = c }
            else if text[i...].hasPrefix(separator) {
                values.append(item); item = ""; i = text.index(i, offsetBy: separator.count)
                guard values.count < 20_000 else { throw ToolFailure.message("最大20,000項目です") }; continue
            } else { item.append(c) }
            i = next
        }
        guard quote == nil else { throw ToolFailure.message("閉じていない引用符があります") }
        values.append(item); return values
    }
    public static func convert(_ input: String, options: Options) throws -> Result {
        try TextToolLimits.input(input)
        guard options.prefix.utf8.count <= 1024, options.suffix.utf8.count <= 1024, options.separator.utf8.count <= 128 else { throw ToolFailure.message("前後の文字は各1024バイト・区切りは128バイト以内です") }
        let text = TextToolLimits.normalized(input)
        var items: [String]
        if text.isEmpty { items = [] }
        else if options.input == .json {
            guard let decoded = try? JSONDecoder().decode([String].self, from: Data(text.utf8)) else { throw ToolFailure.message("文字列のJSON配列を入力してください（例：[\"a\",\"b\"]）") }
            items = decoded
        } else if options.input == .space { items = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).components(separatedBy: " ") }
        else {
            let delimiter: String
            switch options.input {
            case .newline: delimiter = "\n"
            case .comma: delimiter = ","
            case .tab: delimiter = "\t"
            case .semicolon: delimiter = ";"
            case .custom: delimiter = options.separator
            default: delimiter = ["\n", "\t", ",", ";"].first(where: { text.contains($0) }) ?? ""
            }
            items = try split(text, separator: delimiter)
        }
        guard items.count <= 20_000 else { throw ToolFailure.message("最大20,000項目です") }
        let inputCount = items.count
        if options.trim { items = items.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } }
        if options.removeEmpty { items.removeAll(where: \.isEmpty) }
        if options.deduplicate { var seen: Set<String> = []; items = items.filter { seen.insert($0).inserted } }
        if options.order != .original {
            items = items.enumerated().sorted { a,b in let order = LineTools.naturalCompare(a.element,b.element); return order == .orderedSame ? a.offset < b.offset : options.order == .ascending ? order == .orderedAscending : order == .orderedDescending }.map(\.element)
        }
        var bytes = 0
        items = try items.map { value in
            let result = options.prefix + value + options.suffix; bytes += result.utf8.count
            guard bytes <= 4_194_304 else { throw ToolFailure.message("変換結果が4MiBを超えます") }; return result
        }
        func single(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "''") + "'" }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.withoutEscapingSlashes]
        func json(_ value: String) throws -> String { String(decoding: try encoder.encode(value), as: UTF8.self) }
        let output: String
        switch options.format {
        case .newline: output = items.joined(separator: "\n")
        case .comma: output = items.joined(separator: ",")
        case .space: output = items.joined(separator: " ")
        case .commaSpace: output = items.joined(separator: ", ")
        case .single: output = items.map(single).joined(separator: ",")
        case .double: output = try items.map(json).joined(separator: ",")
        case .sql: output = "IN (" + items.map(single).joined(separator: ",") + ")"
        case .json: output = String(decoding: try encoder.encode(items), as: UTF8.self)
        }
        return Result(output: try TextToolLimits.output(output), inputCount: inputCount, count: items.count)
    }
}
