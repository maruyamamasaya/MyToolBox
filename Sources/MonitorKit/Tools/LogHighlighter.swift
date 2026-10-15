import Foundation

enum LogLevel: String, CaseIterable {
    case fatal = "FATAL", error = "ERROR", warn = "WARN", info = "INFO", debug = "DEBUG", trace = "TRACE", other = "OTHER"
    static func detect(_ text: String) -> Self {
        for (level, pattern) in patterns where pattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil { return level }
        return .other
    }
    private static let patterns: [(LogLevel, NSRegularExpression)] = [
        (.fatal, "FATAL|CRITICAL"), (.error, "ERROR"), (.warn, "WARN|WARNING"),
        (.info, "INFO"), (.debug, "DEBUG"), (.trace, "TRACE")
    ].compactMap { level, words in
        guard let regex = try? NSRegularExpression(pattern: "\\b(?:\(words))\\b", options: .caseInsensitive) else { return nil }
        return (level, regex)
    }
}

struct LogEntry: Identifiable {
    let id: Int
    let text: String
    let level: LogLevel
}

enum LogHighlighter {
    static func parse(_ text: String) -> [LogEntry] {
        guard !text.isEmpty else { return [] }
        return text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n").enumerated().map { LogEntry(id: $0.offset + 1, text: $0.element, level: .detect($0.element)) }
    }
    static func visible(_ lines: [LogEntry], levels: Set<LogLevel>, context: Int) -> [LogEntry] {
        let radius = min(10, max(0, context))
        var indexes = Set<Int>()
        for index in lines.indices where levels.contains(lines[index].level) {
            for nearby in max(0, index - radius)...min(lines.count - 1, index + radius) { indexes.insert(nearby) }
        }
        return indexes.sorted().map { lines[$0] }
    }
    static func matches(_ text: String, query: String) -> [NSRange] {
        guard !query.isEmpty, let regex = try? NSRegularExpression(pattern: NSRegularExpression.escapedPattern(for: query), options: .caseInsensitive) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).map(\.range)
    }
}
