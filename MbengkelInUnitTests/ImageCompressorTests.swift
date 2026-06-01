//
//  ImageCompressorTests.swift
//  MbengkelInUnitTests
//

import XCTest
import UIKit
@testable import MbengkelIn

final class ImageCompressorTests: XCTestCase {
    private func makeJPEG(width: CGFloat, height: CGFloat) -> Data {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { ctx in
            UIColor.systemBlue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return image.jpegData(compressionQuality: 1.0)!
    }

    func testLargeImageDownscaledToMaxDimension() throws {
        let data = makeJPEG(width: 3000, height: 2000)
        let out = ImageCompressor.compressed(data)
        let img = try XCTUnwrap(UIImage(data: out))
        let cg = try XCTUnwrap(img.cgImage)
        XCTAssertLessThanOrEqual(max(cg.width, cg.height), 1281, "longest side must be clamped to ~1280px")
        // 3:2 aspect ratio preserved
        XCTAssertEqual(Double(cg.width) / Double(cg.height), 1.5, accuracy: 0.02)
    }

    func testSmallImageNotUpscaled() throws {
        let data = makeJPEG(width: 200, height: 150)
        let out = ImageCompressor.compressed(data)
        let img = try XCTUnwrap(UIImage(data: out))
        let cg = try XCTUnwrap(img.cgImage)
        XCTAssertLessThanOrEqual(max(cg.width, cg.height), 201, "small image must not be upscaled past its size")
    }

    func testInvalidDataReturnsOriginalBytes() {
        let garbage = Data([0x00, 0x01, 0x02, 0x03, 0x04])
        let out = ImageCompressor.compressed(garbage)
        XCTAssertEqual(out, garbage, "undecodable data must fall back to the original bytes")
    }
}
