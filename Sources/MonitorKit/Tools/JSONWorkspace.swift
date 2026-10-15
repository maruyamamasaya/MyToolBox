import Foundation

/// JSON numbers are kept as tokens, so formatting never rounds large integers.
public indirect enum JSONValue: Equatable {
    public struct Member: Equatable {
        public var key: String
        public var value: JSONValue
        public init(_ key: String, _ value: JSONValue) { self.key = key; self.value = value }
    }
    case object([Member]), array([JSONValue]), string(String), number(String), bool(Bool), null
    public var typeName: String {
        switch self {
        case .object: return "object"
        case .array: return "array"
        case .string: return "string"
        case .number: return "number"
        case .bool: return "boolean"
        case .null: return "null"
        }
    }
    public var count: Int? {
        switch self { case .object(let v): return v.count; case .array(let v): return v.count; default: return nil }
    }
    public func encoded(indent: Int? = 2, depth: Int = 0) -> String {
        func quote(_ s: String) -> String {
            let data = try! JSONSerialization.data(withJSONObject: [s], options: [.fragmentsAllowed, .withoutEscapingSlashes])
            return String(decoding: data, as: UTF8.self).dropFirst().dropLast().description
        }
        func container(_ parts: [String], _ open: String, _ close: String) -> String {
            guard !parts.isEmpty else { return open + close }
            guard let indent else { return open + parts.joined(separator: ",") + close }
            let pad = String(repeating: " ", count: indent * (depth + 1))
            return open + "\n" + pad + parts.joined(separator: ",\n" + pad) + "\n" + String(repeating: " ", count: indent * depth) + close
        }
        switch self {
        case .object(let members): return container(members.map { quote($0.key) + (indent == nil ? ":" : ": ") + $0.value.encoded(indent: indent, depth: depth + 1) }, "{", "}")
        case .array(let values): return container(values.map { $0.encoded(indent: indent, depth: depth + 1) }, "[", "]")
        case .string(let s): return quote(s)
        case .number(let n): return n
        case .bool(let b): return b ? "true" : "false"
        case .null: return "null"
        }
    }
    public func value(at path: [Int]) -> JSONValue? {
        guard let first = path.first else { return self }
        switch self {
        case .object(let v): return v.indices.contains(first) ? v[first].value.value(at: Array(path.dropFirst())) : nil
        case .array(let v): return v.indices.contains(first) ? v[first].value(at: Array(path.dropFirst())) : nil
        default: return nil
        }
    }
    public mutating func replace(at path: [Int], with value: JSONValue?) {
        guard let first = path.first else { if let value { self = value }; return }
        let tail = Array(path.dropFirst())
        switch self {
        case .object(var members):
            guard members.indices.contains(first) else { return }
            if tail.isEmpty && value == nil { members.remove(at: first) }
            else { members[first].value.replace(at: tail, with: value) }
            self = .object(members)
        case .array(var values):
            guard values.indices.contains(first) else { return }
            if tail.isEmpty && value == nil { values.remove(at: first) }
            else { values[first].replace(at: tail, with: value) }
            self = .array(values)
        default: break
        }
    }
}

