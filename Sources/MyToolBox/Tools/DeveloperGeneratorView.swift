import SwiftUI

private actor GeneratorWorker {
    func run(_ job: @Sendable () throws -> String) throws -> String { try Task.checkCancellation(); return try job() }
}
@MainActor final class GeneratorModel: ObservableObject {
    @Published var output = ""
    @Published var status = ""
    @Published var busy = false
    private var task: Task<Void, Never>?
    private let worker = GeneratorWorker()
    func clear() { task?.cancel(); output = ""; status = ""; busy = false }
    func generate(_ job: @escaping @Sendable () throws -> String) {
        clear(); busy = true
        task = Task {
            do {
                let result = try await worker.run(job)
                guard !Task.isCancelled else { return }
                output = result; status = "\(result.count)文字 · \(result.utf8.count) UTF-8バイト"; busy = false
            } catch {
                guard !Task.isCancelled else { return }
                status = error.localizedDescription; busy = false
            }
        }
    }
    func copy(_ value: String? = nil) {
        NSPasteboard.general.clearContents()
        status = NSPasteboard.general.setString(value ?? output, forType: .string) ? "コピーしました" : "コピーできませんでした"
    }
}

struct HashGeneratorView: View {
    @ObservedObject var model: GeneratorModel
    @State private var input = ""
    @State private var algorithm = TextHash.Algorithm.sha256
    @State private var base64 = false
    var body: some View {
        ToolPage("ハッシュ生成", subtitle: "テキストのUTF-8バイト列からハッシュ値を生成。", symbol: "number", tint: .purple) {
            VStack(spacing: 16) {
                HStack {
                    Picker("アルゴリズム", selection: $algorithm) { ForEach(TextHash.Algorithm.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                    Picker("出力形式", selection: $base64) { Text("HEX").tag(false); Text("Base64").tag(true) }
                }
                TextPane(title: "入力テキスト", symbol: "text.alignleft", text: $input, tint: .purple)
                Text("\(input.count)文字 · \(input.utf8.count) UTF-8バイト").font(.caption)
                HStack {
                    Button("貼り付け") { input = NSPasteboard.general.string(forType: .string) ?? "" }
                    Button("クリア") { input = ""; model.clear() }
                    Spacer()
                    Button("ハッシュを生成") {
                        let text = input, selected = algorithm, encoded = base64
                        model.generate { try TextHash.generate(text, algorithm: selected, base64: encoded) }
                    }.disabled(model.busy)
                }
                TextPane(title: "生成結果", symbol: "number", text: $model.output, editable: false, tint: .purple)
                GeneratorActions(model: model)
                ToolFootnote(text: "入力は最大1MiB。改行や空白もそのまま計算します。SHA-1は既存値との照合用です。")
            }.padding(24)
        }.frame(minWidth: 850, minHeight: 700)
            .onChange(of: input) { _, _ in model.clear() }
            .onChange(of: algorithm) { _, _ in model.clear() }
            .onChange(of: base64) { _, _ in model.clear() }
    }
}

struct TestDataGeneratorView: View {
    @ObservedObject var model: GeneratorModel
    @State private var mode = "文字列"
    @State private var kind = TestDataGenerator.Kind.ja
    @State private var length = "20"
    @State private var count = "5"
    @State private var separator = "\n"
    @State private var sentences = 3
    @State private var sentenceLength = 1
    @State private var language = "ja"
    @State private var uuidCount = 5
    @State private var columnCount = 5
    @State private var rowCount = 5
    @State private var columns = TestDataGenerator.defaultColumns
    init(model: GeneratorModel, initialMode: String = "文字列") {
        self.model = model; _mode = State(initialValue: initialMode)
    }
    private var settingsKey: String {
        [mode, kind.rawValue, length, count, separator, String(sentences), String(sentenceLength), language, String(uuidCount), String(columnCount), String(rowCount)] .joined(separator: "|") + columns.map { $0.name + $0.type.rawValue }.joined(separator: "|")
    }
    var body: some View {
        ToolPage("テストデータ生成", subtitle: "ダミー文章・文字列・CSV・UUIDをまとめて生成。", symbol: "wand.and.stars", tint: .indigo) {
            VStack(spacing: 16) {
                ThemePicker("モード", selection: $mode, options: ["文章", "文字列", "CSV", "UUID"].map { ($0, $0) }, tabs: true)
                ScrollView {
                    ToolCard { settings }
                }.frame(maxHeight: mode == "CSV" ? 310 : 150)
                HStack {
                    Button("生成・再生成") { generate() }.disabled(model.busy)
                    Button("クリア") { model.clear() }
                    if model.busy { ProgressView().controlSize(.small) }
                    Spacer()
                }
                if mode == "UUID", !model.output.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(model.output.components(separatedBy: "\n").enumerated()), id: \.offset) { entry in
                                HStack {
                                    Text(entry.element).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                                    Spacer()
                                    Button("コピー") { model.copy(entry.element) }.accessibilityLabel("UUID \(entry.offset + 1)をコピー")
                                }
                            }
                        }
                    }
                } else {
                    TextPane(title: "生成結果", symbol: "text.alignleft", text: $model.output, editable: false, tint: .indigo)
                }
                GeneratorActions(model: model)
                ToolFootnote(text: mode == "文字列" ? "各項目を指定文字数に切り詰め・連結します。メール・URL・IP風は形式確認用です。完全なUUID v4はUUIDモードで生成できます。" : "生成データはこの画面内のみ保持。メール・URLはexample.com、IPは文書用アドレスを使用します。")
            }.padding(24)
        }.frame(minWidth: 920, minHeight: 760)
            .onChange(of: settingsKey) { _, _ in model.clear() }
    }
    @ViewBuilder private var settings: some View {
        if mode == "文章" {
            VStack {
                Stepper("文章数: \(sentences)", value: $sentences, in: 1...10)
                Picker("長さ", selection: $sentenceLength) { Text("短文").tag(0); Text("通常文").tag(1); Text("長文").tag(2) }
                Picker("言語", selection: $language) { Text("日本語").tag("ja"); Text("英語").tag("en"); Text("日本語＋英数字").tag("mixed") }
            }
        } else if mode == "文字列" {
            VStack(spacing: 12) {
                Picker("種類", selection: $kind) { ForEach(TestDataGenerator.Kind.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                HStack {
                    Text("1件の文字数"); TextField("1〜10000", text: $length).accessibilityLabel("1件の文字数")
                    Text("件数"); TextField("1〜1000", text: $count).accessibilityLabel("件数")
                    Picker("区切り", selection: $separator) { Text("改行").tag("\n"); Text("カンマ").tag(","); Text("空白").tag(" "); Text("タブ").tag("\t") }
                }
            }
        } else if mode == "UUID" {
            Stepper("UUID v4: \(uuidCount)個", value: $uuidCount, in: 1...100)
        } else {
            VStack(spacing: 10) {
                HStack { Stepper("列: \(columnCount)", value: $columnCount, in: 1...10); Stepper("行: \(rowCount)", value: $rowCount, in: 1...10) }
                ForEach(0..<columnCount, id: \.self) { i in
                    HStack {
                        Text("\(i + 1)").frame(width: 25)
                        TextField("列名", text: $columns[i].name).accessibilityLabel("列\(i + 1)の名前")
                        Picker("型", selection: $columns[i].type) { ForEach(TestDataGenerator.ColumnType.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.frame(width: 240).accessibilityLabel("列\(i + 1)の型")
                    }
                }
            }
        }
    }
    private func generate() {
        switch mode {
        case "文章":
            let n = sentences, size = sentenceLength, lang = language
            model.generate { try TestDataGenerator.sentences(count: n, length: size, language: lang) }
        case "UUID":
            let n = uuidCount
            model.generate { try TestDataGenerator.uuids(count: n).joined(separator: "\n") }
        case "CSV":
            let selected = Array(columns.prefix(columnCount)), n = rowCount
            model.generate { try TestDataGenerator.csv(columns: selected, count: n) }
        default:
            guard let size = Int(length), let n = Int(count) else { model.clear(); model.status = "文字数と件数は整数で指定してください"; return }
            let selected = kind, delimiter = separator
            model.generate { try TestDataGenerator.text(kind: selected, length: size, count: n, separator: delimiter) }
        }
    }
}

private struct GeneratorActions: View {
    @ObservedObject var model: GeneratorModel
    var body: some View {
        HStack {
            Text(model.status).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            Spacer()
            Button("すべてコピー") { model.copy() }.disabled(model.output.isEmpty || model.busy)
        }
    }
}
