import Foundation

public enum TextComparison {
    public enum Kind: String, Sendable { case same = "同一", changed = "変更", removed = "削除", added = "追加" }
    /// UTF-16 offsets for native attributed text; boundaries are extended by whole graphemes.
    public struct Span: Equatable, Sendable { public let location: Int; public let length: Int }
    public struct Row: Identifiable, Sendable {
        public let id: Int
        public let kind: Kind
        public let left: String?, right: String?
        public let leftNumber: Int?, rightNumber: Int?
        public let leftSpan: Span?, rightSpan: Span?
    }
    public struct Result: Sendable {
        public let rows: [Row]
        public var changed: Int { rows.filter { $0.kind == .changed }.count }
        public var removed: Int { rows.filter { $0.kind == .removed }.count }
        public var added: Int { rows.filter { $0.kind == .added }.count }
        public var same: Int { rows.filter { $0.kind == .same }.count }
        public var plainText: String {
            rows.map { row in
                switch row.kind {
                case .same: return "  " + (row.left ?? "")
                case .removed: return "- " + (row.left ?? "")
                case .added: return "+ " + (row.right ?? "")
                case .changed: return "- " + (row.left ?? "") + "\n+ " + (row.right ?? "")
                }
            }.joined(separator: "\n")
        }
    }
    private struct Profile {
        let text: String
        let characters: [Character]
        let words: Set<String>
        init(_ value: String) {
            text = value; characters = Array(value)
            words = Set(value.split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "_" }).map(String.init))
        }
    }
    private struct Budget {
        let start = ProcessInfo.processInfo.systemUptime
        func check() throws {
            try Task.checkCancellation()
            guard ProcessInfo.processInfo.systemUptime - start < 2 else { throw ToolFailure.message("比較の処理時間上限（約2秒）を超えました。入力を小さくしてください") }
        }
    }
    public static func split(_ text: String) -> [String] { text.isEmpty ? [] : TextToolLimits.normalized(text).components(separatedBy: "\n") }
    public static func changedSpans(_ left: String, _ right: String) -> (Span, Span) {
        let a = Array(left), b = Array(right); let common = min(a.count,b.count)
        var first = 0, suffix = 0
        while first < common && a[first] == b[first] { first += 1 }
        while suffix < common - first && a[a.count - suffix - 1] == b[b.count - suffix - 1] { suffix += 1 }
        func word(_ value: Character) -> Bool { value.isLetter || value.isNumber || value == "_" }
        var aEnd = a.count - suffix, bEnd = b.count - suffix
        if first > 0 && ((first < a.count && word(a[first - 1]) && word(a[first])) || (first < b.count && word(b[first - 1]) && word(b[first]))) {
            while first > 0 && (word(a[first - 1]) || word(b[first - 1])) { first -= 1 }
        }
        while aEnd < a.count && word(a[aEnd]) { aEnd += 1 }
        while bEnd < b.count && word(b[bEnd]) { bEnd += 1 }
        func span(_ characters: [Character], end: Int) -> Span {
            let location = String(characters.prefix(first)).utf16.count
            return Span(location: location, length: String(characters[first..<end]).utf16.count)
        }
        return (span(a, end: aEnd), span(b, end: bEnd))
    }
    public static func compare(_ left: String, _ right: String) throws -> Result {
        guard left.utf8.count <= 262_144, right.utf8.count <= 262_144 else { throw ToolFailure.message("テキスト差分は左右それぞれ256KiB以下にしてください") }
        let a = split(left), b = split(right), n = a.count, m = b.count
        guard n <= 1000, m <= 1000 else { throw ToolFailure.message("テキスト差分は左右それぞれ1,000行以下にしてください。省略せずに比較するため、入力を分けてください") }
        let budget = Budget()
        let profilesA = a.map(Profile.init), profilesB = b.map(Profile.init)
        // Intern each line once, so the quadratic LCS loop only compares integer IDs.
        var identifiers: [String: Int] = [:]
        func identifier(_ text: String) -> Int { if let id = identifiers[text] { return id }; let id = identifiers.count; identifiers[text] = id; return id }
        let idsA = a.map(identifier), idsB = b.map(identifier)
        let width = m + 1
        var lcs = [UInt16](repeating: 0, count: (n + 1) * width)
        if n > 0 && m > 0 {
            for i in stride(from: n - 1, through: 0, by: -1) {
                try budget.check()
                for j in stride(from: m - 1, through: 0, by: -1) {
                    lcs[i * width + j] = idsA[i] == idsB[j] ? lcs[(i + 1) * width + j + 1] + 1 : max(lcs[(i + 1) * width + j], lcs[i * width + j + 1])
                }
            }
        }
        var rows: [Row] = [], i = 0, j = 0
        func append(_ kind: Kind, _ l: Int?, _ r: Int?) {
            let spans = kind == .changed ? changedSpans(a[l!], b[r!]) : nil
            rows.append(Row(id: rows.count, kind: kind, left: l.map { a[$0] }, right: r.map { b[$0] }, leftNumber: l.map { $0 + 1 }, rightNumber: r.map { $0 + 1 }, leftSpan: spans?.0, rightSpan: spans?.1))
        }
        while i < n || j < m {
            try budget.check()
            if i < n && j < m && idsA[i] == idsB[j] { append(.same,i,j); i += 1; j += 1; continue }
            var removed: [Int] = [], added: [Int] = []
            while (i < n || j < m) && !(i < n && j < m && idsA[i] == idsB[j]) {
                if j >= m || (i < n && lcs[(i + 1) * width + j] >= lcs[i * width + j + 1]) { removed.append(i); i += 1 }
                else { added.append(j); j += 1 }
            }
            // Align changed blocks by prefix/suffix/word similarity, not by arbitrary line number.
            let rw = added.count + 1, gap = 0.72
            var costs = [Double](repeating: 0, count: (removed.count + 1) * rw)
            for x in 0...removed.count { costs[x * rw] = Double(x) * gap }
            for y in 0...added.count { costs[y] = Double(y) * gap }
            func similarity(_ l: Int, _ r: Int) -> Double {
                let a = profilesA[l], b = profilesB[r]
                if a.text == b.text { return 1 }
                let length = max(a.characters.count,b.characters.count)
                if length == 0 { return 1 }
                let common = min(a.characters.count,b.characters.count)
                var prefix = 0, suffix = 0
                while prefix < common && a.characters[prefix] == b.characters[prefix] { prefix += 1 }
                while suffix < common - prefix && a.characters[a.characters.count - 1 - suffix] == b.characters[b.characters.count - 1 - suffix] { suffix += 1 }
                let shared = a.words.intersection(b.words).reduce(0) { $0 + $1.count }
                return min(1, Double(prefix + suffix) / Double(length) + Double(shared) * 0.5 / Double(length))
            }
            if !removed.isEmpty && !added.isEmpty {
                for x in 1...removed.count {
                    try budget.check()
                    for y in 1...added.count {
                        let substitution = 1 - similarity(removed[x - 1], added[y - 1])
                        costs[x * rw + y] = min(costs[(x - 1) * rw + y] + gap, costs[x * rw + y - 1] + gap, costs[(x - 1) * rw + y - 1] + substitution)
                    }
                }
            }
            var x = removed.count, y = added.count
            var block: [(Kind,Int?,Int?)] = []
            while x > 0 || y > 0 {
                try budget.check()
                if x > 0 && y > 0 && abs(costs[x * rw + y] - costs[(x - 1) * rw + y - 1] - (1 - similarity(removed[x - 1], added[y - 1]))) < 0.000_01 {
                    x -= 1; y -= 1; block.append((.changed,removed[x],added[y]))
                } else if x > 0 && (y == 0 || costs[(x - 1) * rw + y] <= costs[x * rw + y - 1]) { x -= 1; block.append((.removed,removed[x],nil)) }
                else { y -= 1; block.append((.added,nil,added[y])) }
            }
            for (kind,l,r) in block.reversed() { append(kind,l,r) }
        }
        try budget.check()
        return Result(rows: rows)
    }
}

