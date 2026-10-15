import SwiftUI

actor TextCodecWorker {
    static let shared = TextCodecWorker()
    func run(_ input: String, mode: TextCodec.Mode) throws -> TextCodec.Result {
        try Task.checkCancellation()
        return try TextCodec.convert(input, mode: mode)
    }
}
@MainActor final class TextCodecModel: ObservableObject {
    @Published var input = ""
    @Published var output = ""
    @Published var mode = TextCodec.Mode.base64Encode
    @Published var status = ""
    @Published var busy = false
    private var task: Task<Void, Never>?
    func update() {
        task?.cancel(); output = ""; busy = true; status = ""
        let source = input, mode = mode
        task = Task {
            do {
                try await Task.sleep(nanoseconds: 150_000_000)
                let result = try await TextCodecWorker.shared.run(source, mode: mode)
                try Task.checkCancellation()
                output = result.text; status = result.warning; busy = false
            } catch is CancellationError { }
            catch { guard !Task.isCancelled else { return }; output = ""; status = error.localizedDescription; busy = false }
        }
    }
    func stop() { task?.cancel() }
}
struct TextCodecView: View {
    @ObservedObject var model: TextCodecModel
    var body: some View {
        ToolPage("テキスト変換", subtitle: "Base64とエスケープを、相互に変換。", symbol: "arrow.left.arrow.right", tint: .cyan) {
            VStack(spacing: 18) {
                ThemePicker("変換", selection: $model.mode, options: [TextCodec.Mode.base64Encode, .base64Decode, .escape, .restore].map { ($0, $0.rawValue) }, tabs: true)
                HStack(spacing: 16) {
                    TextPane(title: "入力", symbol: "text.alignleft", text: $model.input, tint: .cyan)
                    TextPane(title: "変換結果", symbol: "arrow.right", text: $model.output, editable: false, tint: .cyan)
                }
                HStack {
                    Button("貼り付け") { model.input = NSPasteboard.general.string(forType: .string) ?? "" }
                    Button("クリア") { model.input = "" }
                    if model.busy { ProgressView().controlSize(.small) }
                    Text(model.status).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("結果をコピー") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(model.output, forType: .string); model.status = "コピーしました" }
                        .disabled(model.busy || model.output.isEmpty)
                }
                ToolFootnote(text: "Base64はUTF-8テキスト用です。エスケープは改行・タブ・CR・バックスラッシュ・二重引用符・NULに対応。不明なエスケープは保持します。入力は最大1MiB。")
            }.padding(24)
        }.frame(minWidth: 940, minHeight: 670)
            .onChange(of: model.input) { _, _ in model.update() }
            .onChange(of: model.mode) { _, _ in model.update() }
            .onDisappear { model.stop() }
    }
}
