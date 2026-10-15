import Foundation
import CryptoKit

public enum TextHash {
    public enum Algorithm: String, CaseIterable, Sendable { case sha256 = "SHA-256", sha1 = "SHA-1", sha384 = "SHA-384", sha512 = "SHA-512" }
    public static func generate(_ text: String, algorithm: Algorithm, base64: Bool) throws -> String {
        try TextToolLimits.input(text)
        let input = Data(text.utf8)
        let digest: Data
        switch algorithm {
        case .sha1: digest = Data(Insecure.SHA1.hash(data: input))
        case .sha256: digest = Data(SHA256.hash(data: input))
        case .sha384: digest = Data(SHA384.hash(data: input))
        case .sha512: digest = Data(SHA512.hash(data: input))
        }
        return base64 ? digest.base64EncodedString() : digest.map { String(format: "%02x", $0) }.joined()
    }
}

public enum TestDataGenerator {
    public enum Kind: String, CaseIterable, Sendable {
        case ja = "日本語", en = "英語", alphanumeric = "英数字", number = "数字", alpha = "英字", symbols = "記号入り", email = "メール風", url = "URL風", ip = "IP風", filename = "ファイル名風"
    }
    public enum ColumnType: String, CaseIterable, Sendable {
        case number = "Number", text = "Text", name = "Name", email = "Email", date = "Date", boolean = "Boolean", status = "Status", prefecture = "Prefecture", price = "Price", id = "ID"
    }
    public struct Column: Sendable {
        public var name: String
        public var type: ColumnType
        public init(_ name: String, _ type: ColumnType) { self.name = name; self.type = type }
    }
    public static let defaultColumns: [Column] = [.init("id", .number), .init("name", .name), .init("email", .email), .init("status", .status), .init("createdAt", .date), .init("enabled", .boolean), .init("prefecture", .prefecture), .init("price", .price), .init("code", .id), .init("note", .text)]
    private static func pick(_ values: [String]) -> String { values.randomElement()! }
    private static func chars(_ pool: String, _ count: Int) -> String {
        let values = Array(pool); return String((0..<count).map { _ in values.randomElement()! })
    }
    private static let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
    private static let digits = "0123456789"
    private static func word() -> String { pick(["sample", "testing", "project", "system", "account", "order", "update", "preview"]) }
    private static func sentence(english: Bool) -> String {
        if english { return pick(["The user profile", "The order data", "The system settings", "This sample record", "The test environment"]) + " " + pick(["was updated successfully.", "is ready for review.", "has been created.", "is being validated."]) }
        return pick(["ユーザー情報", "注文データ", "システム設定", "テスト環境", "アカウント", "商品情報"]) + pick(["を確認しています。", "を更新しました。", "の登録が完了しました。", "をテストしています。"])
    }
    public static func sentences(count: Int, length: Int, language: String) throws -> String {
        guard (1...10).contains(count), (0...2).contains(length) else { throw ToolFailure.message("文章数は1〜10です") }
        return (0..<count).map { _ in
            let english = language == "en"
            var value = sentence(english: english)
            if length > 0 { value += english ? " Please use it to verify the development workflow." : " 開発環境での動作確認に使用できます。" }
            if length > 1 { value += english ? " This sample content can be replaced after development is complete." : " この文章はテスト用サンプルとして生成され、開発完了後に置き換えることができます。" }
            if language == "mixed" { value += " [\(word())-\(Int.random(in: 100...999))]" }
            return value
        }.joined(separator: "\n")
    }
    public static func text(kind: Kind, length: Int, count: Int, separator: String) throws -> String {
        guard (1...10000).contains(length), (1...1000).contains(count), length * count <= 1_000_000, separator.utf8.count <= 4 else { throw ToolFailure.message("1件1〜10,000文字・1〜1,000件、合計100万文字以内です") }
        var rows: [String] = []
        for _ in 0..<count {
            try Task.checkCancellation()
            var value: String
            switch kind {
            case .alphanumeric: value = chars(letters + digits, length)
            case .number: value = chars(digits, length)
            case .alpha: value = chars(letters, length)
            case .symbols: value = chars(letters + digits + "!@#$%&*+-_=?.", length)
            case .ja, .en:
                value = ""
                while value.count < length { value += sentence(english: kind == .en) }
            default:
                func structured() -> String {
                    switch kind {
                    case .email: return "\(word()).\(chars(digits, 5))@example.com"
                    case .url: return "https://example.com/\(word())/\(chars(digits, 6))"
                    case .ip: return "192.0.2.\(Int.random(in: 1...254))"
                    default: return "\(word())_\(chars(digits, 4)).\(pick(["txt", "csv", "json", "log", "md", "png"]))"
                    }
                }
                value = structured()
                while value.count < length { value += "-" + structured() }
            }
            rows.append(String(value.prefix(length)))
        }
        return try TextToolLimits.output(rows.joined(separator: separator))
    }
    public static func uuids(count: Int) throws -> [String] {
        guard (1...100).contains(count) else { throw ToolFailure.message("UUIDは1〜100個です") }
        return (0..<count).map { _ in UUID().uuidString.lowercased() }
    }
    public static func csv(columns: [Column], count: Int) throws -> String {
        guard (1...10).contains(columns.count), (1...10).contains(count), columns.allSatisfy({ $0.name.utf8.count <= 1024 }) else { throw ToolFailure.message("CSVは1〜10列・1〜10行、列名は各1,024バイト以内です") }
        var rows = [columns.enumerated().map { $0.element.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "column_\($0.offset + 1)" : $0.element.name }]
        for i in 1...count {
            rows.append(columns.map { column in
                switch column.type {
                case .number: return String(i)
                case .text: return "\(word()) \(word()), \(i)"
                case .name: return pick(["田中", "佐藤", "鈴木", "高橋", "伊藤", "渡辺", "山本", "中村"]) + pick(["太郎", "花子", "一郎", "美咲", "健太", "さくら", "直樹", "結衣"])
                case .email: return "user\(i)@example.com"
                case .date:
                    let day = Int.random(in: 0..<1096)
                    return Date(timeIntervalSince1970: 1_704_067_200 + Double(day * 86400)).formatted(.iso8601.year().month().day().dateSeparator(.dash))
                case .boolean: return Bool.random() ? "true" : "false"
                case .status: return pick(["active", "inactive", "pending", "completed"])
                case .prefecture: return pick(["北海道", "東京都", "神奈川県", "愛知県", "京都府", "大阪府", "福岡県", "沖縄県"])
                case .price: return String(Int.random(in: 1...1000) * 100)
                case .id: return String(format: "ID-%06d", Int.random(in: 0...999998))
                }
            })
        }
        return try TextToolLimits.output(CSVDocument.serialize(rows))
    }
}
