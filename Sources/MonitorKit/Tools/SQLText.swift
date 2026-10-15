import Foundation

public enum SQLToolError: LocalizedError {
    case invalid(String)
    public var errorDescription: String? { switch self { case .invalid(let message): return message } }
}

/// A small lexer, not a dialect-specific SQL parser. Quoted content is never rewritten.
public enum SQLText {
    public enum Kind { case word, quoted, comment, whitespace, symbol }
    public struct Token {
        public let text: String
        public let kind: Kind
        public let depth: Int
        var upper: String { text.uppercased() }
    }
    private static let keywords = Set("SELECT FROM WHERE GROUP BY HAVING ORDER LIMIT OFFSET JOIN INNER LEFT RIGHT FULL OUTER CROSS ON USING AS DISTINCT ALL UNION EXCEPT INTERSECT INSERT INTO VALUES UPDATE SET DELETE RETURNING CREATE TABLE VIEW INDEX ALTER DROP IF EXISTS NOT NULL IS IN LIKE BETWEEN AND OR ASC DESC CASE WHEN THEN ELSE END WITH RECURSIVE OVER PARTITION PRIMARY KEY FOREIGN REFERENCES DEFAULT UNIQUE CHECK CONSTRAINT TRUE FALSE COUNT SUM AVG MIN MAX CAST INTEGER TEXT REAL BLOB NUMERIC BOOLEAN".split(separator: " ").map(String.init))
    private static let clauses = ["GROUP BY", "ORDER BY", "LEFT OUTER JOIN", "RIGHT OUTER JOIN", "FULL OUTER JOIN", "INNER JOIN", "LEFT JOIN", "RIGHT JOIN", "FULL JOIN", "CROSS JOIN", "INSERT INTO", "DELETE FROM", "UNION ALL", "SELECT", "FROM", "WHERE", "HAVING", "LIMIT", "OFFSET", "JOIN", "ON", "USING", "VALUES", "UPDATE", "SET", "RETURNING", "UNION", "EXCEPT", "INTERSECT"]

