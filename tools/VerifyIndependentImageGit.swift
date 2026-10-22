import SwiftUI
import ImageIO
import UniformTypeIdentifiers

/// Real image and Git models. No application launch, global keys, panels or external remotes.
@main struct VerifyIndependentImageGit {
    @MainActor static func main() async throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        func check(_ condition: Bool, _ name: String) throws {
            guard condition else { throw NSError(domain: name, code: 1) }; FileHandle.standardOutput.write(Data(("PASS: " + name + "\n").utf8))
        }
        func wait(_ condition: () -> Bool) async throws {
            let deadline = ContinuousClock.now + .seconds(30)
            while condition() {
                guard ContinuousClock.now < deadline else { throw NSError(domain: "model operation timed out", code: 1) }
                try await Task.sleep(for: .milliseconds(20))
            }
        }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("MyToolBox-ImageGitProbe-" + UUID().uuidString).resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let suite = "local.MyToolBox.ImageGitProbe." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        try check(IndependentTools.tools.contains(.imageResizer) && IndependentTools.tools.contains(.gitBatch), "both tools use independent routes")
        try check(IndependentTools.identifier(.imageResizer) != IndependentTools.identifier(.gitBatch), "separate application identities")

        func makeImage(_ name: String, width: Int, height: Int) throws -> URL {
            let url = folder.appendingPathComponent(name)
            let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.setFillColor(CGColor(red: 0.05, green: 0.2, blue: 0.4, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
            context.setFillColor(CGColor(red: 1, green: 0.65, blue: 0.15, alpha: 1)); context.fillEllipse(in: CGRect(x: CGFloat(width) / 3, y: CGFloat(height) / 3, width: CGFloat(width) / 3, height: CGFloat(height) / 3))
            let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
            CGImageDestinationAddImage(destination, context.makeImage()!, nil)
            guard CGImageDestinationFinalize(destination) else { throw NSError(domain: "fixture encoding", code: 1) }
            return url
        }
        let source = try makeImage("source.png", width: 800, height: 500)
        let second = try makeImage("second.png", width: 320, height: 160)
        let original = try Data(contentsOf: source), secondOriginal = try Data(contentsOf: second)
        let image = ImageResizerModel()
        image.load(source)
        try check(image.busy, "image load starts asynchronously")
        try await wait { image.busy }
        try check(image.input?.width == 800 && image.sourcePreview != nil && image.sourceURL == source, "image model retains source and preview")
        image.width = "400"; image.dimensionChanged(widthChanged: true)
        image.format = .jpeg; image.quality = 0.72
        try check(image.height == "250", "image sizing retains aspect ratio")
        image.resize()
        try check(image.busy && image.format == .jpeg && image.quality == 0.72, "resize keeps settings while processing")
        try await wait { image.busy }
        guard let output = image.output else { throw NSError(domain: image.status, code: 1) }
        try check(image.resultPreview != nil && image.sourceURL == source, "completed resize retains output and both previews")
        let savedImage = folder.appendingPathComponent("resized.jpg")
        image.save(to: savedImage); try await wait { image.busy }
        let loaded = try ImageResizer.read(savedImage)
        try check(loaded.width == 400 && loaded.height == 250 && loaded.isJPEG && image.output == output, "image model saves exact-sized JPEG without dropping output")
        image.save(to: source); try await wait { image.busy }
        try check((try Data(contentsOf: source)) == original && image.output == output && image.resultPreview != nil, "source-overwrite rejection preserves source and completed work")
        // Recover the status after testing a rejected save without touching the input.
        image.save(to: savedImage); try await wait { image.busy }
        let invalid = folder.appendingPathComponent("invalid.png")
        try Data("not an image".utf8).write(to: invalid)
        let batch = ImageResizerModel()
        batch.load([source, invalid, second]); try await wait { batch.busy }
        batch.preset(0.5); batch.format = .png
        batch.resizeBatch(in: folder)
        try check(batch.busy && batch.batchURLs.count == 3, "batch keeps inputs while worker runs")
        batch.load(source)
        try check(batch.batchURLs.count == 3, "reentrant load cannot replace an active batch")
        try await wait { batch.busy }
        try check(batch.batchResults.count == 3 && batch.batchResults.filter { $0.hasPrefix("保存済み") }.count == 2 && batch.batchResults.filter { $0.hasPrefix("失敗") }.count == 1, "batch continues after bad input and retains all results")
        guard let directory = batch.batchDirectory else { throw NSError(domain: "batch directory missing", code: 1) }
        let batchFiles = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let sizes = try batchFiles.map { try ImageResizer.read($0) }
        try check(sizes.count == 2 && sizes.contains { $0.width == 400 && $0.height == 250 } && sizes.contains { $0.width == 160 && $0.height == 80 }, "batch uses each source's dimensions and writes real PNGs")
        try check((try Data(contentsOf: source)) == original && (try Data(contentsOf: second)) == secondOriginal, "batch leaves all originals intact")

        let hooks = folder.appendingPathComponent("empty-hooks")
        let repos = folder.appendingPathComponent("repos")
        for url in [hooks, repos] { try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true) }
        func git(_ path: URL, _ args: [String]) throws -> String {
            try GitBatchCommand.run(path: path.path, arguments: ["-c", "core.hooksPath=" + hooks.path, "-c", "init.templateDir="] + args)
        }
        func configure(_ path: URL) throws {
            for (key, value) in [("user.name", "Isolated Test"), ("user.email", "test@example.invalid"), ("commit.gpgsign", "false"), ("core.hooksPath", hooks.path)] {
                _ = try git(path, ["config", key, value])
            }
        }
        let bare = folder.appendingPathComponent("origin.git")
        let local = repos.appendingPathComponent("日本語 repo")
        let other = folder.appendingPathComponent("other")
        _ = try git(folder, ["init", "--bare", "--initial-branch=main", bare.path]); try configure(bare)
        _ = try git(folder, ["clone", bare.path, local.path]); try configure(local)
        let file = local.appendingPathComponent("sample.txt")
        try "initial".write(to: file, atomically: true, encoding: .utf8)
        _ = try git(local, ["add", "sample.txt"]); _ = try git(local, ["commit", "-m", "initial"])
        _ = try git(local, ["push", "origin", "main"])
        _ = try git(folder, ["clone", bare.path, other.path]); try configure(other)
        defaults.set(repos.path, forKey: "tools.gitBatch.root")
        let model = GitBatchModel(defaults: defaults)
        func selectedLocalRepo() -> Bool {
            // FileManager enumeration returns /private/var while temporaryDirectory uses /var.
            model.selected.count == 1 && model.selected == Set(model.rows.map(\.path)) &&
                model.selected.first.map { URL(fileURLWithPath: $0).resolvingSymlinksInPath().path } == local.resolvingSymlinksInPath().path
        }
        let draftMessage = "作業メモ $(literal) `text`"
        model.message = draftMessage
        try check(model.root == repos.path && model.canClose, "Git restores selected folder from shared-domain-compatible defaults")
        model.load()
        try check(model.busy && !model.canClose, "Git load prevents helper termination")
        model.load(); try await wait { model.busy }
        try check(model.rows.count == 1 && model.selected.isEmpty && model.message == draftMessage && model.canClose, "Git discovery retains folder selection and message")
        model.selected = Set(model.rows.map(\.path))
        try check(GitBatchModel(defaults: defaults).root == repos.path, "Git root persists for a new model")
        var decisions = 0
        model.run(.check)
        try check(model.busy && !model.canClose, "Git operation keeps helper alive while busy")
        model.run(.finish, decide: { decisions += 1; return true })
        try check(decisions == 0 && model.message == draftMessage, "Git rejects reentrant actions before confirmation")
        try await wait { model.busy }
        try check(model.rows.first?.succeeded == true && model.canClose, "Git check completes against a local-only origin")
        try "edited locally".write(to: file, atomically: true, encoding: .utf8)
        model.load(); try await wait { model.busy }
        let beforeHead = try git(local, ["rev-parse", "HEAD"])
        model.run(.finish, decide: { false })
        try check(!model.busy && (try git(local, ["rev-parse", "HEAD"])) == beforeHead && (try String(contentsOf: file, encoding: .utf8)) == "edited locally", "cancelled Git confirmation preserves work and commit draft")
        model.run(.finish, decide: { true }); try await wait { model.busy }
        try check(model.rows.first?.succeeded == true && model.message == draftMessage && selectedLocalRepo(), "Git commit and local-only push retain selected work context")
        try check((try git(local, ["log", "-1", "--format=%s"])).trimmingCharacters(in: .newlines) == draftMessage && (try git(local, ["rev-parse", "HEAD"])) == (try git(bare, ["rev-parse", "main"])), "Git uses literal message and updates isolated bare origin")
        _ = try git(other, ["pull", "--ff-only"])
        try "remote update".write(to: other.appendingPathComponent("sample.txt"), atomically: true, encoding: .utf8)
        _ = try git(other, ["commit", "-am", "remote update"]); _ = try git(other, ["push", "origin", "main"])
        model.run(.check); try await wait { model.busy }
        try check(model.rows.first?.behind == 1, "Git detects an isolated remote update")
        model.run(.start, decide: { true }); try await wait { model.busy }
        try check(model.rows.first?.succeeded == true && model.canClose && (try String(contentsOf: file, encoding: .utf8)) == "remote update", "Git fast-forward completes and restores close permission")
        let failing = GitBatchModel(defaults: defaults)
        failing.root = folder.appendingPathComponent("missing").path; failing.load(); try await wait { failing.busy }
        try check(failing.canClose && failing.rows.isEmpty && GitBatchModel(defaults: defaults).root == repos.path, "Git discovery failure releases busy state without replacing saved root")
        try check(image.output == output && batch.batchResults.count == 3 && model.message == draftMessage, "image and Git model state stays independent")

        let previewFolder = URL(fileURLWithPath: "build/independent-image-git-preview")
        try FileManager.default.createDirectory(at: previewFolder, withIntermediateDirectories: true)
        for theme in VisualTheme.allCases {
            for mode in ["image", "batch", "git"] {
                let size = NSSize(width: 1050, height: mode == "git" ? 800 : 1120)
                let title = mode == "git" ? "Git一括管理" : "画像リサイズ"
                let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: title) {
                    if mode == "git" { GitBatchView(model: model) }
                    else { ImageResizerView(model: mode == "batch" ? batch : image) }
                }.defaultAppStorage(defaults))
                let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
                window.appearance = NSAppearance(named: theme == .windows98 ? .aqua : .darkAqua)
                window.contentView = host; host.frame = NSRect(origin: .zero, size: size)
                window.displayIfNeeded(); try await Task.sleep(for: .milliseconds(250)); host.layoutSubtreeIfNeeded()
                guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw NSError(domain: "render failed", code: 1) }
                host.cacheDisplay(in: host.bounds, to: bitmap)
                guard let png = bitmap.representation(using: .png, properties: [:]) else { throw NSError(domain: "PNG encoding failed", code: 1) }
                try png.write(to: previewFolder.appendingPathComponent(mode + "-" + theme.rawValue + ".png"))
                print("PASS: offscreen " + mode + " / " + theme.rawValue)
            }
        }
    }
}
