import ImageIO
import UIKit

// MARK: - Upload Types

/// An image picked for upload: the original file bytes when the picker provides them, otherwise a decoded image.
nonisolated enum UploadImageSource: Sendable {
    case data(Data)
    case image(UIImage)
}

/// The largest size and the JPEG quality for each kind of uploaded image.
nonisolated struct UploadImageSpec: Sendable {
    let maxSize: CGSize
    let compressionQuality: CGFloat

    static let post = UploadImageSpec(maxSize: CGSize(width: 2048, height: 2048), compressionQuality: 0.8)
    static let avatar = UploadImageSpec(maxSize: CGSize(width: 512, height: 512), compressionQuality: 0.8)
    static let banner = UploadImageSpec(maxSize: CGSize(width: 1920, height: 1080), compressionQuality: 0.85)
}

/// A JPEG ready to upload and the pixel size it was encoded at, with orientation already applied.
nonisolated struct EncodedUploadImage: Sendable {
    let data: Data
    let pixelWidth: Int
    let pixelHeight: Int
}

// MARK: - Encoder

/// Scales images down to their upload size and encodes them as JPEG. The work never runs on the main actor.
nonisolated enum ImageUploadEncoder {
    enum EncodingError: LocalizedError {
        case unreadableImage
        case encodingFailed

        var errorDescription: String? {
            switch self {
            case .unreadableImage:
                return "The photo couldn't be read."
            case .encodingFailed:
                return "The photo couldn't be prepared for upload."
            }
        }
    }

    /// Fits `source` inside `spec.maxSize`, keeping its aspect ratio and never scaling up, and encodes it as JPEG.
    @concurrent
    static func encode(_ source: UploadImageSource, as spec: UploadImageSpec) async throws -> EncodedUploadImage {
        let image: UIImage
        switch source {
        case .data(let data):
            guard let downsampled = downsample(data, toFit: spec.maxSize) else {
                throw EncodingError.unreadableImage
            }
            image = UIImage(cgImage: downsampled)
        case .image(let original):
            image = redraw(original, toFit: spec.maxSize)
        }

        guard let data = image.jpegData(compressionQuality: spec.compressionQuality) else {
            throw EncodingError.encodingFailed
        }
        return EncodedUploadImage(
            data: data,
            pixelWidth: Int((image.size.width * image.scale).rounded()),
            pixelHeight: Int((image.size.height * image.scale).rounded())
        )
    }

    /// Decodes `data` straight to the target size with ImageIO, so a large photo is never decoded at full resolution.
    private static func downsample(_ data: Data, toFit maxSize: CGSize) -> CGImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat,
              width > 0, height > 0 else {
            return nil
        }

        // EXIF orientations 5 to 8 are rotated a quarter turn, so the drawn width is the stored height.
        let orientation = properties[kCGImagePropertyOrientation] as? UInt32 ?? 1
        let isQuarterTurned = (5...8).contains(orientation)
        let drawnWidth = isQuarterTurned ? height : width
        let drawnHeight = isQuarterTurned ? width : height
        let scale = min(1, maxSize.width / drawnWidth, maxSize.height / drawnHeight)

        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: (max(width, height) * scale).rounded()
        ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions)
    }

    /// Redraws an already decoded image at the target size, applying its orientation. Returns it unchanged if it fits.
    private static func redraw(_ image: UIImage, toFit maxSize: CGSize) -> UIImage {
        let scale = min(maxSize.width / image.size.width, maxSize.height / image.size.height)
        guard scale < 1 else { return image }

        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false

        return UIGraphicsImageRenderer(size: newSize, format: format).image { context in
            context.cgContext.interpolationQuality = .high
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
