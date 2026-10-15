import Foundation

public enum RegexWorkbench {
    public struct Match: Sendable {
        public let range: NSRange
        public let groups: [String?]
    }
    public struct Output: Sendable {
        public let matches: [Match]
        public let replacement: String
    }
    public static func test(_ text: String, pattern: String, replacement: String = "", all: Bool = true, ignoreCase: Bool = false, multiline: Bool = false, dotAll: Bool = false) throws -> Output {
        guard text.utf8.count <= 65_536, pattern.utf8.count <= 4096, replacement.utf8.count <= 4096 else { throw ToolFailure.message("本文は64KiB、パターン・置換は4KiB以内にしてください。") }
        var options: NSRegularExpression.Options = []
        if ignoreCase { options.insert(.caseInsensitive) }; if multiline { options.insert(.anchorsMatchLines) }; if dotAll { options.insert(.dotMatchesLineSeparators) }
        let regex = try NSRegularExpression(pattern: pattern, options: options)
        let source = text as NSString, start = ProcessInfo.processInfo.systemUptime
        var found: [NSTextCheckingResult] = [], exceeded = false
        regex.enumerateMatches(in: text, options: [.reportProgress], range: NSRange(location: 0, length: source.length)) { match, _, stop in
            if Task.isCancelled || ProcessInfo.processInfo.systemUptime - start > 0.25 { exceeded = true; stop.pointee = true; return }
            if let match {
                if found.count >= 1000 { exceeded = true; stop.pointee = true; return }
                found.append(match)
                if !all { stop.pointee = true }
            }
        }
        guard !exceeded else { throw ToolFailure.message("時間上限（0.25秒）または一致上限（1,000件）を超えました。条件を絞ってください。") }
        var result = "", cursor = 0
        for match in found {
            result += source.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            result += regex.replacementString(for: match, in: text, offset: 0, template: replacement)
            guard result.utf8.count <= 1_048_576 else { throw ToolFailure.message("置換結果は1MiB以内にしてください。") }
            cursor = NSMaxRange(match.range)
        }
        result += source.substring(from: cursor)
        return Output(matches: found.map { match in
            Match(range: match.range, groups: (0..<match.numberOfRanges).map { index in
                let range = match.range(at: index); return range.location == NSNotFound ? nil : source.substring(with: range)
            })
        }, replacement: result)
    }
    public enum PartKind: String, CaseIterable, Sendable {
        case digit = "数字", letter = "英字", alnum = "英数字", literal = "固定文字", space = "空白", nonspace = "空白以外", any = "任意の文字", word = "単語文字", nonword = "単語文字以外", characterClass = "文字クラス", group = "グループ", either = "ORグループ"
    }
    public enum Repetition: String, CaseIterable, Sendable {
        case one = "1回", optional = "0〜1回", zeroMore = "0回以上", oneMore = "1回以上", exact = "指定回数", range = "範囲指定", atLeast = "最低回数"
    }
    public struct Part: Identifiable, Sendable {
        public let id = UUID()
        public var kind: PartKind = .digit
        public var value = "", alternative = "", negate = false, capture = true
        public var repetition: Repetition = .one
        public var minimum = 1, maximum = 5
        public init() {}
        public func pattern() throws -> String {
            let escaped = NSRegularExpression.escapedPattern(for: value)
            let base: String
            switch kind {
            case .digit: base = "[0-9]"
            case .letter: base = "[A-Za-z]"
            case .alnum: base = "[A-Za-z0-9]"
            case .literal: base = "(?:" + escaped + ")"
            case .space: base = "\\s"
            case .nonspace: base = "\\S"
            case .any: base = "."
            case .word: base = "\\w"
            case .nonword: base = "\\W"
            case .characterClass: base = "[" + (negate ? "^" : "") + value + "]"
            case .group: base = (capture ? "(" : "(?:") + escaped + ")"
            case .either: base = "(?:" + escaped + "|" + NSRegularExpression.escapedPattern(for: alternative) + ")"
            }
            guard (0...1000).contains(minimum), (minimum...1000).contains(maximum) else { throw ToolFailure.message("回数は0〜1,000、最大回数は最小回数以上にしてください。") }
            let suffix: String
            switch repetition {
            case .one: suffix = ""
            case .optional: suffix = "?"
            case .zeroMore: suffix = "*"
            case .oneMore: suffix = "+"
            case .exact: suffix = "{\(minimum)}"
            case .range: suffix = "{\(minimum),\(maximum)}"
            case .atLeast: suffix = "{\(minimum),}"
            }
            return base + suffix
        }
    }
    public static func build(_ parts: [Part], start: Bool, end: Bool) throws -> String {
        guard parts.count <= 40 else { throw ToolFailure.message("条件は40個までです。") }
        let pattern = (start ? "^" : "") + (try parts.map { try $0.pattern() }.joined()) + (end ? "$" : "")
        guard pattern.utf8.count <= 4096 else { throw ToolFailure.message("パターンは4KiB以内にしてください。") }
        _ = try NSRegularExpression(pattern: pattern)
        return pattern
    }
}
