// Synthetic local fixture; validates the actual model and image pipeline without touching user files.
import SwiftUI
import ImageIO
import UniformTypeIdentifiers

@main struct RenderImageResizer {
    @MainActor static func main() async throws {
        _ = NSApplication.shared
        let folder = URL(fileURLWithPath: "build/image-resizer-check")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let sourceURL = folder.appendingPathComponent("sample.png")
        let context = CGContext(data: nil, width: 800, height: 500, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 0.05, green: 0.2, blue: 0.4, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 800, height: 500))
        context.setFillColor(CGColor(red: 1, green: 0.65, blue: 0.15, alpha: 1)); context.fillEllipse(in: CGRect(x: 470, y: 230, width: 170, height: 170))
        context.setFillColor(CGColor(red: 0.1, green: 0.7, blue: 0.65, alpha: 1)); context.fill(CGRect(x: 90, y: 70, width: 330, height: 210))
        let destination = CGImageDestinationCreateWithURL(sourceURL as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        guard CGImageDestinationFinalize(destination) else { throw ToolFailure.message("fixture encoding") }
        let original = try Data(contentsOf: sourceURL)
        let model = ImageResizerModel(); model.load(sourceURL)
        try await wait(model)
        guard model.input?.width == 800, model.sourcePreview != nil else { throw ToolFailure.message("load failed: \(model.status)") }
        model.width = "400"; model.dimensionChanged(widthChanged: true)
        guard model.height == "250" else { throw ToolFailure.message("aspect ratio") }
        model.format = .jpeg; model.resize(); try await wait(model)
        guard let result = model.output, model.resultPreview != nil else { throw ToolFailure.message("resize failed: \(model.status)") }
        let resultURL = folder.appendingPathComponent("sample-400x250.jpg")
        try ImageResizer.save(result, to: resultURL, protecting: sourceURL)
        let loaded = try ImageResizer.read(resultURL)
        guard loaded.width == 400, loaded.height == 250, loaded.isJPEG, try Data(contentsOf: sourceURL) == original else { throw ToolFailure.message("saved file verification") }
        for theme in VisualTheme.allCases {
            let size = NSSize(width: 1000, height: 1120)
            let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "画像リサイズ") { ImageResizerView(model: model) })
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: theme == .windows98 ? .aqua : .darkAqua)
            window.contentView = host; host.frame = NSRect(origin: .zero, size: size)
            window.displayIfNeeded(); try await Task.sleep(nanoseconds: 300_000_000); host.layoutSubtreeIfNeeded()
            guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds), let png = bitmapPNG(host, bitmap) else { throw ToolFailure.message("render failed") }
            let output = URL(fileURLWithPath: "evidence/themes/\(theme.rawValue)")
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            try png.write(to: output.appendingPathComponent("tool-image-resizer.png"))
            print("Rendered \(theme.rawValue)")
        }
        model.preset(0.25)
        guard model.width == "200", model.height == "125", model.output == nil else { throw ToolFailure.message("preset / stale result") }
        model.load(folder.appendingPathComponent("missing.png")); try await wait(model)
        guard model.input == nil, model.output == nil, model.sourcePreview == nil else { throw ToolFailure.message("failed load stale result") }
        print("PASS: model load, aspect ratio, resize, real JPEG save/reload, original unchanged, stale result clearing, three themes")
    }
    @MainActor static func bitmapPNG(_ host: NSView, _ bitmap: NSBitmapImageRep) -> Data? { host.cacheDisplay(in: host.bounds, to: bitmap); return bitmap.representation(using: .png, properties: [:]) }
    @MainActor static func wait(_ model: ImageResizerModel) async throws {
        for _ in 0..<200 { if !model.busy { return }; try await Task.sleep(nanoseconds: 50_000_000) }
        throw ToolFailure.message("image model timeout")
    }
}