    public static func tokens(_ sql: String) throws -> [Token] {
        guard sql.utf8.count <= 200_000 else { throw SQLToolError.invalid("SQLは200 KB以内にしてください。") }
        guard !sql.contains("\0") else { throw SQLToolError.invalid("SQLにNUL文字は使用できません。") }
        let chars = Array(sql.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n"))
        var result: [Token] = [], i = 0, depth = 0
        func word(_ c: Character) -> Bool { c.isLetter || c.isNumber || c == "_" || c == "$" }
        while i < chars.count {
            let start = i, tokenDepth = depth
            let kind: Kind
            let c = chars[i]
            if c.isWhitespace {
                kind = .whitespace; i += 1
                while i < chars.count && chars[i].isWhitespace { i += 1 }
            } else if c == "-", i + 1 < chars.count, chars[i + 1] == "-" {
                kind = .comment; i += 2
                while i < chars.count && chars[i] != "\n" { i += 1 }
            } else if c == "/", i + 1 < chars.count, chars[i + 1] == "*" {
                kind = .comment; i += 2; var nesting = 1
                while i < chars.count && nesting > 0 {
                    if i + 1 < chars.count && chars[i] == "/" && chars[i + 1] == "*" { nesting += 1; i += 2 }
                    else if i + 1 < chars.count && chars[i] == "*" && chars[i + 1] == "/" { nesting -= 1; i += 2 }
                    else { i += 1 }
                }
                guard nesting == 0 else { throw SQLToolError.invalid("ブロックコメントが閉じていません。") }
            } else if c == "'" || c == "\"" || c == "`" || c == "[" {
                kind = .quoted; let close: Character = c == "[" ? "]" : c
                i += 1; var closed = false
                while i < chars.count {
                    if chars[i] == close {
                        i += 1
                        if i < chars.count && chars[i] == close { i += 1; continue }
                        closed = true; break
                    }
                    // Keep backslash escapes intact without interpreting their dialect-specific meaning.
                    if chars[i] == "\\" && i + 1 < chars.count { i += 2 } else { i += 1 }
                }
                guard closed else { throw SQLToolError.invalid("引用符が閉じていません。") }
            } else if c == "$", let end = dollarEnd(chars, start: i) {
                kind = .quoted
                let marker = Array(chars[i...end]); i = end + 1; var closed = false
                while i + marker.count <= chars.count {
                    if Array(chars[i..<(i + marker.count)]) == marker { i += marker.count; closed = true; break }
                    i += 1
                }
                guard closed else { throw SQLToolError.invalid("ドル引用符が閉じていません。") }
            } else if (c == ":" || c == "@" || c == "$") && i + 1 < chars.count && (chars[i + 1].isLetter || chars[i + 1] == "_") {
                kind = .quoted; i += 2
                while i < chars.count && word(chars[i]) { i += 1 }
            } else if word(c) {
                kind = .word; i += 1
                while i < chars.count && word(chars[i]) { i += 1 }
            } else {
                kind = .symbol; i += 1
                if c == "(" { depth += 1 }
                if c == ")" { depth -= 1 }
                guard depth >= 0, depth <= 64 else { throw SQLToolError.invalid("括弧の対応または深さ（最大64）を確認してください。") }
            }
            result.append(Token(text: String(chars[start..<i]), kind: kind, depth: tokenDepth))
        }
        guard depth == 0 else { throw SQLToolError.invalid("括弧が閉じていません。") }
        return result
    }
    private static func dollarEnd(_ chars: [Character], start: Int) -> Int? {
        var i = start + 1
        while i < chars.count && (chars[i].isLetter || chars[i].isNumber || chars[i] == "_") { i += 1 }
        return i < chars.count && chars[i] == "$" ? i : nil
    }
    private static func clause(at index: Int, in tokens: [Token]) -> (name: String, end: Int)? {
        guard tokens[index].kind == .word else { return nil }
        for name in clauses {
            var cursor = index, end = index, found = true
            for word in name.split(separator: " ") {
                if cursor >= tokens.count || tokens[cursor].kind != .word || tokens[cursor].upper != word { found = false; break }
                end = cursor; cursor += 1
                while cursor < tokens.count && tokens[cursor].kind == .whitespace { cursor += 1 }
            }
            if found { return (name, end) }
        }
        return nil
    }
    public static func format(_ sql: String, uppercase: Bool = true) throws -> String {
        let items = try tokens(sql)
        var output = "", i = 0
        func newline(_ depth: Int) {
            while output.last == " " || output.last == "\t" { output.removeLast() }
            if !output.isEmpty && !output.hasSuffix("\n") { output += "\n" }
            output += String(repeating: "  ", count: min(64, max(0, depth)))
        }
        while i < items.count {
            let item = items[i]
            if item.kind == .whitespace {
                if !output.isEmpty && !output.hasSuffix("\n") && !output.hasSuffix(" ") { output += " " }
            } else if item.kind == .comment {
                output += item.text
                // A line comment must always end at a newline, even in compact input.
                newline(item.depth)
            } else if item.kind == .word {
                if let phrase = clause(at: i, in: items) {
                    newline(item.depth)
                    output += uppercase ? phrase.name : phrase.name.lowercased(); i = phrase.end
                } else { output += keywords.contains(item.upper) ? (uppercase ? item.upper : item.upper.lowercased()) : item.text }
            } else {
                output += item.text
                if item.text == "," && item.depth == 0 { newline(1) }
                if item.text == ";" && item.depth == 0 { newline(0) }
            }
            i += 1
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public struct Explanation: Equatable, Sendable {
        public let title: String
        public let source: String
        public let meaning: String
    }
    public static func explain(_ sql: String) throws -> [Explanation] {
        let items = try tokens(sql).filter { $0.kind != .comment && $0.kind != .whitespace }
        guard let first = items.first, first.kind == .word, first.upper == "SELECT" else {
            throw SQLToolError.invalid("説明は単一のSELECT文が対象です。WITH・更新系SQLには対応していません。")
        }
        let semicolons = items.indices.filter { items[$0].text == ";" }
        guard semicolons.isEmpty || (semicolons.count == 1 && semicolons[0] == items.count - 1) else { throw SQLToolError.invalid("説明するSELECT文は1つにしてください。") }
        guard !items.contains(where: { $0.kind == .word && (["UNION", "EXCEPT", "INTERSECT", "OVER", "WINDOW", "INTO"].contains($0.upper) || ($0.depth > 0 && $0.upper == "SELECT")) }) else {
            throw SQLToolError.invalid("集合演算・サブクエリ・ウィンドウ関数・SELECT INTOの説明は未対応です。")
        }
        var sections: [Explanation] = [], i = 0
        let meanings: [String: String] = [
            "SELECT": "取得する列や計算式です。*は全列、DISTINCTは結果の重複を除きます。",
            "FROM": "データの取得元となるテーブルです。ASで別名を付けられます。",
            "WHERE": "集計前に、条件が真になる行を絞り込みます。",
            "GROUP BY": "指定した列・式が同じ行をまとめて集計します。",
            "HAVING": "GROUP BYなどで集計した後の結果を条件で絞り込みます。",
            "ORDER BY": "結果を並べ替えます。ASCは昇順、DESCは降順です。",
            "LIMIT": "返す行数の上限を指定します。方言によって書式が異なります。",
            "OFFSET": "先頭から指定した行数を読み飛ばします。",
            "ON": "テーブルを結合する条件です。", "USING": "両テーブルに同名で存在する結合列を指定します。"
        ]
        while i < items.count {
            guard items[i].depth == 0, let phrase = clause(at: i, in: items) else { i += 1; continue }
            let start = phrase.end + 1; var end = start
            while end < items.count && items[end].text != ";" {
                if items[end].depth == 0 && clause(at: end, in: items) != nil { break }
                end += 1
            }
            guard start < end else { throw SQLToolError.invalid("\(phrase.name)の後の内容を確認してください。") }
            let meaning: String
            if phrase.name.contains("JOIN") {
                if phrase.name.hasPrefix("LEFT") { meaning = "左側の全行を残して結合します。一致しない右側の列はNULLになります。" }
                else if phrase.name.hasPrefix("RIGHT") { meaning = "右側の全行を残して結合します。一致しない左側の列はNULLになります。" }
                else if phrase.name.hasPrefix("FULL") { meaning = "両側の全行を残して結合します。一致しない側の列はNULLになります。" }
                else if phrase.name.hasPrefix("CROSS") { meaning = "両テーブルの行のすべての組み合わせを返します。" }
                else { meaning = "結合条件に一致する両テーブルの行を組み合わせます。" }
            } else { meaning = meanings[phrase.name] ?? "この句の個別説明は未対応です。" }
            sections.append(Explanation(title: phrase.name, source: items[start..<end].map(\.text).joined(separator: " "), meaning: meaning))
            i = end
        }
        return sections
    }
}
