import Foundation
public enum StringReplacer {
    public enum Mode: String, CaseIterable, Sendable { case search = "検索", replace = "置換", delete = "削除", rules = "複数置換" }
    public struct Options: Equatable, Sendable {
        public var mode: Mode = .search
        public var query = "", replacement = "", rules = "", deletionList = ""
        public var caseSensitive = false, wholeLine = false, regex = false, dotAll = false, multipleDelete = false
        public init() {}
    }
    public struct Match: Sendable { public let location: Int; public let length: Int }
    public struct Result: Sendable { public let output: String; public let count: Int; public let matches: [Match] }
    private struct Rule { let query: String; let replacement: String }
    private static func rules(_ text: String) throws -> [Rule] {
        try LineTools.lines(text).enumerated().compactMap { index,line in
            if line.trimmingCharacters(in: .whitespaces).isEmpty { return nil }
            guard let range = line.range(of: "=>") else { throw ToolFailure.message("\(index + 1)行目に「=>」がありません") }
            let query = String(line[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            guard !query.isEmpty else { throw ToolFailure.message("\(index + 1)行目の検索文字列が空です") }
            return Rule(query: query, replacement: String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces))
        }
    }
    public static func run(_ input: String, options: Options) throws -> Result {
        try TextToolLimits.input(input)
        if options.regex && input.utf8.count > 262_144 { throw ToolFailure.message("正規表現モードの入力は256KiB以下にしてください") }
        let source = TextToolLimits.normalized(input)
        let rules: [Rule]
        if options.mode == .rules { rules = try self.rules(options.rules) }
        else if options.mode == .delete && options.multipleDelete {
            rules = try LineTools.lines(options.deletionList).filter { !$0.isEmpty }.map { Rule(query: $0, replacement: "") }
        } else { rules = [Rule(query: options.query, replacement: options.mode == .delete ? "" : options.replacement)] }
        guard rules.count <= 100 else { throw ToolFailure.message("ルールは100件以内にしてください") }
        var output = source, count = 0, preview: [Match] = []
        for rule in rules {
            try Task.checkCancellation()
            guard !rule.query.isEmpty else { throw ToolFailure.message("検索する文字列を入力してください") }
            guard rule.query.utf8.count <= 4096, rule.replacement.utf8.count <= 65_536 else { throw ToolFailure.message("検索文字列は4KiB、置換文字列は64KiB以内です") }
            var flags: NSRegularExpression.Options = options.caseSensitive ? [] : [.caseInsensitive]
            if options.dotAll { flags.insert(.dotMatchesLineSeparators) }
            if options.wholeLine { flags.insert(.anchorsMatchLines) }
            let pattern = options.regex ? rule.query : NSRegularExpression.escapedPattern(for: rule.query)
            let expression: NSRegularExpression
            do { expression = try NSRegularExpression(pattern: options.wholeLine ? "^(?:" + pattern + ")$" : pattern, options: flags) }
            catch { throw ToolFailure.message("正規表現の形式が正しくありません：" + error.localizedDescription) }
            if options.regex && output.utf8.count > 262_144 { throw ToolFailure.message("正規表現の処理対象が256KiBを超えました") }
            let text = output as NSString
            let started = ProcessInfo.processInfo.systemUptime
            var timedOut = false, limit = false
            var matches: [NSTextCheckingResult] = []
            expression.enumerateMatches(in: output, options: [.reportProgress], range: NSRange(location: 0, length: text.length)) { match,_,stop in
                if ProcessInfo.processInfo.systemUptime - started > 0.25 || Task.isCancelled { timedOut = true; stop.pointee = true; return }
                if let match {
                    if matches.count >= 100_000 { limit = true; stop.pointee = true }
                    else { matches.append(match) }
                }
            }
            try Task.checkCancellation()
            guard !timedOut else { throw ToolFailure.message("正規表現の処理時間上限（0.25秒）を超えました。条件や入力を小さくしてください") }
            guard !limit else { throw ToolFailure.message("一致件数が100,000件を超えます") }
            count += matches.count
            if rules.count == 1 { preview = matches.prefix(1000).map { Match(location: $0.range.location, length: $0.range.length) } }
            if options.mode == .search { continue }
            var parts: [String] = [], cursor = 0, bytes = 0
            func append(_ value: String) throws {
                bytes += value.utf8.count
                guard bytes <= 4_194_304 else { throw ToolFailure.message("変換結果が4MiBを超えます") }; parts.append(value)
            }
            for match in matches {
                try append(text.substring(with: NSRange(location: cursor, length: match.range.location - cursor)))
                try append(options.regex ? try expand(rule.replacement, match: match, source: text) : rule.replacement)
                cursor = NSMaxRange(match.range)
            }
            try append(text.substring(from: cursor)); output = parts.joined()
        }
        return Result(output: try TextToolLimits.output(output), count: count, matches: preview)
    }
    /// JavaScript-compatible common replacement tokens; literal mode never expands dollars.
    private static func expand(_ template: String, match: NSTextCheckingResult, source: NSString) throws -> String {
        let chars = Array(template); var result = "", i = 0, bytes = 0
        func add(_ value: String) throws {
            bytes += value.utf8.count
            guard bytes <= 4_194_304 else { throw ToolFailure.message("置換結果が4MiBを超えます") }; result += value
        }
        while i < chars.count {
            guard chars[i] == "$", i + 1 < chars.count else { try add(String(chars[i])); i += 1; continue }
            let next = chars[i + 1]
            switch next {
            case "$": try add("$"); i += 2
            case "&": try add(source.substring(with: match.range)); i += 2
            case "`": try add(source.substring(to: match.range.location)); i += 2
            case "'": try add(source.substring(from: NSMaxRange(match.range))); i += 2
            default:
                if let first = next.wholeNumberValue, next.isASCII, first > 0 {
                    var group = first, consumed = 2
                    if i + 2 < chars.count, let second = chars[i + 2].wholeNumberValue, chars[i + 2].isASCII, first * 10 + second < match.numberOfRanges { group = first * 10 + second; consumed = 3 }
                    if group < match.numberOfRanges {
                        let range = match.range(at: group)
                        if range.location != NSNotFound { try add(source.substring(with: range)) }
                        i += consumed; continue
                    }
                }
                try add("$"); i += 1
            }
        }
        return result
    }
}
