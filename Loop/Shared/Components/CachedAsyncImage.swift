import SwiftUI

/// Remote image backed by `ImagePipeline`: downsampled to `targetSize`, decoded off the main actor,
/// and shown without a placeholder flash when the image is already in memory. With `fadeIn`, an image that has to load
/// fades in over the placeholder instead of replacing it in one frame.
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    private let url: URL?
    private let targetSize: CGSize?
    private let trimsEdges: Bool
    private let fadeIn: Animation?
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder

    @Environment(\.displayScale) private var displayScale
    @State private var loaded: (request: ImageRequest, image: UIImage)?

    /// - Parameters:
    ///   - targetSize: The frame the image fills, in points. Pass nil to keep full resolution.
    ///   - trimsEdges: Drops the image's outermost pixel on every side, where some publishers' images carry a
    ///     light or dark line.
    ///   - fadeIn: How an image that has to load fades in over the placeholder, which stays underneath. Nil shows it
    ///     in one frame. An image already in memory always shows at once.
    init(
        url: URL?,
        targetSize: CGSize? = nil,
        trimsEdges: Bool = false,
        fadeIn: Animation? = nil,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.targetSize = targetSize
        self.trimsEdges = trimsEdges
        self.fadeIn = fadeIn
        self.content = content
        self.placeholder = placeholder
    }

    private var request: ImageRequest? {
        guard let url else { return nil }
        // A zero-sized frame hasn't been laid out yet; wait for the real size rather than loading full resolution.
        if let targetSize, targetSize.width <= 0 || targetSize.height <= 0 { return nil }
        return ImageRequest(url: url, pointSize: targetSize, scale: displayScale, trimsEdges: trimsEdges)
    }

    var body: some View {
        let request = request
        Group {
            if fadeIn != nil {
                ZStack {
                    placeholder()
                    if let image = image(for: request) {
                        content(Image(uiImage: image))
                            .transition(.opacity)
                    }
                }
            } else if let image = image(for: request) {
                content(Image(uiImage: image))
            } else {
                placeholder()
            }
        }
        .task(id: request) {
            // Hold the image in state even on a cache hit, so a later eviction can't drop it back to the placeholder.
            guard let request, loaded?.request != request else { return }
            let wasShowing = image(for: request) != nil
            guard let image = await ImagePipeline.shared.image(for: request), !Task.isCancelled else { return }
            withAnimation(wasShowing ? nil : fadeIn) {
                loaded = (request, image)
            }
        }
    }

    private func image(for request: ImageRequest?) -> UIImage? {
        guard let request else { return nil }
        if let loaded, loaded.request == request {
            return loaded.image
        }
        return ImagePipeline.shared.memoryCache[request]
    }
}
