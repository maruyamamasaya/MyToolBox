import Foundation

public enum SmallDataTools {
    public static func parse(_ text: String, delimiter: Unicode.Scalar = ",") throws -> [[String]] {
        guard text.utf8.count <= 524_288 else { throw ToolFailure.message("小さな表向けです。入力は512KiB以内にしてください。") }
        let rows = try CSVDocument.parse(text, delimiter: delimiter)
        guard rows.count <= 1001, (rows.first?.count ?? 0) <= 30 else { throw ToolFailure.message("最大1,000データ行・30列です。") }
        return rows
    }
    public static func tableCSV(_ data: Data) throws -> [[String]] {
        guard data.count <= 524_288 else { throw ToolFailure.message("512KiB以下のCSVを選んでください。") }
        let rows = try parse(CSVDocument.decode(data).0)
        guard rows.count <= 100 else { throw ToolFailure.message("表ビルダーは100行までです。") }
        return rows
    }
    public enum Format: String, CaseIterable { case markdown = "Markdown", html = "HTML", csv = "CSV" }
    public enum Alignment: String, CaseIterable { case left = "左揃え", center = "中央揃え", right = "右揃え" }
    public static func export(_ rows: [[String]], format: Format, header: Bool, alignment: Alignment) -> String {
        guard let first = rows.first else { return "" }
        if format == .csv { return CSVDocument.serialize(rows) }
        if format == .markdown {
            func cell(_ value: String) -> String { value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "|", with: "\\|").replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").replacingOccurrences(of: "\n", with: "<br>") }
            func row(_ values: [String]) -> String { "| " + values.map(cell).joined(separator: " | ") + " |" }
            let rule = alignment == .left ? ":---" : alignment == .center ? ":---:" : "---:"
            return ([row(header ? first : Array(repeating: "", count: first.count)), row(Array(repeating: rule, count: first.count))] + (header ? Array(rows.dropFirst()) : rows).map(row)).joined(separator: "\n")
        }
        func escape(_ value: String) -> String { value.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;") }
        let align = alignment == .left ? "left" : alignment == .center ? "center" : "right"
        func row(_ values: [String], tag: String) -> String { "  <tr>" + values.map { "<\(tag) style=\"text-align: \(align)\">\(escape($0))</\(tag)>" }.joined() + "</tr>" }
        let heading = header ? "<thead>\n" + row(first, tag: "th") + "\n</thead>\n" : ""
        return "<table>\n" + heading + "<tbody>\n" + (header ? Array(rows.dropFirst()) : rows).map { row($0, tag: "td") }.joined(separator: "\n") + "\n</tbody>\n</table>"
    }
    public struct Column: Sendable {
        public let name: String, type: String, mode: String?
        public let nulls: Int, unique: Int, count: Int
        public let sum: Double?, mean: Double?, median: Double?, minimum: Double?, maximum: Double?
    }
    public struct Statistics: Sendable {
        public let rows: Int, duplicates: Int, columns: [Column]
        public var nulls: Int { columns.reduce(0) { $0 + $1.nulls } }
    }
    public static func statistics(_ rows: [[String]], header: Bool, nullTokens: String) throws -> Statistics {
        let width = rows.first?.count ?? 0
        let data = header ? Array(rows.dropFirst()) : rows
        guard data.count <= 1000, width <= 30 else { throw ToolFailure.message("最大1,000データ行・30列です。") }
        let tokens = Set(([""] + nullTokens.components(separatedBy: ",")).map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        var seen = Set<[String]>(), duplicates = 0
        for row in data { if !seen.insert(row).inserted { duplicates += 1 } }
        let columns = try (0..<width).map { index -> Column in
            let values = data.map { $0.indices.contains(index) ? $0[index].trimmingCharacters(in: .whitespacesAndNewlines) : "" }
            let present = values.filter { !tokens.contains($0.lowercased()) }
            var counts: [String: Int] = [:], mode: String?, best = 0
            for value in present { counts[value, default: 0] += 1; if counts[value]! > best { best = counts[value]!; mode = value } }
            let numbers = present.compactMap { Double($0).flatMap { $0.isFinite ? $0 : nil } }.sorted()
            let numeric = !present.isEmpty && numbers.count == present.count
            let type = present.isEmpty ? "空" : numeric ? "数値" : present.allSatisfy { ["true", "false"].contains($0.lowercased()) } ? "真偽値" : "文字列"
            var sum: Double?, mean: Double?, median: Double?
            if numeric {
                let total = numbers.reduce(0, +)
                guard total.isFinite else { throw ToolFailure.message("数値が大きすぎて合計を計算できません。") }
                sum = total; mean = total / Double(numbers.count)
                let middle = numbers.count / 2
                median = numbers.count % 2 == 1 ? numbers[middle] : numbers[middle - 1] / 2 + numbers[middle] / 2
            }
            return Column(name: header ? rows[0][index] : "列\(index + 1)", type: type, mode: mode, nulls: values.count - present.count, unique: counts.count, count: present.count, sum: sum, mean: mean, median: median, minimum: numeric ? numbers.first : nil, maximum: numeric ? numbers.last : nil)
        }
        return Statistics(rows: data.count, duplicates: duplicates, columns: columns)
    }
}
