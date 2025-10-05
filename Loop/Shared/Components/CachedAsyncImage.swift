import SwiftUI

/// A cached version of AsyncImage that stores loaded images in memory
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    @State private var cachedImage: UIImage?
    private let url: URL?
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder
    
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let cachedImage = cachedImage {
                content(Image(uiImage: cachedImage))
            } else if let url = url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        content(image)
                            .onAppear {
                                // Cache the image once loaded
                                if let uiImage = loadUIImage(from: url) {
                                    cachedImage = uiImage
                                }
                            }
                    case .failure(_):
                        placeholder()
                    case .empty:
                        placeholder()
                    @unknown default:
                        placeholder()
                    }
                }
            } else {
                placeholder()
            }
        }
        .task {
            // Try to load from cache first
            if let url = url, let cached = ImageCache.shared.get(url: url) {
                cachedImage = cached
            }
        }
    }
    
    private func loadUIImage(from url: URL) -> UIImage? {
        // Try to get from cache first
        if let cached = ImageCache.shared.get(url: url) {
            return cached
        }
        
        // Load from URL and cache it
        if let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            ImageCache.shared.set(image: image, for: url)
            return image
        }
        
        return nil
    }
}

/// Simple in-memory image cache
class ImageCache {
    static let shared = ImageCache()
    
    private var cache: [String: UIImage] = [:]
    private let queue = DispatchQueue(label: "com.loop.imagecache", attributes: .concurrent)
    
    private init() {}
    
    func get(url: URL) -> UIImage? {
        queue.sync {
            return cache[url.absoluteString]
        }
    }
    
    func set(image: UIImage, for url: URL) {
        queue.async(flags: .barrier) {
            self.cache[url.absoluteString] = image
        }
    }
    
    func clear() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }
}

