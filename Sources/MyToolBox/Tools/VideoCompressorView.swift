import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

@MainActor final class VideoCompressorModel: ObservableObject {
    @Published var urls: [URL] = []
    @Published var quality = VideoCompression.Quality.balanced
    @Published var busy = false
    @Published var progress: Double = 0
    @Published var status = "動画を選択、またはここにドロップ"
    @Published var results: [String] = []
    @Published var directory: URL?
    private var session: AVAssetExportSession?
    private var task: Task<Void, Never>?
    func load(_ inputs: [URL]) {
        guard !busy else { return }
        let files = inputs.filter(\.isFileURL)
        guard !files.isEmpty, files.count <= 200 else { status = "動画は一度に200本まで選べます"; return }
        var seen = Set<URL>()
        urls = files.filter { seen.insert($0.standardizedFileURL).inserted }
        results = []; directory = nil; status = "\(urls.count)本を選択しました"
    }
    func open() {
        guard !busy else { return }
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.movie, .video]
        panel.allowsMultipleSelection = true; panel.canChooseDirectories = false
        if panel.runModal() == .OK { load(panel.urls) }
    }
    func start() {
        guard !busy, !urls.isEmpty else { return }
        let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true
        panel.canCreateDirectories = true; panel.prompt = "ここに保存"
        panel.message = "新しい圧縮動画フォルダを作成します。元動画は変更しません。"
        if panel.runModal() == .OK, let parent = panel.url { start(in: parent) }
    }
    func start(in parent: URL) {
        guard !busy, !urls.isEmpty else { return }
        let inputs = urls, selected = quality
        busy = true; progress = 0; results = []; directory = nil
        task = Task {
            do {
                let folder = try VideoCompression.beginBatch(in: parent); directory = folder
                var succeeded = 0
                for (index, input) in inputs.enumerated() {
                    try Task.checkCancellation()
                    let output = VideoCompression.outputURL(for: input, index: index, directory: folder)
                    status = "\(index + 1) / \(inputs.count)：\(input.lastPathComponent)"
                    do {
                        let original = try VideoCompression.bytes(at: input)
                        let asset = AVURLAsset(url: input)
                        guard !(try await asset.loadTracks(withMediaType: .video)).isEmpty else {
                            throw Failure.message("映像トラックがありません")
                        }
                        try Task.checkCancellation()
                        guard let exporter = AVAssetExportSession(asset: asset, presetName: selected.preset), exporter.supportedFileTypes.contains(.mp4) else {
                            throw Failure.message("この動画はMP4へ変換できません")
                        }
                        session = exporter; exporter.outputURL = output; exporter.outputFileType = .mp4
                        exporter.shouldOptimizeForNetworkUse = true
                        let ticker = Task { [weak self] in
                            while !Task.isCancelled {
                                self?.progress = (Double(index) + Double(exporter.progress)) / Double(inputs.count)
                                try? await Task.sleep(for: .milliseconds(250))
                            }
                        }
                        await exporter.export(); ticker.cancel(); session = nil
                        try Task.checkCancellation()
                        guard exporter.status == .completed else { throw exporter.error ?? Failure.message("変換に失敗しました") }
                        let size = try VideoCompression.bytes(at: output)
                        // Keep only useful compressed copies; never remove the source.
                        if size >= original {
                            try FileManager.default.removeItem(at: output)
                            results.append("縮小なし：\(input.lastPathComponent)（元動画を保持）")
                        } else {
                            succeeded += 1
                            let percent = Int((1 - Double(size) / Double(max(1, original))) * 100)
                            results.append("保存：\(output.lastPathComponent) · \(Self.bytes(original)) → \(Self.bytes(size))（\(percent)%削減）")
                        }
                    } catch {
                        try? FileManager.default.removeItem(at: output)
                        if Task.isCancelled { throw CancellationError() }
                        results.append("失敗：\(input.lastPathComponent) — \(error.localizedDescription)")
                    }
                    progress = Double(index + 1) / Double(inputs.count)
                }
                status = "完了：\(succeeded)本保存。各動画の結果を確認してください"
            } catch { status = Task.isCancelled ? "キャンセルしました。保存済みの動画は残っています" : error.localizedDescription }
            session = nil; busy = false
        }
    }
    func stop() { task?.cancel(); session?.cancelExport() }
    static func bytes(_ value: Int64) -> String { ByteCountFormatter.string(fromByteCount: value, countStyle: .file) }
    enum Failure: LocalizedError {
        case message(String)
        var errorDescription: String? { if case let .message(text) = self { return text }; return nil }
    }
}

struct VideoCompressorView: View {
    @ObservedObject var model: VideoCompressorModel
    @State private var targeted = false
    var body: some View {
        ToolPage("動画圧縮", subtitle: "複数の動画をまとめてMP4へ", symbol: "film", tint: .blue) {
          ScrollView { VStack(spacing: 12) {
            ToolCard { VStack(alignment: .leading, spacing: 8) {
                Text("動画").font(.headline)
                Button("動画を選択…", action: model.open).disabled(model.busy)
                Text("ここに動画をドロップ · 最大200本").font(.caption).foregroundStyle(.secondary)
                ScrollView {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(Array(model.urls.enumerated()), id: \.offset) { _, url in
                            Text(url.lastPathComponent).font(.caption).lineLimit(2).help(url.path)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.frame(height: 90)
            }}
            ToolCard { VStack(alignment: .leading, spacing: 8) {
                Text("圧縮設定").font(.headline)
                Picker("画質", selection: $model.quality) {
                    ForEach(VideoCompression.Quality.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.disabled(model.busy)
                Text("MP4 · 元動画を保持。容量は内容によって変わります。小さくならない変換結果は保存しません。HDR・字幕・複数音声などは保持されない場合があります。")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("圧縮して保存…", action: model.start).buttonStyle(.borderedProminent)
                        .disabled(model.busy || model.urls.isEmpty)
                    if model.busy { Button("キャンセル", action: model.stop) }
                }
                if model.busy { ProgressView(value: model.progress) }
                Text(model.status).font(.caption).textSelection(.enabled)
            }}
            if !model.results.isEmpty || model.directory != nil {
                ToolCard { VStack(alignment: .leading, spacing: 8) {
                    Text("結果").font(.headline)
                    if let folder = model.directory { Button("保存先を開く") { NSWorkspace.shared.open(folder) } }
                    ScrollView {
                        VStack(alignment: .leading, spacing: 7) {
                            ForEach(Array(model.results.enumerated()), id: \.offset) { _, result in
                                Text(result).font(.caption).textSelection(.enabled)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.frame(height: 120)
                }}
            }
          }.padding(12) }
        }.frame(minWidth: 420, idealWidth: 460, minHeight: 540)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(targeted ? Color.blue : .clear, lineWidth: 3))
            .dropDestination(for: URL.self) { urls, _ in
                guard !model.busy, !urls.isEmpty, urls.allSatisfy(\.isFileURL) else { return false }
                model.load(urls); return true
            } isTargeted: { targeted = $0 }
    }
}