public enum ListComparison {
    public struct Options: Equatable, Sendable {
        public var trim = true, ignoreCase = false, ignoreEmpty = true
        public init() {}
    }
    public struct Result: Sendable {
        public let leftCount: Int, rightCount: Int
        public let common: [String], onlyLeft: [String], onlyRight: [String]
    }
    public static func compare(_ left: String, _ right: String, options: Options) throws -> Result {
        func values(_ text: String) throws -> [(String,String)] {
            let lines = try LineTools.lines(text)
            var seen: Set<String> = [], values: [(String,String)] = []
            for line in lines {
                let value = options.trim ? line.trimmingCharacters(in: .whitespacesAndNewlines) : line
                if options.ignoreEmpty && value.isEmpty { continue }
                let key = options.ignoreCase ? value.lowercased() : value
                if seen.insert(key).inserted { values.append((value,key)) }
            }
            return values
        }
        let a = try values(left), b = try values(right)
        let keysA = Set(a.map { $0.1 }), keysB = Set(b.map { $0.1 })
        return Result(leftCount: a.count, rightCount: b.count, common: a.filter { keysB.contains($0.1) }.map { $0.0 }, onlyLeft: a.filter { !keysB.contains($0.1) }.map { $0.0 }, onlyRight: b.filter { !keysA.contains($0.1) }.map { $0.0 })
    }
}
