import Foundation

public enum DirectoryTree {
    public typealias Failure = EverydayCalculators.Failure
    public struct Node: Identifiable, Codable, Equatable {
        public var id: UUID
        public var name: String
        public var folder: Bool
        public var depth: Int
        public init(name: String, folder: Bool = true, depth: Int = 0) { id = UUID(); self.name = name; self.folder = folder; self.depth = depth }
    }
    public enum Format: String, CaseIterable { case tree = "標準 Tree", simple = "シンプル記号", bullet = "箇条書き", markdown = "Markdown", arrow = "矢印", ascii = "ASCII", custom = "カスタム" }
    public struct Style {
        public var folder = "📁", file = "📄", branch = "↳", bullet = "", arrow = "→"
        public var width = 2, slash = true, emoji = true
        public init() {}
    }
    public static func validate(_ nodes: [Node]) throws {
        guard nodes.count <= 1000, Set(nodes.map(\.id)).count == nodes.count else { throw Failure.invalid("最大1,000項目・ID重複なしで指定してください。") }
        for (i, node) in nodes.enumerated() {
            guard !node.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, node.name.utf8.count <= 255,
                  !node.name.contains("/"), !node.name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }), (0...20).contains(node.depth),
                  i == 0 ? node.depth == 0 : node.depth <= nodes[i - 1].depth + 1 else { throw Failure.invalid("名前・階層を確認してください（深さ20まで、名前に/・改行は使用不可）。") }
            if i > 0 && node.depth > nodes[i - 1].depth && !nodes[i - 1].folder { throw Failure.invalid("ファイルの中に項目は作成できません。") }
        }
    }
    public static func decode(_ text: String) throws -> [Node] {
        guard text.utf8.count <= 500_000, let data = text.data(using: .utf8) else { throw Failure.invalid("JSONは500KB以内です。") }
        let nodes = try JSONDecoder().decode([Node].self, from: data); try validate(nodes); return nodes
    }
    public static func encode(_ nodes: [Node]) throws -> String {
        try validate(nodes); let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return String(decoding: try encoder.encode(nodes), as: UTF8.self)
    }
    /// Parse indented text or standard tree/ASCII output. Folder markers are retained.
    public static func parse(_ text: String) throws -> [Node] {
        guard text.utf8.count <= 500_000 else { throw Failure.invalid("入力は500KB以内です。") }
        var nodes: [Node] = []
        for raw in text.components(separatedBy: .newlines) where !raw.trimmingCharacters(in: .whitespaces).isEmpty {
            let line = raw.replacingOccurrences(of: "\t", with: "    ")
            let chars = Array(line); var offset = 0
            while offset < chars.count && (chars[offset] == " " || chars[offset] == "│" || chars[offset] == "|") { offset += 1 }
            let rest = String(chars.dropFirst(offset))
            let branch = ["├── ", "└── ", "|-- ", "`-- ", "+-- "].first { rest.hasPrefix($0) }
            let depth = branch == nil ? offset / 2 : offset / 4 + 1
            var name = branch.map { String(rest.dropFirst($0.count)) } ?? rest
            let folder = name.hasSuffix("/")
            if folder { name.removeLast() }
            nodes.append(Node(name: name, folder: folder, depth: depth))
        }
        // A node followed by a deeper node is necessarily a directory.
        if nodes.count > 1 { for i in 0..<(nodes.count - 1) where nodes[i + 1].depth > nodes[i].depth { nodes[i].folder = true } }
        try validate(nodes); return nodes
    }
    public static func render(_ nodes: [Node], format: Format, style: Style = Style()) throws -> String {
        try validate(nodes)
        return nodes.enumerated().map { i, node in
            let name = node.name + (node.folder && style.slash ? "/" : "")
            let nextSibling = nodes.dropFirst(i + 1).prefix { $0.depth >= node.depth }.contains { $0.depth == node.depth }
            switch format {
            case .tree, .ascii:
                let ascii = format == .ascii
                var prefix = ""
                if node.depth > 0 {
                    for level in 1..<node.depth {
                        // Locate the ancestor at this level, then check its following siblings.
                        if let ancestor = nodes[..<i].lastIndex(where: { $0.depth == level }) {
                            let continues = nodes.dropFirst(ancestor + 1).prefix { $0.depth >= level }.contains { $0.depth == level }
                            prefix += continues ? (ascii ? "|   " : "│   ") : "    "
                        } else { prefix += "    " }
                    }
                    prefix += nextSibling ? (ascii ? "|-- " : "├── ") : (ascii ? "`-- " : "└── ")
                }; return prefix + name
            case .simple: return String(repeating: "  ", count: node.depth) + (node.folder ? "+ " : "- ") + name
            case .bullet: return String(repeating: "  ", count: node.depth) + "• " + name
            case .markdown: return String(repeating: "  ", count: node.depth) + "- " + name
            case .arrow: return String(repeating: "  ", count: node.depth) + "→ " + name
            case .custom:
                let icon = style.emoji ? (node.folder ? style.folder : style.file) + " " : ""
                return String(repeating: " ", count: node.depth * min(8, max(1, style.width))) + style.bullet + (node.depth > 0 ? style.branch + " " : "") + icon + name
            }
        }.joined(separator: "\n")
    }
    public static let sample = [Node(name: "project"), Node(name: "src", depth: 1), Node(name: "main.swift", folder: false, depth: 2), Node(name: "README.md", folder: false, depth: 1)]
}
