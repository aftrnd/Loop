import SwiftUI

/// A cached version of AsyncImage that stores loaded images in memory
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    @State private var cachedImage: UIImage?
    @State private var isLoading = false
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
            } else {
                placeholder()
            }
        }
        .task {
            guard let url = url, cachedImage == nil, !isLoading else { return }
            
            // Try to load from cache first
            if let cached = ImageCache.shared.get(url: url) {
                cachedImage = cached
                return
            }
            
            // Load asynchronously from URL
            isLoading = true
            await loadUIImage(from: url)
            isLoading = false
        }
    }
    
    private func loadUIImage(from url: URL) async {
        // Try to get from cache first
        if let cached = ImageCache.shared.get(url: url) {
            cachedImage = cached
            return
        }
        
        // Load from URL asynchronously using URLSession
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            // Decode image on background thread
            let image = await Task.detached(priority: .userInitiated) {
                UIImage(data: data)
            }.value
            
            if let image = image {
                // Cache and update UI on main thread
                ImageCache.shared.set(image: image, for: url)
                await MainActor.run {
                    cachedImage = image
                }
            }
        } catch {
            // Silent failure - just show placeholder
            print("Failed to load image from \(url): \(error.localizedDescription)")
        }
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

