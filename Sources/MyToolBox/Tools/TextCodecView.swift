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
    @State private var showsSettings = false
    private var isBase64: Binding<Bool> {
        Binding(get: { model.mode == .base64Encode || model.mode == .base64Decode }, set: { base64 in
            let decode = model.mode == .base64Decode || model.mode == .restore
            model.mode = base64 ? (decode ? .base64Decode : .base64Encode) : (decode ? .restore : .escape)
        })
    }
    private var isDecoding: Binding<Bool> {
        Binding(get: { model.mode == .base64Decode || model.mode == .restore }, set: { decode in
            model.mode = isBase64.wrappedValue ? (decode ? .base64Decode : .base64Encode) : (decode ? .restore : .escape)
        })
    }
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("テキスト変換").font(.headline)
                Spacer()
                Button { showsSettings = true } label: {
                    Image(systemName: "gearshape").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("テキスト変換の設定")
                    .popover(isPresented: $showsSettings) {
                        VStack(alignment: .leading, spacing: 12) {
                            ThemeMenu()
                            Text("入力すると自動で変換します。Base64はUTF-8テキスト用。エスケープは改行・タブ・CR・バックスラッシュ・二重引用符・NULに対応し、不明なものは保持します。入力は最大1MiB。")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(12).frame(width: 260)
                    }
            }
            HStack(spacing: 8) {
                Picker("変換方法", selection: isBase64) { Text("Base64").tag(true); Text("エスケープ").tag(false) }.labelsHidden()
                Picker("変換方向", selection: isDecoding) {
                    Text(isBase64.wrappedValue ? "エンコード" : "変換").tag(false)
                    Text(isBase64.wrappedValue ? "デコード" : "復元").tag(true)
                }.labelsHidden()
            }
            TextEditor(text: $model.input).font(.system(.body, design: .monospaced))
                .frame(minHeight: 55, maxHeight: .infinity).accessibilityLabel("入力テキスト")
                .overlay(alignment: .topLeading) {
                    if model.input.isEmpty {
                        Text("入力テキスト").font(.caption).foregroundStyle(.secondary).padding(6).allowsHitTesting(false).accessibilityHidden(true)
                    }
                }
            ScrollView {
                Text(model.output.isEmpty ? (model.busy ? "変換中…" : "変換結果") : model.output)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(model.output.isEmpty ? Color.secondary : Color.primary)
                    .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(8)
            }.frame(minHeight: 60, maxHeight: .infinity)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
                .accessibilityLabel("変換結果")
            Text(model.status).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                Button { model.input = NSPasteboard.general.string(forType: .string) ?? "" } label: {
                    Image(systemName: "doc.on.clipboard").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("貼り付け")
                Button { model.input = "" } label: {
                    Image(systemName: "trash").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("クリア")
                Spacer(minLength: 0)
                Button { model.update() } label: { Text("変換").frame(minWidth: 28, minHeight: 28) }
                    .buttonStyle(.borderedProminent).disabled(model.busy)
                Button {
                    NSPasteboard.general.clearContents()
                    model.status = NSPasteboard.general.setString(model.output, forType: .string) ? "コピーしました" : "コピーできませんでした"
                } label: { Text("コピー").frame(minHeight: 28) }
                    .disabled(model.busy || model.output.isEmpty)
            }
        }.padding(10).controlSize(.regular)
            .frame(minWidth: 300, idealWidth: 320, minHeight: 340, idealHeight: 360)
            .onChange(of: model.input) { _, _ in model.update() }
            .onChange(of: model.mode) { _, _ in model.update() }
            .onDisappear { model.stop() }
    }
}
