//
//  ImageCompressor.swift
//  MbengkelIn
//

import UIKit

// Downscales + JPEG-compresses image data before upload so we never push
// multi-megabyte camera originals to Storage. Falls back to the original bytes
// if the data can't be decoded or re-encoded.
enum ImageCompressor {
    static func compressed(_ data: Data, maxDimension: CGFloat = 1280, quality: CGFloat = 0.7) -> Data {
        guard let image = UIImage(data: data) else { return data }

        let longest = max(image.size.width, image.size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality) ?? data
    }
}
