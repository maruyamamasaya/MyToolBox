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
    private var widthBinding: Binding<String> { Binding(get: { model.width }, set: { model.width = $0; model.dimensionChanged(widthChanged: true) }) }
    private var heightBinding: Binding<String> { Binding(get: { model.height }, set: { model.height = $0; model.dimensionChanged(widthChanged: false) }) }
    var body: some View {
        ToolPage("画像リサイズ", subtitle: "複数画像を選んで、同じ設定でまとめてリサイズ。", symbol: "photo", tint: .orange) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ToolCard {
                        HStack(spacing: 18) {
                            if let preview = model.sourcePreview { Image(nsImage: preview).resizable().scaledToFit().frame(width: 120, height: 90) }
                            else { Image(systemName: "photo.badge.plus").font(.system(size: 40)).foregroundStyle(.orange).frame(width: 120, height: 90) }
                            VStack(alignment: .leading, spacing: 8) {
                                Text(model.isBatch ? "\(model.batchURLs.count)枚を選択中" : model.sourceURL?.lastPathComponent ?? "ここに画像をドロップ").font(.headline).lineLimit(2)
                                if let input = model.input { Text("\(input.width) × \(input.height) px · \(ImageResizerModel.bytes(input.data.count))").foregroundStyle(.secondary) }
                                else { Text("JPEG・PNG・WebP・HEIC・TIFF ／ 1枚50MiB・200枚まで").font(.caption).foregroundStyle(.secondary) }
                            }
                            Spacer()
                            Button("画像を選択…") { model.open() }.controlSize(.large)
                        }
                    }.overlay { RoundedRectangle(cornerRadius: 10).stroke(targeted ? Color.orange : .clear, lineWidth: 3) }
                    ToolCard {
                        VStack(alignment: .leading, spacing: 18) {
                            ToolSectionLabel(title: "サイズを指定", symbol: "arrow.up.left.and.arrow.down.right")
                            if model.isBatch {
                                Text("倍率は各画像の元サイズが基準です。縦横比を維持する場合は最後に入力した幅または高さを全画像に適用し、反対側は画像ごとに計算します。OFFでは全画像を指定の幅×高さに揃えます。先頭の読み込める画像をプレビューしています。")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            HStack { ForEach([25, 50, 75, 100, 200], id: \.self) { percent in Button("\(percent)%") { model.preset(Double(percent) / 100) } }; Spacer() }
                            HStack(spacing: 12) {
                                Text("幅"); TextField("px", text: widthBinding).frame(width: 100); Text("× 高さ"); TextField("px", text: heightBinding).frame(width: 100); Text("px").foregroundStyle(.secondary)
                                Spacer(); Toggle("縦横比を維持", isOn: $model.keepRatio).onChange(of: model.keepRatio) { _, enabled in if enabled { model.dimensionChanged(widthChanged: true) } }
                            }
                            HStack(spacing: 18) {
                                ThemePicker("出力形式", selection: $model.format, options: ImageResizer.Format.allCases.map { ($0, $0.rawValue) })
                                if model.format == .jpeg { Text("品質 \(Int((model.quality * 100).rounded()))%").monospacedDigit(); Slider(value: $model.quality, in: 0.1...1, step: 0.01).frame(maxWidth: 200) }
                                Spacer()
                                Button(model.isBatch ? "一括リサイズして保存…" : "リサイズする") { model.resize() }.buttonStyle(ThemeButtonStyle(prominent: true)).disabled(model.size == nil)
                            }
                            if model.size == nil, model.input != nil { Text("幅・高さは1〜16,384 px、合計4,000万画素以内で指定してください").font(.caption).foregroundStyle(.orange) }
                        }
                    }.disabled(model.input == nil)
                    if let preview = model.resultPreview, let output = model.output, let input = model.input {
                        ToolCard {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack { ToolSectionLabel(title: "できあがり", symbol: "checkmark.circle"); Spacer(); Button("画像を保存…") { model.save() }.buttonStyle(ThemeButtonStyle(prominent: true)) }
                                Image(nsImage: preview).resizable().scaledToFit().frame(maxWidth: .infinity).frame(height: 260).background(.gray.opacity(0.15))
                                Text("変換前：\(input.width) × \(input.height) px · \(ImageResizerModel.bytes(input.data.count))  →  変換後：\(model.width) × \(model.height) px · \(ImageResizerModel.bytes(output.count))（\(model.format.rawValue)）").font(.caption).textSelection(.enabled)
                            }
                        }
                    }
                    if !model.batchResults.isEmpty {
                        ToolCard {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    ToolSectionLabel(title: "一括処理の結果", symbol: "photo.on.rectangle")
                                    Spacer()
                                    if let directory = model.batchDirectory { Button("保存先を開く") { NSWorkspace.shared.open(directory) } }
                                }
                                ForEach(Array(model.batchResults.enumerated()), id: \.offset) { _, result in Text(result).font(.caption).textSelection(.enabled) }
                            }
                        }
                    }
                    HStack { if model.busy { ProgressView().controlSize(.small) }; Text(model.status).font(.caption).textSelection(.enabled) }
                    ToolFootnote(text: "画像処理は端末内で完結。JPEGの透明部分は白背景になります。PNGは透明を保持します。向きを補正してsRGBで出力し、元のEXIF・GPS情報は引き継ぎません。アニメーション・複数ページ画像は非対応。元画像には上書きできません。")
                }.padding(24).disabled(model.busy)
            }
        }.frame(minWidth: 900, minHeight: 780)
            .onChange(of: model.format) { _, _ in model.invalidate() }
            .onChange(of: model.quality) { _, _ in model.invalidate() }
            .dropDestination(for: URL.self) { urls, _ in
                guard !urls.isEmpty, urls.allSatisfy(\.isFileURL), !model.busy else { return false }
                model.load(urls); return true
            } isTargeted: { targeted = $0 }
    }
}
