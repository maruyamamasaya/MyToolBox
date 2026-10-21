import SwiftUI
import ImageIO
import UniformTypeIdentifiers
@main struct RenderCompactImageResizer {
    @MainActor static func main() async throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let folder = URL(fileURLWithPath: "build/image-compact-preview")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let suite = "test.image.compact.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
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
        let second = folder.appendingPathComponent("second.png")
        try original.write(to: second)
        let batch = ImageResizerModel(); batch.load([sourceURL, second]); try await wait(batch)
        batch.preset(0.5)
        let batchParent = folder.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: batchParent, withIntermediateDirectories: true)
        batch.resizeBatch(in: batchParent); try await wait(batch)
        guard batch.batchResults.count == 2, batch.batchResults.allSatisfy({ $0.hasPrefix("保存済み") }) else { fatalError("batch resize") }
        for theme in VisualTheme.allCases {
            for batchMode in [false, true] {
                let current = batchMode ? batch : model
                let savedOutput = current.output, savedWidth = current.width, savedHeight = current.height
                let savedBatch = current.batchResults
                for expanded in [false, true, false] {
                    let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "画像リサイズ") {
                        ImageResizerView(model: current, initiallyExpanded: expanded)
                    }.defaultAppStorage(defaults))
                    let size = NSSize(width: expanded ? 1100 : 360, height: (expanded ? 850 : 560) + (theme == .windows98 ? 30 : 0))
                    let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
                    window.contentView = host; host.frame = NSRect(origin: .zero, size: size)
                    window.displayIfNeeded(); try await Task.sleep(for: .milliseconds(100)); host.layoutSubtreeIfNeeded()
                    guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { fatalError("render") }
                    host.cacheDisplay(in: host.bounds, to: rep)
                    try rep.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent(theme.rawValue + (batchMode ? "-batch" : "-single") + (expanded ? "-expanded" : "-compact") + ".png"))
                    guard current.output == savedOutput, current.width == savedWidth, current.height == savedHeight, current.batchResults == savedBatch else { fatalError("state lost on layout change") }
                    print("PASS \(theme.rawValue) batch=\(batchMode) expanded=\(expanded) fitting \(host.fittingSize)")
                }
            }
        }
        guard try Data(contentsOf: sourceURL) == original else { fatalError("source modified") }
        let window = NSWindow(contentRect: NSRect(x: 0,y: 0,width: 360,height: 560), styleMask: [.titled,.resizable], backing: .buffered, defer: false)
        let bridge = ExpandableToolWindowSizing.Host(frame: .zero)
        bridge.compactSize = NSSize(width: 360, height: 560); window.contentView = bridge
        bridge.apply(); let compact = window.contentLayoutRect.size
        bridge.expanded = true; bridge.apply(); let large = window.contentLayoutRect.size
        bridge.expanded = false; bridge.apply()
        guard compact == window.contentLayoutRect.size, large.width > compact.width, compact.height == 560 else { fatalError("resize roundtrip") }
        model.stop(); batch.stop()
        print("PASS native size roundtrip / source preserved / real single and batch output")
    }
    @MainActor static func wait(_ model: ImageResizerModel) async throws {
        for _ in 0..<200 { if !model.busy { return }; try await Task.sleep(for: .milliseconds(50)) }
        throw ToolFailure.message("image model timeout")
    }
}
