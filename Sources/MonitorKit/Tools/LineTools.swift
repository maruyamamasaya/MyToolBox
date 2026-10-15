import Foundation

public enum LineTools {
    public static func lines(_ input: String) throws -> [String] {
        try TextToolLimits.input(input)
        let lines = input.isEmpty ? [] : TextToolLimits.normalized(input).components(separatedBy: "\n")
        guard lines.count <= 20_000 else { throw ToolFailure.message("最大20,000行です") }
        return lines
    }
    public enum SortMode: String, CaseIterable, Sendable { case natural = "自然順", alphabetic = "文字順", number = "数値順" }
    public struct SortOptions: Equatable, Sendable {
        public var mode: SortMode = .natural
        public var descending = false, emptyLast = true, removeDuplicates = false, originalOrder = false
        public init() {}
    }
    public static func naturalCompare(_ a: String, _ b: String) -> ComparisonResult {
        func parts(_ text: String) -> [String] {
            var chunks: [String] = []; var current = ""; var previous: Bool?
            for scalar in text.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars {
                let digit = (48...57).contains(scalar.value)
                if let previous, previous != digit { chunks.append(current); current = "" }
                current.unicodeScalars.append(scalar); previous = digit
            }
            if !current.isEmpty { chunks.append(current) }; return chunks
        }
        let left = parts(a), right = parts(b)
        for (x,y) in zip(left,right) {
            let order: ComparisonResult
            if x.first?.isASCII == true, x.first?.isNumber == true, y.first?.isASCII == true, y.first?.isNumber == true {
                let nx = String(x.drop(while: { $0 == "0" })), ny = String(y.drop(while: { $0 == "0" }))
                order = nx.count == ny.count ? nx.compare(ny, options: .literal) : nx.count < ny.count ? .orderedAscending : .orderedDescending
            } else { order = compareText(x,y) }
            if order != .orderedSame { return order }
        }
        return left.count == right.count ? .orderedSame : left.count < right.count ? .orderedAscending : .orderedDescending
    }
    private static func compareText(_ a: String, _ b: String) -> ComparisonResult {
        a.compare(b, options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "ja_JP"))
    }
    private static func number(_ text: String) -> Decimal? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.range(of: "^[+-]?(?:[0-9]+(?:\\.[0-9]*)?|\\.[0-9]+)(?:[eE][+-]?[0-9]+)?$", options: .regularExpression) != nil else { return nil }
        return Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))
    }
    public static func sort(_ input: String, options: SortOptions) throws -> [String] {
        let source = try lines(input)
        if options.originalOrder { return source }
        var seen: Set<String> = []
        let entries = source.enumerated().filter { !options.removeDuplicates || seen.insert($0.element).inserted }
        return entries.sorted { l,r in
            let a = l.element.trimmingCharacters(in: .whitespacesAndNewlines), b = r.element.trimmingCharacters(in: .whitespacesAndNewlines)
            if options.emptyLast, a.isEmpty != b.isEmpty { return !a.isEmpty }
            let order: ComparisonResult
            switch options.mode {
            case .natural: order = naturalCompare(a,b)
            case .alphabetic: order = compareText(a,b)
            case .number:
                let x = number(a), y = number(b)
                if let x, let y { order = x == y ? .orderedSame : x < y ? .orderedAscending : .orderedDescending }
                else if x != nil { order = .orderedAscending }
                else if y != nil { order = .orderedDescending }
                else { order = compareText(a,b) }
            }
            if order == .orderedSame { return l.offset < r.offset }
            return options.descending ? order == .orderedDescending : order == .orderedAscending
        }.map(\.element)
    }
    public enum ConditionType: String, CaseIterable, Sendable { case contains = "含む", notContains = "含まない", starts = "で始まる", ends = "で終わる", equals = "完全一致" }
    public struct Condition: Equatable, Identifiable, Sendable {
        public let id: UUID
        public var type: ConditionType
        public var value: String
        public init(type: ConditionType = .contains, value: String = "") { id = UUID(); self.type = type; self.value = value }
    }
    public struct FilterOptions: Equatable, Sendable {
        public var any = false, ignoreCase = false, ignoreEmpty = true, showNumbers = false
        public var conditions = [Condition()]
        public init() {}
    }
    public struct FilterResult: Sendable { public let output: String; public let total: Int; public let count: Int }
    public static func filter(_ input: String, options: FilterOptions) throws -> FilterResult {
        let source = try lines(input), conditions = options.conditions.filter { !$0.value.isEmpty }
        guard conditions.count <= 100 else { throw ToolFailure.message("抽出条件は100件以内にしてください") }
        var matches: [String] = []
        for (index,line) in source.enumerated() {
            if options.ignoreEmpty && line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }
            if conditions.isEmpty { continue }
            let text = options.ignoreCase ? line.lowercased() : line
            let results = conditions.map { condition in
                let query = options.ignoreCase ? condition.value.lowercased() : condition.value
                switch condition.type {
                case .contains: return text.contains(query)
                case .notContains: return !text.contains(query)
                case .starts: return text.hasPrefix(query)
                case .ends: return text.hasSuffix(query)
                case .equals: return text == query
                }
            }
            if options.any ? results.contains(true) : results.allSatisfy({ $0 }) { matches.append(options.showNumbers ? "\(index + 1): " + line : line) }
        }
        return FilterResult(output: try TextToolLimits.output(matches.joined(separator: "\n")), total: source.count, count: matches.count)
    }
    public struct DuplicateOptions: Equatable, Sendable {
        public var ignoreEmpty = true, trim = true, ignoreCase = false
        public init() {}
    }
    public struct DuplicateGroup: Sendable, Identifiable {
        public var id: Int { lineNumbers[0] }
        public let value: String
        public var lineNumbers: [Int]
    }
    public struct DuplicateResult: Sendable {
        public let lines: Int, total: Int, unique: Int, extra: Int
        public let groups: [DuplicateGroup]
        public var output: String { groups.map(\.value).joined(separator: "\n") }
    }
    public static func duplicates(_ input: String, options: DuplicateOptions) throws -> DuplicateResult {
        let source = try lines(input)
        var indices: [String: Int] = [:], groups: [DuplicateGroup] = [], total = 0
        for (index,line) in source.enumerated() {
            let display = options.trim ? line.trimmingCharacters(in: .whitespacesAndNewlines) : line
            if options.ignoreEmpty && display.isEmpty { continue }
            let key = options.ignoreCase ? display.lowercased() : display
            total += 1
            if let existing = indices[key] { groups[existing].lineNumbers.append(index + 1) }
            else { indices[key] = groups.count; groups.append(DuplicateGroup(value: display, lineNumbers: [index + 1])) }
        }
        let repeated = groups.filter { $0.lineNumbers.count > 1 }
        return DuplicateResult(lines: source.count, total: total, unique: groups.count, extra: repeated.reduce(0) { $0 + $1.lineNumbers.count - 1 }, groups: repeated)
    }
}
