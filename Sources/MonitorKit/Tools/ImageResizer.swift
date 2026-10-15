import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

public enum ImageResizer {
    public static let maxBytes = 30 * 1024 * 1024
    public static let maxPixels = 40_000_000
    public enum Format: String, CaseIterable, Sendable {
        case png = "PNG", jpeg = "JPEG"
        public var type: UTType { self == .png ? .png : .jpeg }
        public var fileExtension: String { self == .png ? "png" : "jpg" }
    }
    public struct Input: Sendable {
        public let data: Data
        public let width: Int
        public let height: Int
        public let isJPEG: Bool
    }
    public struct Size: Equatable, Sendable {
        public let width: Int
        public let height: Int
        public init(width: Int, height: Int) { self.width = width; self.height = height }
    }
    public enum Failure: LocalizedError {
        case message(String)
        public var errorDescription: String? { if case .message(let value) = self { return value }; return nil }
    }
    public static func validate(_ size: Size) throws {
        guard (1...16384).contains(size.width), (1...16384).contains(size.height), size.width * size.height <= maxPixels else {
            throw Failure.message("幅・高さは1〜16,384 px、合計4,000万画素以内で指定してください")
        }
    }
    public static func scaled(width: Int, height: Int, scale: Double) throws -> Size {
        guard width > 0, height > 0, scale.isFinite, scale > 0,
              Double(width) * scale <= 16384, Double(height) * scale <= 16384 else { throw Failure.message("この倍率ではサイズ上限を超えます") }
        let size = Size(width: max(1, Int((Double(width) * scale).rounded())), height: max(1, Int((Double(height) * scale).rounded())))
        try validate(size); return size
    }
    public static func inspect(_ data: Data) throws -> Input {
        guard !data.isEmpty, data.count <= maxBytes else { throw Failure.message("30MiB以下の画像を選択してください") }
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let type = CGImageSourceGetType(source) as String?,
              [UTType.jpeg.identifier, UTType.png.identifier, UTType.webP.identifier, UTType.heic.identifier, UTType.heif.identifier, UTType.tiff.identifier].contains(type),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = properties[kCGImagePropertyPixelWidth] as? Int,
              let h = properties[kCGImagePropertyPixelHeight] as? Int, w > 0, h > 0,
              w <= 100000, h <= 100000, w * h <= maxPixels else { throw Failure.message("対応画像を読み込めません。入力は4,000万画素以内です") }
        guard CGImageSourceGetCount(source) == 1 else { throw Failure.message("アニメーション・複数ページ画像には対応していません") }
        let orientation = properties[kCGImagePropertyOrientation] as? Int ?? 1
        let rotated = (5...8).contains(orientation)
        return Input(data: data, width: rotated ? h : w, height: rotated ? w : h, isJPEG: type == UTType.jpeg.identifier)
    }
    public static func read(_ url: URL) throws -> Input {
        let attributes = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard attributes.isRegularFile == true, let bytes = attributes.fileSize, bytes <= maxBytes else { throw Failure.message("30MiB以下の画像ファイルを選択してください") }
        return try inspect(Data(contentsOf: url))
    }
    public static func preview(_ data: Data, maxDimension: Int = 1000) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxDimension,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { throw Failure.message("画像のデコードに失敗しました") }
        return image
    }
    public static func resize(_ input: Input, to size: Size, format: Format, quality: Double) throws -> Data {
        try validate(size)
        guard quality.isFinite, (0.1...1).contains(quality) else { throw Failure.message("JPEG品質は10〜100%で指定してください") }
        // ImageIO applies EXIF orientation before drawing. The output contains pixels only.
        let image = try preview(input.data, maxDimension: max(input.width, input.height))
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: size.width, height: size.height, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw Failure.message("画像用メモリを確保できませんでした") }
        let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        if format == .jpeg { context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(rect) }
        context.interpolationQuality = .high
        context.draw(image, in: rect)
        guard let output = context.makeImage() else { throw Failure.message("リサイズに失敗しました") }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, format.type.identifier as CFString, 1, nil) else { throw Failure.message("出力形式を利用できません") }
        CGImageDestinationAddImage(destination, output, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw Failure.message("画像の書き出しに失敗しました") }
        return data as Data
    }
    public static func save(_ data: Data, to url: URL, protecting source: URL) throws {
        let sourceURL = source.resolvingSymlinksInPath().standardizedFileURL
        let targetURL = url.resolvingSymlinksInPath().standardizedFileURL
        guard sourceURL != targetURL else { throw Failure.message("元画像とは別の保存先を指定してください") }
        // Also protect a hard link to the input file.
        let sourceID = try? source.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier
        let targetID = try? url.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier
        if let a = sourceID as? NSObject, let b = targetID as? NSObject, a.isEqual(b) {
            throw Failure.message("元画像と同じファイルには保存できません")
        }
        try data.write(to: url, options: .atomic)
    }
}
