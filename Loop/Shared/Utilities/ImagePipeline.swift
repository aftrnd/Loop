import ImageIO
import UIKit
import os

// MARK: - Image Request

/// A remote image at the pixel size it will be drawn at.
nonisolated struct ImageRequest: Hashable, Sendable {
    let url: URL
    /// Target size in pixels. Zero means full resolution.
    let pixelWidth: Int
    let pixelHeight: Int

    /// - Parameters:
    ///   - pointSize: The frame the image fills, or nil to keep full resolution.
    ///   - scale: The display scale the frame is rendered at.
    init(url: URL, pointSize: CGSize?, scale: CGFloat) {
        self.url = url
        if let pointSize, pointSize.width > 0, pointSize.height > 0 {
            pixelWidth = Int((pointSize.width * scale).rounded(.up))
            pixelHeight = Int((pointSize.height * scale).rounded(.up))
        } else {
            pixelWidth = 0
            pixelHeight = 0
        }
    }

    fileprivate var cacheKey: NSString {
        "\(url.absoluteString)#\(pixelWidth)x\(pixelHeight)" as NSString
    }
}

// MARK: - Image Pipeline

/// Downloads remote images, downsamples them to the size they are drawn at, and keeps the
/// decoded bitmaps in a bounded memory cache. Network and decode work never runs on the main actor.
actor ImagePipeline {
    static let shared = ImagePipeline()

    /// Decoded images, readable synchronously so views can skip the placeholder on a cache hit.
    nonisolated let memoryCache = ImageMemoryCache()

    private let session: URLSession
    private var inFlight: [ImageRequest: Task<UIImage?, Never>] = [:]

    private init() {
        let configuration = URLSessionConfiguration.default
        // Protocol caching revalidates against the server, so a replaced avatar at the same URL still updates.
        configuration.urlCache = URLCache(memoryCapacity: 16 * 1024 * 1024, diskCapacity: 256 * 1024 * 1024)
        configuration.requestCachePolicy = .useProtocolCachePolicy
        session = URLSession(configuration: configuration)
    }

    /// Returns the image for `request`, joining an in-flight load for the same request if there is one.
    func image(for request: ImageRequest) async -> UIImage? {
        if let cached = memoryCache[request] {
            return cached
        }
        if let task = inFlight[request] {
            return await task.value
        }

        let session = session
        let task = Task.detached(priority: .userInitiated) {
            await Self.load(request, session: session)
        }
        inFlight[request] = task
        let image = await task.value
        inFlight[request] = nil

        if let image {
            memoryCache[request] = image
        }
        return image
    }

    // MARK: - Loading

    private nonisolated static let logger = Logger(subsystem: "com.nejack.Loop", category: "ImagePipeline")

    private nonisolated static func load(_ request: ImageRequest, session: URLSession) async -> UIImage? {
        do {
            let (data, _) = try await session.data(from: request.url)
            return decode(data, filling: request)
        } catch {
            logger.error("Image load failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Decodes `data` into a bitmap that is ready to draw. When the request has a target size, the image is
    /// downsampled to the smallest size that still fills that frame at full sharpness.
    private nonisolated static func decode(_ data: Data, filling request: ImageRequest) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat,
              width > 0, height > 0 else {
            return UIImage(data: data)?.preparingForDisplay()
        }

        // EXIF orientations 5 to 8 are rotated a quarter turn, so the drawn width is the stored height.
        let orientation = properties[kCGImagePropertyOrientation] as? UInt32 ?? 1
        let isQuarterTurned = (5...8).contains(orientation)
        let drawnWidth = isQuarterTurned ? height : width
        let drawnHeight = isQuarterTurned ? width : height

        var maxPixelSize = max(width, height)
        if request.pixelWidth > 0, request.pixelHeight > 0 {
            let fillScale = max(CGFloat(request.pixelWidth) / drawnWidth, CGFloat(request.pixelHeight) / drawnHeight)
            if fillScale < 1 {
                maxPixelSize = (maxPixelSize * fillScale).rounded(.up)
            }
        }

        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Memory Cache

/// Thin wrapper over `NSCache`, which is thread-safe and evicts on memory pressure.
nonisolated final class ImageMemoryCache: @unchecked Sendable {
    private let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 100 * 1024 * 1024
        return cache
    }()

    /// The latest image cached for each URL, whatever its size. Mostly the same objects as `cache`.
    private let latestByURL: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.totalCostLimit = 50 * 1024 * 1024
        return cache
    }()

    subscript(request: ImageRequest) -> UIImage? {
        get { cache.object(forKey: request.cacheKey) }
        set {
            guard let newValue else {
                cache.removeObject(forKey: request.cacheKey)
                return
            }
            cache.setObject(newValue, forKey: request.cacheKey, cost: newValue.decodedByteCount)
            latestByURL.setObject(newValue, forKey: request.url as NSURL, cost: newValue.decodedByteCount)
        }
    }

    /// Any cached size of the image at `url`, to stand in while another size loads.
    func anyImage(for url: URL) -> UIImage? {
        latestByURL.object(forKey: url as NSURL)
    }

    func removeAll() {
        cache.removeAllObjects()
        latestByURL.removeAllObjects()
    }
}

private extension UIImage {
    nonisolated var decodedByteCount: Int {
        guard let cgImage else { return 1 }
        return cgImage.bytesPerRow * cgImage.height
    }
}
