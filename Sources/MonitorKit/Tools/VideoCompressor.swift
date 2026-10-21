import Foundation
import AVFoundation

public enum VideoCompression {
    public enum Quality: String, CaseIterable, Sendable {
        case balanced = "標準（1080pまで）", small = "小さめ（720pまで）", smallest = "最小（低画質）"
        public var preset: String {
            switch self {
            case .balanced: return AVAssetExportPreset1920x1080
            case .small: return AVAssetExportPreset1280x720
            case .smallest: return AVAssetExportPresetLowQuality
            }
        }
    }
    public static func beginBatch(in parent: URL) throws -> URL {
        let directory = parent.appendingPathComponent("圧縮動画-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        return directory
    }
    public static func outputURL(for input: URL, index: Int, directory: URL) -> URL {
        directory.appendingPathComponent("\(index + 1)-" + input.deletingPathExtension().lastPathComponent + "-compressed.mp4")
    }
    public static func bytes(at url: URL) throws -> Int64 {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        guard let size = values.fileSize else { throw CocoaError(.fileReadUnknown) }
        return Int64(size)
    }
}
