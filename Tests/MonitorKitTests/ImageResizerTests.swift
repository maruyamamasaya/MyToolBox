import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import MonitorKit

final class ImageResizerTests: XCTestCase {
    private func fixture(type: UTType = .png, orientation: Int? = nil) throws -> Data {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(data: nil, width: 8, height: 4, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        let image = try XCTUnwrap(context.makeImage())
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil))
        let properties: [CFString: Any] = orientation.map { [kCGImagePropertyOrientation: $0] } ?? [:]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }
    private func rgba(_ data: Data, x: Int, y: Int) throws -> [UInt8] {
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let context = try XCTUnwrap(CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let bytes = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        let offset = (y * image.width + x) * 4
        return Array(UnsafeBufferPointer(start: bytes + offset, count: 4))
    }
    func testPNGDimensionsTransparencyAndDistortion() throws {
        let input = try ImageResizer.inspect(fixture())
        XCTAssertEqual(input.width, 8); XCTAssertEqual(input.height, 4)
        let resized = try ImageResizer.resize(input, to: .init(width: 16, height: 12), format: .png, quality: 0.85)
        let info = try ImageResizer.inspect(resized)
        XCTAssertEqual(info.width, 16); XCTAssertEqual(info.height, 12)
        XCTAssertEqual(try rgba(resized, x: 15, y: 6)[3], 0)
        let red = try rgba(resized, x: 1, y: 6)
        XCTAssertGreaterThan(red[0], 240); XCTAssertEqual(red[3], 255)
    }
    func testJPEGWhiteBackgroundAndOutputType() throws {
        let input = try ImageResizer.inspect(fixture())
        let data = try ImageResizer.resize(input, to: .init(width: 8, height: 4), format: .jpeg, quality: 1)
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        XCTAssertEqual(CGImageSourceGetType(source) as String?, UTType.jpeg.identifier)
        let white = try rgba(data, x: 7, y: 2)
        XCTAssertTrue(white.prefix(3).allSatisfy { $0 > 240 })
    }
    func testEXIFRotationIsBakedIntoPixels() throws {
        let input = try ImageResizer.inspect(fixture(type: .jpeg, orientation: 6))
        XCTAssertEqual(input.width, 4); XCTAssertEqual(input.height, 8)
        let data = try ImageResizer.resize(input, to: .init(width: 2, height: 4), format: .png, quality: 0.85)
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        XCTAssertEqual(properties[kCGImagePropertyPixelWidth] as? Int, 2)
        XCTAssertEqual(properties[kCGImagePropertyPixelHeight] as? Int, 4)
        XCTAssertTrue(properties[kCGImagePropertyOrientation] == nil || properties[kCGImagePropertyOrientation] as? Int == 1)
        XCTAssertNil(properties[kCGImagePropertyGPSDictionary])
    }
    func testLimitsAndScaleRounding() throws {
        XCTAssertEqual(try ImageResizer.scaled(width: 3, height: 5, scale: 0.5), .init(width: 2, height: 3))
        XCTAssertEqual(try ImageResizer.scaled(width: 1, height: 1, scale: 0.25), .init(width: 1, height: 1))
        for size in [ImageResizer.Size(width: 0, height: 1), .init(width: -1, height: 2), .init(width: 16385, height: 1), .init(width: 10000, height: 10000), .init(width: Int.max, height: Int.max)] { XCTAssertThrowsError(try ImageResizer.validate(size)) }
        for scale in [Double.nan, .infinity, -1, 0, 10000] { XCTAssertThrowsError(try ImageResizer.scaled(width: 10, height: 10, scale: scale)) }
        XCTAssertThrowsError(try ImageResizer.inspect(Data("not an image".utf8)))
        XCTAssertThrowsError(try ImageResizer.inspect(Data(count: ImageResizer.maxBytes + 1)))
        let input = try ImageResizer.inspect(fixture())
        XCTAssertThrowsError(try ImageResizer.resize(input, to: .init(width: 1, height: 1), format: .jpeg, quality: .nan))
    }
    func testFileSaveRoundTripAndOriginalProtection() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let original = folder.appendingPathComponent("original.png"), result = folder.appendingPathComponent("result.jpg")
        let bytes = try fixture(); try bytes.write(to: original)
        let input = try ImageResizer.read(original)
        let data = try ImageResizer.resize(input, to: .init(width: 4, height: 2), format: .jpeg, quality: 0.8)
        try ImageResizer.save(data, to: result, protecting: original)
        XCTAssertEqual(try ImageResizer.read(result).width, 4)
        XCTAssertEqual(try Data(contentsOf: original), bytes)
        XCTAssertThrowsError(try ImageResizer.save(data, to: original, protecting: original))
        let symlink = folder.appendingPathComponent("link.png")
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: original)
        XCTAssertThrowsError(try ImageResizer.save(data, to: symlink, protecting: original))
        let hardlink = folder.appendingPathComponent("hard.png")
        try FileManager.default.linkItem(at: original, to: hardlink)
        XCTAssertThrowsError(try ImageResizer.save(data, to: hardlink, protecting: original))
        XCTAssertEqual(try Data(contentsOf: original), bytes)
    }
    func testMultiPageImageRejected() throws {
        let source = try XCTUnwrap(CGImageSourceCreateWithData(try fixture() as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.tiff.identifier as CFString, 2, nil))
        CGImageDestinationAddImage(destination, image, nil); CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        XCTAssertThrowsError(try ImageResizer.inspect(data as Data))
    }
}
