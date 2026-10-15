import SwiftUI

/// Original 16×16 drawings, aligned to a pixel grid; no Microsoft artwork or font assets.
struct ClassicToolIcon: View {
    let symbol: String
    var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width / 16, y: size.height / 16)
            func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, _ color: Color) {
                context.fill(Path(CGRect(x: x, y: y, width: width, height: height)), with: .color(color))
            }
            let black = Color(hex: 0x202020), gray = Color(hex: 0x808080), blue = Color(hex: 0x000080), teal = Color(hex: 0x008080), yellow = Color(hex: 0xf5d54a)
            if symbol == "waveform.path.ecg" || symbol == "desktopcomputer" || symbol == "app.window" || symbol == "cpu" {
                rect(1, 1, 14, 11, black); rect(2, 2, 12, 9, .white); rect(3, 3, 10, 7, blue)
                rect(7, 12, 2, 2, gray); rect(4, 14, 8, 1, black)
                rect(4, 7, 2, 1, .green); rect(6, 5, 1, 3, .green); rect(7, 7, 2, 1, .green); rect(9, 4, 1, 4, .green); rect(10, 6, 2, 1, .green)
            } else if symbol.contains("calendar") {
                rect(1, 2, 14, 13, black); rect(2, 3, 12, 11, .white); rect(2, 3, 12, 3, blue)
                rect(4, 1, 2, 3, gray); rect(10, 1, 2, 3, gray)
                for row in 0..<2 { for column in 0..<3 { rect(CGFloat(4 + column * 3), CGFloat(8 + row * 3), 2, 2, column == 0 ? .red : black) } }
            } else if symbol.contains("headphone") || symbol.contains("speaker") {
                rect(1, 5, 4, 6, black); rect(2, 6, 3, 4, gray); rect(5, 4, 1, 8, black); rect(6, 3, 1, 10, black); rect(7, 2, 1, 12, black)
                rect(10, 6, 1, 4, blue); rect(12, 4, 1, 8, blue); rect(14, 2, 1, 12, blue)
            } else if symbol.contains("mic") {
                rect(6, 1, 4, 8, black); rect(7, 2, 2, 5, gray); rect(4, 6, 1, 5, black); rect(11, 6, 1, 5, black)
                rect(5, 11, 6, 1, black); rect(7, 12, 2, 2, gray); rect(4, 14, 8, 1, black)
            } else {
                rect(2, 1, 11, 14, black); rect(3, 2, 9, 12, .white); rect(12, 5, 2, 10, gray)
                if symbol.contains("table") || symbol.contains("clipboard") {
                    rect(4, 4, 7, 8, teal)
                    for row in [6, 9] { rect(4, CGFloat(row), 7, 1, .white) }
                    rect(7, 4, 1, 8, .white)
                    if symbol.contains("clipboard") { rect(5, 0, 5, 3, gray) }
                } else if symbol.contains("magnifyingglass") {
                    rect(4, 4, 7, 6, blue); rect(5, 5, 5, 4, Color(hex: 0xb5dcff)); rect(10, 10, 2, 2, black); rect(12, 12, 3, 3, black)
                } else if symbol.contains("pencil") {
                    for i in 0..<8 { rect(CGFloat(5+i), CGFloat(12-i), 3, 2, black); rect(CGFloat(5+i), CGFloat(12-i), 2, 1, yellow) }
                } else {
                    for row in 0..<4 { rect(4, CGFloat(4+row*2), 7, 1, row == 0 ? blue : black) }
                    if symbol.contains("sparkles") { rect(9, 1, 2, 6, yellow); rect(7, 3, 6, 2, yellow) }
                    if symbol.contains("split") { rect(7, 3, 1, 10, .red) }
                }
            }
        }.accessibilityHidden(true)
    }
}
