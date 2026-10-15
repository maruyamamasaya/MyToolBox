import Foundation

public enum TextCodec {
    public enum Mode: String, CaseIterable, Sendable {
        case base64Encode = "Base64 エンコード", base64Decode = "Base64 デコード", escape = "エスケープ", restore = "復元", visualize = "可視化", inspect = "文字チェック"
    }
    public struct Result: Sendable { public let text: String; public let warning: String }
    public static func convert(_ input: String, mode: Mode) throws -> Result {
        try TextToolLimits.input(input)
        var output = "", invalid = 0
        switch mode {
        case .base64Encode: output = Data(input.utf8).base64EncodedString()
        case .base64Decode:
            let value = input.filter { !$0.isWhitespace }
            guard value.count % 4 == 0, value.range(of: "^[A-Za-z0-9+/]*={0,2}$", options: .regularExpression) != nil, let data = Data(base64Encoded: value) else { throw ToolFailure.message("Base64の形式が正しくありません") }
            guard let text = String(data: data, encoding: .utf8) else { throw ToolFailure.message("UTF-8のテキストとして復元できません") }
            output = text
        case .escape:
            let map: [Unicode.Scalar: String] = ["\n": "\\n", "\r": "\\r", "\t": "\\t", "\\": "\\\\", "\"": "\\\"", "\0": "\\0"]
            for scalar in input.unicodeScalars { output += map[scalar] ?? String(scalar) }
        case .restore:
            let map: [Unicode.Scalar: String] = ["n": "\n", "r": "\r", "t": "\t", "\\": "\\", "\"": "\"", "0": "\0"]
            var pending = false
            for scalar in input.unicodeScalars {
                if pending {
                    if let replacement = map[scalar] { output += replacement }
                    else { output += "\\" + String(scalar); invalid += 1 }
                    pending = false
                } else if scalar == "\\" { pending = true }
                else { output += String(scalar) }
            }
            if pending { output += "\\"; invalid += 1 }
        case .visualize:
            let map: [Unicode.Scalar: String] = [" ": "·", "　": "□", "\t": "→", "\r": "␍", "\n": "↵\n", "\0": "␀"]
            for scalar in input.unicodeScalars { output += map[scalar] ?? String(scalar) }
        case .inspect: output = inspect(input)
        }
        return Result(text: try TextToolLimits.output(output), warning: invalid == 0 ? "" : "解釈できないエスケープを\(invalid)件、そのまま残しました")
    }
    private static func inspect(_ text: String) -> String {
        var counts = [Int](repeating: 0, count: 5), line = 1, findings: [String] = [], totalFindings = 0
        let names: [UInt32: String] = [0xA0: "ノーブレークスペース", 0xAD: "ソフトハイフン", 0x34F: "結合書記素接合子", 0x61C: "アラビア文字マーク", 0x200B: "ゼロ幅スペース", 0x200C: "ゼロ幅非接合子", 0x200D: "ゼロ幅接合子", 0x200E: "左から右マーク", 0x200F: "右から左マーク", 0x2060: "単語結合子", 0x3000: "全角スペース", 0xFEFF: "BOM / ゼロ幅ノーブレークスペース", 0xFFFD: "Unicode置換文字"]
        // ICU script properties cover supplementary Han and kana as well as common ranges.
        let scripts = ["Hiragana", "Katakana", "Han"].map { try! NSRegularExpression(pattern: "^\\p{script=\($0)}$") }
        var newlines = 0, spaces = 0, replacements = 0
        for scalar in text.unicodeScalars {
            let value = scalar.value, character = String(scalar)
            let category = value <= 0x7F ? 0 : scripts.firstIndex { $0.firstMatch(in: character, range: NSRange(character.startIndex..., in: character)) != nil }.map { $0 + 1 } ?? 4
            counts[category] += 1
            var name = names[value]
            if (value <= 0x1F || (0x7F...0x9F).contains(value)) && ![9,10,13].contains(value) { name = "制御文字" }
            if (0x202A...0x202E).contains(value) || (0x2066...0x2069).contains(value) { name = "書字方向制御文字" }
            if (0x2061...0x2064).contains(value) { name = "不可視の演算・区切り文字" }
            if scalar.properties.generalCategory == .privateUse { name = "私用領域の文字" }
            if (0xFDD0...0xFDEF).contains(value) || value & 0xFFFF >= 0xFFFE { name = "Unicode非文字" }
            if let name { totalFindings += 1; if findings.count < 1000 { findings.append("\(line)行目  U+\(String(format: "%04X", value))  \(name)") } }
            if value == 0x3000 { spaces += 1 }; if value == 0xFFFD { replacements += 1 }
            if value == 10 { newlines += 1; line += 1 }
        }
        let labels = ["ASCII", "ひらがな", "カタカナ", "漢字", "その他 Unicode"]
        let summary = zip(labels, counts).map { "\($0): \($1)" }.joined(separator: "\n")
        return "総文字数（Unicodeスカラー）: \(counts.reduce(0,+))\n改行（LF）: \(newlines)\n全角スペース: \(spaces)\n置換文字: \(replacements)\n\n\(summary)\n\n確認対象: \(totalFindings)件\n" + (findings.isEmpty ? "確認対象の文字はありません" : findings.joined(separator: "\n")) + (totalFindings > 1000 ? "\n先頭1,000件のみ表示" : "")
    }
}
