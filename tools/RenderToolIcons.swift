// Render the actual packaged icons without opening windows or changing preferences.
import AppKit

@main struct RenderToolIcons {
    @MainActor static func main() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let output = root.appendingPathComponent("evidence/tool-icons")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let small = ProcessInfo.processInfo.arguments.contains("--small")
        let iconSize: CGFloat = small ? 32 : 96
        let columns = 7
        let cell = NSSize(width: 168, height: small ? 86 : 150)
        let rows = (ToolID.allCases.count + columns - 1) / columns
        let size = NSSize(width: CGFloat(columns) * cell.width, height: CGFloat(rows) * cell.height)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor(calibratedWhite: 0.10, alpha: 1).setFill()
        NSRect(origin: .zero, size: size).fill()
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph
        ]
        for (index, tool) in ToolID.allCases.enumerated() {
            let x = CGFloat(index % columns) * cell.width
            let y = size.height - CGFloat(index / columns + 1) * cell.height
            let path = root.appendingPathComponent("Resources/ToolIcons/\(tool.rawValue).icns")
            guard let icon = NSImage(contentsOf: path) else {
                throw NSError(domain: "RenderToolIcons", code: 1, userInfo: [NSLocalizedDescriptionKey: tool.rawValue])
            }
            icon.draw(in: NSRect(x: x + (cell.width - iconSize) / 2, y: y + 46, width: iconSize, height: iconSize),
                      from: .zero, operation: .sourceOver, fraction: 1)
            (tool.title as NSString).draw(in: NSRect(x: x + 6, y: y + 7, width: cell.width - 12, height: 32), withAttributes: attributes)
        }
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "RenderToolIcons", code: 2)
        }
        try png.write(to: output.appendingPathComponent(small ? "small-tools.png" : "all-tools.png"))
        print("Rendered \(ToolID.allCases.count) packaged tool icons")
    }
}
