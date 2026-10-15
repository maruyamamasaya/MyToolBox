import SwiftUI

struct RandomNumberView: View {
    @State private var range = 1
    @State private var digits = "16"
    @State private var startsAtZero = false
    @State private var count = 10
    @State private var separator = "\n"
    @State private var numbers: [String] = []
    @State private var error: String?
    @State private var copied = false
    private let ranges = [(1, 10), (1, 100), (1, 1000), (0, 255), (-100, 100), (-1000, 1000)]
    private var output: String { numbers.joined(separator: separator) }
    var body: some View {
        ToolPage("乱数ジェネレーター", subtitle: "範囲と個数を選んで、ランダムな整数をまとめて生成", symbol: "dice", tint: .purple) {
            VStack(alignment: .leading, spacing: 20) {
                ToolCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Picker("数値の範囲", selection: $range) {
                            ForEach(ranges.indices, id: \.self) { index in
                                Text("\(ranges[index].0) 〜 \(ranges[index].1)").tag(index)
                            }
                            Text("桁数を指定…").tag(6)
                        }
                        if range == 6 {
                            HStack {
                                Text("桁数")
                                TextField("1〜32", text: $digits).textFieldStyle(.roundedBorder).frame(width: 80).accessibilityLabel("桁数")
                                Toggle("0から開始する", isOn: $startsAtZero)
                            }
                            Text(startsAtZero ? "0〜指定桁数の最大値。先頭の0は省略します。" : "1〜32桁。指定した桁数の整数を生成します。")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Picker("生成する数", selection: $count) {
                            ForEach([1, 5, 10, 20, 50, 100], id: \.self) { Text("\($0)個").tag($0) }
                        }
                        Picker("区切り形式", selection: $separator) {
                            Text("改行").tag("\n"); Text("カンマ（,）").tag(", ")
                            Text("スペース").tag(" "); Text("タブ").tag("\t"); Text("パイプ（|）").tag(" | ")
                        }
                        Button("乱数を生成", systemImage: "arrow.clockwise", action: generate).buttonStyle(.borderedProminent)
                    }
                }
                if let error { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
                HStack {
                    Text("生成結果：\(numbers.count)個").font(.headline)
                    Spacer()
                    Button(copied ? "コピーしました" : "コピー", systemImage: "doc.on.doc") {
                        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(output, forType: .string); copied = true
                    }.disabled(numbers.isEmpty)
                }
                ToolCard {
                    ScrollView { Text(output).font(.system(.body, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                        .frame(minHeight: 180, maxHeight: .infinity).accessibilityLabel("生成された乱数")
                }
                ToolFootnote(text: "端末内で生成します。重複する場合があります。区切り形式の変更は同じ結果に反映されます。")
            }.padding(26)
        }.frame(minWidth: 620, idealWidth: 740, minHeight: 650)
            .onAppear { generate() }
            .onChange(of: range) { _, _ in generate() }
            .onChange(of: count) { _, _ in generate() }
            .onChange(of: digits) { _, _ in if range == 6 { generate() } }
            .onChange(of: startsAtZero) { _, _ in if range == 6 { generate() } }
            .onChange(of: separator) { _, _ in copied = false }
    }
    private func generate() {
        copied = false
        do {
            var generator = SystemRandomNumberGenerator()
            let digitCount: Int?
            if range == 6 {
                guard let parsed = Int(digits) else { throw RandomNumbers.GenerationError.invalidInput }
                digitCount = parsed
            } else { digitCount = nil }
            let bounds = ranges[min(range, ranges.count - 1)]
            numbers = try RandomNumbers.generate(minimum: bounds.0, maximum: bounds.1, digits: digitCount, startsAtZero: startsAtZero, count: count, using: &generator)
            error = nil
        } catch { self.error = error.localizedDescription; numbers = [] }
    }
}
