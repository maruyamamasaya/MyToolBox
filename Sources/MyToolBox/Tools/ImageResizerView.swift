import SwiftUI
import UniformTypeIdentifiers

actor ImageResizeWorker {
    func load(_ url: URL) throws -> (ImageResizer.Input, CGImage) {
        try Task.checkCancellation()
        let input = try ImageResizer.read(url)
        return (input, try ImageResizer.preview(input.data))
    }
    func resize(_ input: ImageResizer.Input, size: ImageResizer.Size, format: ImageResizer.Format, quality: Double) throws -> (Data, CGImage) {
        try Task.checkCancellation()
        let data = try ImageResizer.resize(input, to: size, format: format, quality: quality)
        return (data, try ImageResizer.preview(data))
    }
    func beginBatch(in parent: URL) throws -> URL { try ImageResizer.createBatchDirectory(in: parent) }
    func batchFile(_ url: URL, index: Int, directory: URL, sizing: ImageResizer.BatchSizing, format: ImageResizer.Format, quality: Double) throws -> URL {
        try ImageResizer.resizeBatchFile(url, index: index, directory: directory, sizing: sizing, format: format, quality: quality)
    }
    func save(_ data: Data, to url: URL, protecting source: URL) throws { try ImageResizer.save(data, to: url, protecting: source) }
}
@MainActor final class ImageResizerModel: ObservableObject {
    @Published var input: ImageResizer.Input?
    @Published var sourceURL: URL?
    @Published var sourcePreview: NSImage?
    @Published var resultPreview: NSImage?
    @Published var output: Data?
    @Published var width = ""
    @Published var height = ""
    @Published var keepRatio = true
    @Published var format = ImageResizer.Format.png
    @Published var quality = 0.85
    @Published var status = "画像を選択、またはここにドロップしてください"
    @Published var busy = false
    @Published var batchURLs: [URL] = []
    @Published var batchResults: [String] = []
    @Published var batchDirectory: URL?
    private var batchScale: Double?
    private var widthBased = true
    var isBatch: Bool { batchURLs.count > 1 }
    private let worker = ImageResizeWorker()
    private var task: Task<Void, Never>?
    var size: ImageResizer.Size? {
        guard let w = Int(width), let h = Int(height) else { return nil }
        let size = ImageResizer.Size(width: w, height: h)
        return (try? ImageResizer.validate(size)) != nil ? size : nil
    }
    func invalidate() { output = nil; resultPreview = nil; batchResults = []; batchDirectory = nil; status = "設定を変更しました。リサイズしてください" }
    func dimensionChanged(widthChanged: Bool) {
        invalidate(); batchScale = nil; widthBased = widthChanged
        guard keepRatio, let input else { return }
        let raw = widthChanged ? width : height
        guard let value = Int(raw), (1...16384).contains(value) else { return }
        if widthChanged { height = String(max(1, Int((Double(value) * Double(input.height) / Double(input.width)).rounded()))) }
        else { width = String(max(1, Int((Double(value) * Double(input.width) / Double(input.height)).rounded()))) }
    }
    func preset(_ scale: Double) {
        guard let input else { return }
        invalidate(); batchScale = scale
        do { let s = try ImageResizer.scaled(width: input.width, height: input.height, scale: scale); width = String(s.width); height = String(s.height) }
        catch { status = error.localizedDescription }
    }
    func open() {
        guard !busy else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.jpeg, .png, .webP, .heic, .heif, .tiff]
        panel.allowsMultipleSelection = true; panel.canChooseDirectories = false
        if panel.runModal() == .OK { load(panel.urls) }
    }
    func load(_ url: URL) { load([url]) }
    func load(_ urls: [URL]) {
        guard !busy, !urls.isEmpty, urls.allSatisfy(\.isFileURL) else { return }
        guard urls.count <= 200 else { status = "一度に選べる画像は200枚までです"; return }
        var seen = Set<URL>()
        let unique = urls.filter { seen.insert($0.standardizedFileURL).inserted }
        guard !unique.isEmpty else { return }
        batchURLs = unique; batchScale = nil; widthBased = true
        invalidate(); input = nil; sourceURL = nil; sourcePreview = nil; width = ""; height = ""
        busy = true; status = "画像を読み込み中…"
        task = Task {
            do {
                var firstValid: (URL, ImageResizer.Input, CGImage)?
                for candidate in unique {
                    try Task.checkCancellation()
                    do {
                        let (loaded, preview) = try await worker.load(candidate)
                        firstValid = (candidate, loaded, preview); break
                    } catch is CancellationError { throw CancellationError() }
                    catch { if unique.count == 1 { throw error } }
                }
                guard let (url, loaded, preview) = firstValid else { throw ImageResizer.Failure.message("読み込める画像がありません") }
                try Task.checkCancellation()
                input = loaded; sourceURL = url; sourcePreview = NSImage(cgImage: preview, size: .zero)
                width = String(loaded.width); height = String(loaded.height)
                format = loaded.isJPEG ? .jpeg : .png
                status = isBatch ? "\(batchURLs.count)枚を選択しました。設定は全画像に適用します" : "読み込みました"; busy = false
            } catch { guard !Task.isCancelled else { return }; status = error.localizedDescription; busy = false }
        }
    }
    func resize() {
        if isBatch { resizeBatch(); return }
        guard !busy, let input, let size else { status = "有効な幅と高さを指定してください"; return }
        invalidate(); busy = true; status = "リサイズ中…"
        let selectedFormat = format, selectedQuality = quality
        task = Task {
            do {
                let (data, preview) = try await worker.resize(input, size: size, format: selectedFormat, quality: selectedQuality)
                try Task.checkCancellation()
                output = data; resultPreview = NSImage(cgImage: preview, size: .zero); status = "できあがりました。保存先を選んで保存できます"; busy = false
            } catch { guard !Task.isCancelled else { return }; status = error.localizedDescription; busy = false }
        }
    }
    func resizeBatch() {
        guard !busy, size != nil else { return }
        let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true
        panel.canCreateDirectories = true; panel.prompt = "ここに一括保存"
        panel.message = "選んだフォルダ内に新しいリサイズ用フォルダを作成します。元画像は変更しません。"
        guard panel.runModal() == .OK, let parent = panel.url else { return }
        resizeBatch(in: parent)
    }
    func resizeBatch(in parent: URL) {
        guard !busy, let size else { return }
        let urls = batchURLs, selectedFormat = format, selectedQuality = quality
        let sizing: ImageResizer.BatchSizing = batchScale.map { .scale($0) } ?? .pixels(size, keepRatio: keepRatio, widthBased: widthBased)
        invalidate(); busy = true; status = "一括リサイズを開始…"
        task = Task {
            do {
                let directory = try await worker.beginBatch(in: parent)
                batchDirectory = directory
                var succeeded = 0
                for (index, url) in urls.enumerated() {
                    try Task.checkCancellation()
                    status = "処理中：\(index + 1) / \(urls.count)枚"
                    do {
                        let saved = try await worker.batchFile(url, index: index, directory: directory, sizing: sizing, format: selectedFormat, quality: selectedQuality)
                        try Task.checkCancellation()
                        succeeded += 1; batchResults.append("保存済み：" + saved.lastPathComponent)
                    } catch is CancellationError { throw CancellationError() }
                    catch { batchResults.append("失敗：" + url.lastPathComponent + " — " + error.localizedDescription) }
                }
                status = "完了：\(succeeded)枚保存・\(urls.count - succeeded)枚失敗。保存先：" + directory.path
            } catch { if !Task.isCancelled { status = error.localizedDescription } }
            busy = false
        }
    }
    func save() {
        guard !busy, output != nil, let sourceURL, let size else { return }
        let panel = NSSavePanel(); panel.allowedContentTypes = [format.type]
        panel.nameFieldStringValue = sourceURL.deletingPathExtension().lastPathComponent + "-\(size.width)x\(size.height)." + format.fileExtension
        guard panel.runModal() == .OK, let url = panel.url else { return }
        save(to: url)
    }
    func save(to url: URL) {
        guard !busy, let output, let sourceURL else { return }
        busy = true; status = "保存中…"
        task = Task {
            do { try await worker.save(output, to: url, protecting: sourceURL); try Task.checkCancellation(); status = "保存しました：" + url.lastPathComponent }
            catch { guard !Task.isCancelled else { return }; status = error.localizedDescription }
            busy = false
        }
    }
    func stop() { task?.cancel() }
    static func bytes(_ count: Int) -> String { ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file) }
}
struct ImageResizerView: View {
    @ObservedObject var model: ImageResizerModel
    @State private var targeted = false
    @State private var expanded: Bool
    @State private var showsSettings = false
    @State private var showsBatchResults = false
    @State private var previewResult = true
    init(model: ImageResizerModel, initiallyExpanded: Bool = false) {
        self.model = model; _expanded = State(initialValue: initiallyExpanded)
    }
    private var widthBinding: Binding<String> { Binding(get: { model.width }, set: { model.width = $0; model.dimensionChanged(widthChanged: true) }) }
    private var heightBinding: Binding<String> { Binding(get: { model.height }, set: { model.height = $0; model.dimensionChanged(widthChanged: false) }) }
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("画像リサイズ").font(.headline)
                Spacer(minLength: 0)
                Button(expanded ? "小さく戻す" : "拡大") { expanded.toggle() }
                Button { showsSettings = true } label: {
                    Image(systemName: "gearshape").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("リサイズの設定")
                    .popover(isPresented: $showsSettings) { settings }
            }
            if let input = model.input {
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.isBatch ? "\(model.batchURLs.count)枚 · 先頭画像をプレビュー" : model.sourceURL?.lastPathComponent ?? "選択中の画像")
                        .font(.caption.weight(.semibold)).lineLimit(1).help(model.sourceURL?.lastPathComponent ?? "")
                    Text("元画像 \(input.width) × \(input.height) px · \(ImageResizerModel.bytes(input.data.count))")
                        .font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            let layout = expanded ? AnyLayout(HStackLayout(alignment: .top, spacing: 16)) : AnyLayout(VStackLayout(spacing: 8))
            layout {
                preview.frame(maxWidth: .infinity, maxHeight: .infinity)
                controls.frame(width: expanded ? 290 : nil).fixedSize(horizontal: false, vertical: true)
            }.frame(maxHeight: .infinity)
            if let output = model.output {
                Text("変換後 \(model.width) × \(model.height) px · \(ImageResizerModel.bytes(output.count))（\(model.format.rawValue)）")
                    .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            }
            if !model.batchResults.isEmpty {
                Button("一括処理の結果（\(model.batchResults.count)件）") { showsBatchResults = true }
                    .popover(isPresented: $showsBatchResults) {
                        VStack(alignment: .leading, spacing: 10) {
                            if let directory = model.batchDirectory {
                                Button("保存先を開く") { NSWorkspace.shared.open(directory) }
                            }
                            ScrollView {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(Array(model.batchResults.enumerated()), id: \.offset) { _, result in
                                        Text(result).font(.caption).textSelection(.enabled)
                                    }
                                }
                            }
                        }.padding(12).frame(width: 340, height: 320)
                    }
            }
            Text(model.status).font(.caption).foregroundStyle(.secondary)
                .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button { model.open() } label: {
                    Image(systemName: "photo.badge.plus").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("画像を選択").disabled(model.busy)
                Spacer(minLength: 0)
                Button { model.resize() } label: {
                    Text(model.isBatch ? "一括保存…" : "リサイズ").frame(minHeight: 28)
                }.buttonStyle(.borderedProminent).disabled(model.busy || model.input == nil || model.size == nil)
                if !model.isBatch {
                    Button { model.save() } label: { Text("保存…").frame(minHeight: 28) }
                        .disabled(model.busy || model.output == nil)
                }
            }
        }.padding(10).controlSize(.regular)
            .frame(minWidth: expanded ? 800 : 340, idealWidth: expanded ? 1100 : 360,
                   minHeight: expanded ? 600 : 520, idealHeight: expanded ? 850 : 560)
            .background(ExpandableToolWindowSizing(expanded: expanded, compactSize: NSSize(width: 360, height: 560)))
            .onChange(of: model.format) { _, _ in model.invalidate() }
            .onChange(of: model.quality) { _, _ in model.invalidate() }
            .onChange(of: model.sourceURL) { _, _ in previewResult = true }
            .dropDestination(for: URL.self) { urls, _ in
                guard !urls.isEmpty, urls.allSatisfy(\.isFileURL), !model.busy else { return false }
                model.load(urls); return true
            } isTargeted: { targeted = $0 }
    }
    private var preview: some View {
        VStack(spacing: 6) {
            if model.resultPreview != nil {
                Picker("プレビュー", selection: $previewResult) { Text("元画像").tag(false); Text("変換後").tag(true) }
                    .pickerStyle(.segmented).labelsHidden()
            }
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.35))
                if let image = previewResult ? (model.resultPreview ?? model.sourcePreview) : model.sourcePreview {
                    Image(nsImage: image).resizable().scaledToFit().padding(8)
                        .accessibilityLabel(previewResult && model.resultPreview != nil ? "変換後のプレビュー" : "元画像のプレビュー")
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "photo.badge.plus").font(.system(size: 32)).foregroundStyle(.orange)
                        Text("画像をここにドロップ").font(.headline)
                        Text("複数選択可 · 200枚まで").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }.frame(minHeight: 130, maxHeight: .infinity)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(targeted ? Color.orange : .clear, lineWidth: 3))
        }
    }
    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("サイズ").font(.caption.weight(.semibold))
                Spacer()
                Toggle("縦横比を維持", isOn: $model.keepRatio).font(.caption)
                    .onChange(of: model.keepRatio) { _, enabled in if enabled { model.dimensionChanged(widthChanged: true) } }
            }
            HStack(spacing: 6) {
                Text("幅").font(.caption)
                TextField("px", text: widthBinding).textFieldStyle(.roundedBorder).accessibilityLabel("幅")
                Text("高さ").font(.caption)
                TextField("px", text: heightBinding).textFieldStyle(.roundedBorder).accessibilityLabel("高さ")
                Text("px").font(.caption).foregroundStyle(.secondary)
            }
            Picker("出力形式", selection: $model.format) {
                ForEach(ImageResizer.Format.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            if model.size == nil, model.input != nil {
                Text("1〜16,384 px、合計4,000万画素以内で指定してください")
                    .font(.caption).foregroundStyle(.orange)
            }
        }.disabled(model.busy || model.input == nil)
    }
    private var settings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("元画像からの倍率").font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach([25, 50, 75, 100, 200], id: \.self) { percent in
                    Button("\(percent)%") { model.preset(Double(percent) / 100) }
                }
            }.disabled(model.busy || model.input == nil)
            if model.format == .jpeg {
                Text("JPEG品質 \(Int((model.quality * 100).rounded()))%").font(.caption)
                Slider(value: $model.quality, in: 0.1...1, step: 0.01).disabled(model.busy)
            }
            ThemeMenu()
            Text("一括処理の倍率は各画像の元サイズが基準。縦横比ONでは最後に入力した幅か高さを適用し、反対側を画像ごとに計算します。OFFは全画像を指定サイズに揃えます。")
                .font(.caption).foregroundStyle(.secondary)
            Text("JPEG・PNG・WebP・HEIC・TIFF、1枚50MiBまで。元画像への上書き不可。JPEGの透明部分は白、PNGは透明を保持。向きを補正しsRGBで出力、EXIF・GPSは引き継ぎません。アニメーション・複数ページは非対応。")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(12).frame(width: 300)
    }
}
