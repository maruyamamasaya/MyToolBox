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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("乱数", systemImage: "dice").font(.headline)
                Spacer()
                ThemeMenu()
            }
            HStack(spacing: 8) {
                Text("範囲").frame(width: 30, alignment: .leading)
                Picker("数値の範囲", selection: $range) {
                    ForEach(ranges.indices, id: \.self) { index in
                        Text("\(ranges[index].0) 〜 \(ranges[index].1)").tag(index)
                    }
                    Text("桁数を指定…").tag(6)
                }.labelsHidden()
            }
            HStack(spacing: 8) {
                Text("個数").frame(width: 30, alignment: .leading)
                Picker("生成する数", selection: $count) {
                    ForEach([1, 5, 10, 20, 50, 100], id: \.self) { Text("\($0)個").tag($0) }
                }.labelsHidden().frame(width: 78)
                Picker("区切り形式", selection: $separator) {
                    Text("改行").tag("\n"); Text("カンマ").tag(", ")
                    Text("空白").tag(" "); Text("タブ").tag("\t"); Text("パイプ").tag(" | ")
                }.labelsHidden()
            }
            if range == 6 {
                HStack(spacing: 8) {
                    Text("桁数").frame(width: 30, alignment: .leading)
                    TextField("1〜32", text: $digits).textFieldStyle(.roundedBorder)
                        .frame(width: 52).accessibilityLabel("桁数")
                    Toggle("0から開始", isOn: $startsAtZero)
                        .help("0〜指定桁数の最大値。先頭の0は省略します。")
                }
            }
            HStack {
                Button("生成", systemImage: "arrow.clockwise", action: generate)
                    .buttonStyle(.borderedProminent)
                Spacer()
                Text("\(numbers.count)個").font(.caption).foregroundStyle(.secondary)
                Button(copied ? "コピー済み" : "コピー", systemImage: "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(output, forType: .string)
                    copied = true
                }.disabled(numbers.isEmpty)
            }
            if let error {
                Text(error).font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
            ScrollView {
                Text(output).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(8)
            }
            .frame(maxWidth: .infinity, minHeight: 64, maxHeight: .infinity)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
            .accessibilityLabel("生成された乱数")
            .help("端末内で生成します。重複する場合があります。")
        }
        .padding(10).controlSize(.small)
        .frame(minWidth: 340, idealWidth: 360, minHeight: range == 6 ? 290 : 260, idealHeight: range == 6 ? 290 : 260)
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
