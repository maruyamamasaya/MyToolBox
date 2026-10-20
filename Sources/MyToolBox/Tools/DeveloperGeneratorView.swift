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
    @State private var input: String
    @State private var algorithm: TextHash.Algorithm
    @State private var base64: Bool
    @State private var showsSettings = false
    init(model: GeneratorModel, input: String = "", algorithm: TextHash.Algorithm = .sha256, base64: Bool = false) {
        self.model = model; _input = State(initialValue: input)
        _algorithm = State(initialValue: algorithm); _base64 = State(initialValue: base64)
    }
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("ハッシュ生成").font(.headline)
                Spacer()
                Button { showsSettings = true } label: {
                    Image(systemName: "gearshape").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("ハッシュ生成の設定")
                    .popover(isPresented: $showsSettings) {
                        VStack(alignment: .leading, spacing: 12) {
                            ThemeMenu()
                            Text("入力は最大1MiB。UTF-8の改行・空白もそのまま計算します。空文字にも対応。SHA-1は既存値との照合用です。")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(12).frame(width: 260)
                    }
            }
            HStack(spacing: 8) {
                Picker("アルゴリズム", selection: $algorithm) {
                    ForEach(TextHash.Algorithm.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.labelsHidden()
                Picker("出力形式", selection: $base64) { Text("HEX").tag(false); Text("Base64").tag(true) }
                    .labelsHidden()
            }
            TextEditor(text: $input).font(.system(.body, design: .monospaced))
                .frame(minHeight: 55, maxHeight: .infinity).accessibilityLabel("入力テキスト")
                .overlay(alignment: .topLeading) {
                    if input.isEmpty {
                        Text("入力テキスト").font(.caption).foregroundStyle(.secondary)
                            .padding(6).allowsHitTesting(false).accessibilityHidden(true)
                    }
                }
            HStack(spacing: 6) {
                Button { input = NSPasteboard.general.string(forType: .string) ?? "" } label: {
                    Image(systemName: "doc.on.clipboard").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("貼り付け")
                Button { input = ""; model.clear() } label: {
                    Image(systemName: "trash").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("クリア")
                Spacer(minLength: 0)
                Button {
                    let text = input, selected = algorithm, encoded = base64
                    model.generate { try TextHash.generate(text, algorithm: selected, base64: encoded) }
                } label: { Text(model.busy ? "生成中" : "生成").frame(minHeight: 28) }
                    .buttonStyle(.borderedProminent).disabled(model.busy)
                Button { model.copy() } label: { Text("コピー").frame(minHeight: 28) }
                    .disabled(model.output.isEmpty || model.busy)
            }
            ScrollView {
                Text(model.output.isEmpty ? "生成結果" : model.output)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(model.output.isEmpty ? Color.secondary : Color.primary)
                    .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true).padding(8)
            }.frame(minHeight: 60, maxHeight: .infinity)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
                .accessibilityLabel("生成結果")
            Text(model.status.isEmpty ? "入力 \(input.count)文字 · \(input.utf8.count)バイト" : model.status)
                .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }.padding(10).controlSize(.regular)
            .frame(minWidth: 300, idealWidth: 320, minHeight: 340, idealHeight: 360)
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
    @State private var showsSettings = false
    private var settingsSummary: String {
        switch mode {
        case "文章": return "\(sentences)文章"
        case "UUID": return "UUID v4 · \(uuidCount)個"
        case "CSV": return "\(columnCount)列 × \(rowCount)行"
        default: return "\(kind.rawValue) · \(length)文字 × \(count)件"
        }
    }
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("テストデータ生成").font(.headline)
                Spacer()
                Button { showsSettings = true } label: {
                    Image(systemName: "gearshape").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("生成条件の設定")
                    .popover(isPresented: $showsSettings) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                settings
                                ThemeMenu()
                                Text(mode == "文字列" ? "各項目を指定文字数に切り詰め・連結します。メール・URL・IP風は形式確認用です。完全なUUID v4はUUIDモードで生成できます。" : "生成データは画面内だけで保持。メール・URLはexample.com、IPは文書用アドレスです。")
                                    .font(.caption).foregroundStyle(.secondary)
                            }.padding(12)
                        }.frame(width: 340, height: mode == "CSV" ? 400 : 250)
                    }
            }
            Picker("モード", selection: $mode) {
                ForEach(["文章", "文字列", "CSV", "UUID"], id: \.self) { Text($0).tag($0) }
            }.pickerStyle(.segmented).labelsHidden()
            HStack {
                Text(settingsSummary).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("条件を変更") { showsSettings = true }
            }
            ScrollView {
                if mode == "UUID", !model.output.isEmpty {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(model.output.components(separatedBy: "\n").enumerated()), id: \.offset) { entry in
                            HStack(alignment: .top, spacing: 8) {
                                Text(entry.element).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
                                Button { model.copy(entry.element) } label: {
                                    Image(systemName: "doc.on.doc").frame(width: 28, height: 28).contentShape(Rectangle())
                                }.accessibilityLabel("UUID \(entry.offset + 1)をコピー")
                            }
                        }
                    }.padding(8)
                } else {
                    Text(model.output.isEmpty ? "生成結果" : model.output)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(model.output.isEmpty ? Color.secondary : Color.primary)
                        .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(8)
                }
            }.frame(maxWidth: .infinity, minHeight: 60, maxHeight: .infinity)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
                .accessibilityLabel("生成結果")
            Text(model.status).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button { model.clear() } label: {
                    Image(systemName: "trash").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("生成結果をクリア")
                Spacer(minLength: 0)
                Button { generate() } label: { Text(model.busy ? "生成中" : "生成").frame(minWidth: 36, minHeight: 28) }
                    .buttonStyle(.borderedProminent).disabled(model.busy)
                Button { model.copy() } label: { Text("コピー").frame(minHeight: 28) }
                    .disabled(model.output.isEmpty || model.busy)
            }
        }.padding(10).controlSize(.regular)
            .frame(minWidth: 320, idealWidth: 340, minHeight: 300, idealHeight: 340)
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
                }
                HStack {
                    Text("件数"); TextField("1〜1000", text: $count).accessibilityLabel("件数")
                }
                    Picker("区切り", selection: $separator) { Text("改行").tag("\n"); Text("カンマ").tag(","); Text("空白").tag(" "); Text("タブ").tag("\t") }
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
                        Picker("型", selection: $columns[i].type) { ForEach(TestDataGenerator.ColumnType.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.frame(width: 125).accessibilityLabel("列\(i + 1)の型")
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
