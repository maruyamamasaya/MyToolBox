import XCTest
@testable import MonitorKit

final class VideoCompressionTests: XCTestCase {
    func testBatchIsolationAndOutputNames() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let a = try VideoCompression.beginBatch(in: root)
        let b = try VideoCompression.beginBatch(in: root)
        XCTAssertNotEqual(a, b)
        let input = root.appendingPathComponent("映画.mov")
        let first = VideoCompression.outputURL(for: input, index: 0, directory: a)
        let second = VideoCompression.outputURL(for: input, index: 1, directory: a)
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(first.pathExtension, "mp4")
        XCTAssertEqual(first.deletingLastPathComponent(), a)
        XCTAssertNotEqual(first, input)
        XCTAssertThrowsError(try VideoCompression.bytes(at: input))
    }
}
