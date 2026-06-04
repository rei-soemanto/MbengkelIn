import Testing
import UIKit
@testable import MbengkelIn

@Suite("ImageCompressor")
struct ImageCompressorTests {
    private func makeJPEG(width: CGFloat, height: CGFloat) -> Data {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { ctx in
            UIColor.systemBlue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return image.jpegData(compressionQuality: 1.0)!
    }

    @Test func largeImageDownscaledToMaxDimension() throws {
        let data = makeJPEG(width: 3000, height: 2000)
        let out = ImageCompressor.compressed(data)
        let img = try #require(UIImage(data: out))
        let cg = try #require(img.cgImage)
        #expect(max(cg.width, cg.height) <= 1281)
        #expect(abs(Double(cg.width) / Double(cg.height) - 1.5) < 0.02)
    }

    @Test func smallImageNotUpscaled() throws {
        let data = makeJPEG(width: 200, height: 150)
        let out = ImageCompressor.compressed(data)
        let img = try #require(UIImage(data: out))
        let cg = try #require(img.cgImage)
        #expect(max(cg.width, cg.height) <= 201)
    }

    @Test func invalidDataReturnsOriginalBytes() {
        let garbage = Data([0x00, 0x01, 0x02, 0x03, 0x04])
        let out = ImageCompressor.compressed(garbage)
        #expect(out == garbage)
    }
}
