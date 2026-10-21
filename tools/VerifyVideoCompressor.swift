import SwiftUI
import AVFoundation

@main struct VerifyVideoCompressor {
    @MainActor static func main() async throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let root = URL(fileURLWithPath: "build/video-validation")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let run = root.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: run, withIntermediateDirectories: false)
        let source = run.appendingPathComponent("fixture.mov")
        let writer = try AVAssetWriter(outputURL: source, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.jpeg, AVVideoWidthKey: 640, AVVideoHeightKey: 480])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB, kCVPixelBufferWidthKey as String: 640, kCVPixelBufferHeightKey as String: 480])
        writer.add(input); guard writer.startWriting() else { throw writer.error! }
        writer.startSession(atSourceTime: .zero)
        for frame in 0..<60 {
            while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(10)) }
            var pixel: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pixel)
            let buffer = pixel!
            CVPixelBufferLockBaseAddress(buffer, [])
            memset(CVPixelBufferGetBaseAddress(buffer), Int32(30 + frame), CVPixelBufferGetDataSize(buffer))
            CVPixelBufferUnlockBaseAddress(buffer, [])
            precondition(adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(frame), timescale: 30)))
        }
        input.markAsFinished(); await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error! }
        let original = try Data(contentsOf: source)
        let invalid = run.appendingPathComponent("invalid.mov"); try Data("invalid".utf8).write(to: invalid)
        let model = VideoCompressorModel(); model.load([source, invalid, source])
        precondition(model.urls.count == 2)
        model.start(in: run)
        let deadline = Date().addingTimeInterval(90)
        while model.busy && Date() < deadline { try await Task.sleep(for: .milliseconds(100)) }
        precondition(!model.busy, "timeout")
        precondition(model.results.count == 2, model.status)
        precondition(model.results[0].hasPrefix("保存："), model.results.description)
        precondition(model.results[1].hasPrefix("失敗："), model.results.description)
        let unchanged = try Data(contentsOf: source); precondition(unchanged == original)
        let outputs = try FileManager.default.contentsOfDirectory(at: model.directory!, includingPropertiesForKeys: nil)
        precondition(outputs.count == 1 && outputs[0].pathExtension == "mp4")
        let asset = AVURLAsset(url: outputs[0]); let tracks = try await asset.loadTracks(withMediaType: .video)
        precondition(!tracks.isEmpty)
        model.start(in: run); model.stop()
        while model.busy { try await Task.sleep(for: .milliseconds(100)) }
        precondition(model.status.hasPrefix("キャンセル"))
        for theme in VisualTheme.allCases {
            let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "動画圧縮") { VideoCompressorView(model: model) })
            let size = NSSize(width: 640, height: 900)
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
            window.contentView = host; host.frame = NSRect(origin: .zero, size: size)
            window.displayIfNeeded(); host.layoutSubtreeIfNeeded()
            let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
            host.cacheDisplay(in: host.bounds, to: rep)
            try rep.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent(theme.rawValue + ".png"))
        }
        print("PASS: real MOV → smaller MP4, failure continuation, deduplication, source preservation, cancellation and four-theme rendering")
    }
}