public enum JSONWorkspace {
    public struct Failure: LocalizedError {
        public let message: String
        public let line: Int
        public let column: Int
        public var errorDescription: String? { "\(line)行 \(column)列: \(message)" }
    }
    public static func parse(_ text: String) throws -> JSONValue {
        guard text.utf8.count <= 256 * 1024 else { throw Failure(message: "入力は256 KiBまでです。", line: 1, column: 1) }
        var parser = Parser(chars: Array(text))
        let result = try parser.value(depth: 0)
        parser.space()
        guard parser.i == parser.chars.count else { throw parser.failure("JSONの後に余分な文字があります。") }
        return result
    }
    private struct Parser {
        let chars: [Character]
        var i = 0
        var nodes = 0
        var current: Character? { i < chars.count ? chars[i] : nil }
        mutating func space() { while let c = current, c == " " || c == "\n" || c == "\r" || c == "\r\n" || c == "\t" { i += 1 } }
        func failure(_ message: String) -> Failure {
            let prefix = chars.prefix(i)
            return Failure(message: message, line: prefix.filter { $0 == "\n" || $0 == "\r" || $0 == "\r\n" }.count + 1, column: prefix.reversed().prefix { $0 != "\n" && $0 != "\r" && $0 != "\r\n" }.count + 1)
        }
        mutating func consume(_ c: Character) -> Bool { space(); if current == c { i += 1; return true }; return false }
        mutating func string() throws -> String {
            space(); let start = i
            guard current == "\"" else { throw failure("文字列が必要です。") }; i += 1
            var escaped = false
            while let c = current {
                i += 1
                if c == "\"" && !escaped {
                    let token = String(chars[start..<i])
                    do { return try JSONSerialization.jsonObject(with: Data(token.utf8), options: [.fragmentsAllowed]) as! String }
                    catch { throw failure("文字列のエスケープが不正です。") }
                }
                if c == "\\" && !escaped { escaped = true } else { escaped = false }
            }
            throw failure("文字列が閉じられていません。")
        }
        mutating func value(depth: Int) throws -> JSONValue {
            space(); nodes += 1
            guard depth <= 48, nodes <= 4000 else { throw failure("最大48階層・4,000要素までです。") }
            if current == "\"" { return .string(try string()) }
            if consume("{") {
                var members: [JSONValue.Member] = []; var keys = Set<String>()
                if consume("}") { return .object([]) }
                repeat {
                    let key = try string()
                    guard keys.insert(key).inserted else { throw failure("キー「\(key)」が重複しています。") }
                    guard consume(":") else { throw failure("キーの後に : が必要です。") }
                    members.append(.init(key, try value(depth: depth + 1)))
                    if consume("}") { return .object(members) }
                    guard consume(",") else { throw failure(", または } が必要です。") }
                } while true
            }
            if consume("[") {
                var values: [JSONValue] = []
                if consume("]") { return .array([]) }
                repeat {
                    values.append(try value(depth: depth + 1))
                    if consume("]") { return .array(values) }
                    guard consume(",") else { throw failure(", または ] が必要です。") }
                } while true
            }
            let start = i
            while let c = current, ![" ", "\n", "\r", "\r\n", "\t", ",", "]", "}"].contains(c) { i += 1 }
            let token = String(chars[start..<i])
            switch token {
            case "true": return .bool(true)
            case "false": return .bool(false)
            case "null": return .null
            default:
                guard token.range(of: #"^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?$"#, options: .regularExpression) != nil else { throw failure("値が不正です。文字列は二重引用符で囲んでください。") }
                return .number(token)
            }
        }
    }
}

/// Bounded UTF-8 file exchange. Validation precedes any destination write.
public enum JSONWorkspaceFile {
    public static let maximumBytes = 256 * 1024
    public static func read(_ url: URL) throws -> String {
        guard url.isFileURL else { throw ToolFailure.message("ローカルのJSONファイルを選んでください。") }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let info = try url.resourceValues(forKeys: [.isRegularFileKey])
        guard info.isRegularFile == true else { throw ToolFailure.message("通常のJSONファイルを選んでください。") }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var data = Data()
        while data.count < maximumBytes + 4 {
            guard let part = try handle.read(upToCount: maximumBytes + 4 - data.count), !part.isEmpty else { break }
            data.append(part)
        }
        if data.starts(with: [0xEF, 0xBB, 0xBF]) { data.removeFirst(3) }
        guard data.count <= maximumBytes else { throw ToolFailure.message("ファイルは256 KiBまでです。") }
        guard let text = String(data: data, encoding: .utf8) else { throw ToolFailure.message("UTF-8のJSONファイルを選んでください。") }
        _ = try JSONWorkspace.parse(text)
        return text
    }
    public static func save(_ text: String, to url: URL) throws {
        guard url.isFileURL else { throw ToolFailure.message("ローカルの保存先を選んでください。") }
        _ = try JSONWorkspace.parse(text)
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        try Data(text.utf8).write(to: url, options: .atomic)
    }
}
