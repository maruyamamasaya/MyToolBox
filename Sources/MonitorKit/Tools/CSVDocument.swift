import Foundation

public enum ToolFailure: LocalizedError {
    case message(String)
    public var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}
public enum CSVDocument {
    public static func parse(_ input: String, delimiter: Unicode.Scalar = ",") throws -> [[String]] {
        guard input.utf8.count <= 8 * 1024 * 1024 else { throw ToolFailure.message("8MiB以下のCSVを指定してください") }
        var text = input
        if text.first == "\u{FEFF}" { text.removeFirst() }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ToolFailure.message("CSVを入力してください") }
        var rows: [[String]] = [], row: [String] = [], field = ""
        var quoted = false, closed = false, skipLF = false, atRecordEnd = false
        func finishField() { row.append(field); field = ""; closed = false }
        func finishRow() throws {
            finishField(); rows.append(row); row = []
            if rows.count > 20_000 { throw ToolFailure.message("最大20,000行です") }
        }
        for scalar in text.unicodeScalars {
            if skipLF { skipLF = false; if scalar == "\n" { continue } }
            atRecordEnd = false
            if quoted {
                if scalar == "\"" { quoted = false; closed = true }
                else { field.unicodeScalars.append(scalar) }
                continue
            }
            if closed && scalar == "\"" { field.append("\""); quoted = true; closed = false; continue }
            if scalar == delimiter { finishField() }
            else if scalar == "\n" || scalar == "\r" {
                try finishRow(); skipLF = scalar == "\r"; atRecordEnd = true
            } else if scalar == "\"", field.isEmpty, !closed { quoted = true }
            else {
                guard !closed, scalar != "\"" else { throw ToolFailure.message("引用符の位置が不正です") }
                field.unicodeScalars.append(scalar)
            }
            if row.count > 200 { throw ToolFailure.message("最大200列です") }
        }
        guard !quoted else { throw ToolFailure.message("閉じていない引用符があります") }
        if !atRecordEnd { try finishRow() }
        let width = rows.map(\.count).max() ?? 0
        guard width <= 200, width * rows.count <= 200_000 else { throw ToolFailure.message("最大200列・200,000セルです") }
        return rows.map { $0 + Array(repeating: "", count: width - $0.count) }
    }
    public static func serialize(_ rows: [[String]]) -> String {
        rows.map { row in row.map { value in
            value.isEmpty || value.rangeOfCharacter(from: CharacterSet(charactersIn: ",\"\r\n")) != nil ? "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : value
        }.joined(separator: ",") }.joined(separator: "\r\n")
    }
    public static func encoded(_ rows: [[String]]) throws -> Data {
        guard rows.count <= 20_000, (rows.map(\.count).max() ?? 0) <= 200, rows.reduce(0, { $0 + $1.count }) <= 200_000 else { throw ToolFailure.message("保存できる表の上限を超えています") }
        let data = Data(("\u{FEFF}" + serialize(rows)).utf8)
        guard data.count <= 8 * 1024 * 1024 else { throw ToolFailure.message("保存結果が8MiBを超えます。データを減らしてください") }
        return data
    }
    public static func decode(_ data: Data) throws -> (String, String) {
        guard data.count <= 8 * 1024 * 1024 else { throw ToolFailure.message("8MiB以下のCSVを指定してください") }
        if let s = String(data: data, encoding: .utf8) { return (s, "UTF-8") }
        if let s = String(data: data, encoding: .shiftJIS) { return (s, "Shift_JIS") }
        throw ToolFailure.message("UTF-8またはShift_JISとして読み取れません")
    }
}
