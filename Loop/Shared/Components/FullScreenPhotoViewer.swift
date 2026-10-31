import SwiftUI

// MARK: - Presentation

extension View {
    /// Marks a post photo as the place the full-screen viewer zooms out of and back into.
    /// - Parameter namespace: The namespace of the post presenting the viewer; nil leaves the photo unmarked.
    func photoViewerSource(index: Int, in namespace: Namespace.ID?, cornerRadius: CGFloat) -> some View {
        modifier(PhotoViewerSource(index: index, namespace: namespace, cornerRadius: cornerRadius))
    }

    /// Presents a post's photos full screen with the system zoom transition: the viewer grows out of the
    /// tapped photo, and closing it (a tap, or the system's swipe down) shrinks it back into the photo that
    /// is showing, with the app visible behind it. Presented from the post itself, so it also works in sheets.
    func photoViewer(
        isPresented: Binding<Bool>,
        media: [LoopMedia],
        currentIndex: Binding<Int>,
        namespace: Namespace.ID
    ) -> some View {
        fullScreenCover(isPresented: isPresented) {
            FullScreenPhotoViewer(media: media, currentIndex: currentIndex)
                .navigationTransition(.zoom(sourceID: currentIndex.wrappedValue, in: namespace))
        }
    }
}

private struct PhotoViewerSource: ViewModifier {
    let index: Int
    let namespace: Namespace.ID?
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if let namespace {
            content.matchedTransitionSource(id: index, in: namespace) { source in
                source.clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            }
        } else {
            content
        }
    }
}

// MARK: - Full Screen Photo Viewer

/// A post's photos, paged full screen. Pinch or double tap to zoom; a single tap closes it.
struct FullScreenPhotoViewer: View {
    let media: [LoopMedia]
    /// Shared with the post, so its carousel follows the viewer and the close zooms into the right photo
    @Binding var currentIndex: Int

    @Environment(\.dismiss) private var dismiss
    /// While the visible photo is zoomed in, drags pan it rather than closing the viewer
    @State private var isZoomed = false

    var body: some View {
        TabView(selection: $currentIndex) {
            ForEach(Array(media.enumerated()), id: \.offset) { index, item in
                if item.type == .image {
                    ZoomablePhoto(
                        media: item,
                        isCurrent: index == currentIndex,
                        isZoomed: $isZoomed,
                        onTap: { dismiss() }
                    )
                    .tag(index)
                }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .overlay(alignment: .bottom) {
            if media.count > 1 {
                // Matches the page dots on the post's carousel
                PageIndicator(currentPage: currentIndex, pageCount: media.count)
                    .padding(.bottom, 20)
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .interactiveDismissDisabled(isZoomed)
    }
}

// MARK: - Zoomable Photo

/// One page of the viewer. Opens on whatever size of the photo is already cached (the post's thumbnail),
/// so the zoom transition never shows an empty frame, and swaps in full resolution once it is decoded.
private struct ZoomablePhoto: View {
    let media: LoopMedia
    let isCurrent: Bool
    @Binding var isZoomed: Bool
    let onTap: () -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private static let zoomedScale: CGFloat = 2
    private static let zoomAnimation = Animation.smooth(duration: 0.4)

    var body: some View {
        let url = URL(string: media.url)

        CachedAsyncImage(url: url) { image in
            photo(image)
        } placeholder: {
            if let url, let preview = ImagePipeline.shared.memoryCache.anyImage(for: url) {
                photo(Image(uiImage: preview))
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scaleEffect(scale)
        .offset(offset)
        .contentShape(Rectangle())
        .gesture(magnification)
        // Only takes drags while zoomed in; otherwise they page or close the viewer
        .highPriorityGesture(pan, including: scale > 1 ? .all : .subviews)
        .onTapGesture(count: 2) {
            withAnimation(Self.zoomAnimation) {
                if scale > 1 {
                    resetZoom()
                } else {
                    scale = Self.zoomedScale
                    lastScale = Self.zoomedScale
                }
            }
        }
        .onTapGesture {
            if scale <= 1 {
                onTap()
            }
        }
        .onChange(of: scale > 1) { _, zoomed in
            if isCurrent {
                isZoomed = zoomed
            }
        }
        .onChange(of: isCurrent) { _, current in
            // A photo paged away from starts unzoomed when it comes back
            if !current {
                resetZoom()
            }
        }
    }

    private func photo(_ image: Image) -> some View {
        image
            .resizable()
            .aspectRatio(contentMode: .fit)
    }

    private var magnification: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = lastScale * value.magnification
            }
            .onEnded { _ in
                if scale < 1 {
                    withAnimation(Self.zoomAnimation) {
                        resetZoom()
                    }
                } else {
                    lastScale = scale
                }
            }
    }

    private var pan: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    private func resetZoom() {
        scale = 1
        lastScale = 1
        offset = .zero
        lastOffset = .zero
    }
}

#Preview {
    @Previewable @State var currentIndex = 0

    FullScreenPhotoViewer(
        media: [
            LoopMedia(type: .image, url: "https://picsum.photos/800/600", width: 800, height: 600),
            LoopMedia(type: .image, url: "https://picsum.photos/600/800", width: 600, height: 800)
        ],
        currentIndex: $currentIndex
    )
}
