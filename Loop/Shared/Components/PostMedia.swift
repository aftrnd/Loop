import SwiftUI

// MARK: - Post Media
// Photo views shared by PostContent and ReplyCardView: a single photo, a swipeable carousel and its page dots.

struct SingleMediaView: View {
    let media: LoopMedia
    let cornerRadius: CGFloat
    /// The namespace the photo viewer zooms out of and back into, if the photo opens one
    var transitionNamespace: Namespace.ID? = nil
    let onPhotoTap: () -> Void
    var showDebugOverlay: Bool = false
    
    var body: some View {
        switch media.type {
        case .image:
            let displayMode = determineDisplayMode(media: media)
            
            GeometryReader { geometry in
                CachedAsyncImage(
                    url: URL(string: media.url),
                    targetSize: CGSize(width: geometry.size.width, height: displayMode.height)
                ) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: displayMode.height)
                        .clipped()
                } placeholder: {
                    ZStack {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(Color.secondary.opacity(0.2))
                        ProgressView()
                            .scaleEffect(1.0)
                    }
                    .frame(width: geometry.size.width, height: displayMode.height)
                }
                .frame(width: geometry.size.width, height: displayMode.height)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .photoViewerSource(index: 0, in: transitionNamespace, cornerRadius: cornerRadius)
                .overlay(
                    Group {
                        if showDebugOverlay {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(Color.red, lineWidth: 1)
                        }
                    }
                )
            }
            .frame(height: displayMode.height)
            .onTapGesture {
                onPhotoTap()
            }
            
        case .video:
            // Placeholder for video - would implement video player here
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 200)
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                        Text("Video")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                )
            
        case .text:
            EmptyView()
        }
    }
    
    private func determineDisplayMode(media: LoopMedia) -> ImageDisplayMode {
        guard let width = media.width, let height = media.height, height > 0 else {
            // Default to square if no dimensions - use .fill to crop
            return ImageDisplayMode(height: 300, contentMode: .fill)
        }
        
        let aspectRatio = width / height
        
        // Calculate height based on aspect ratio to show proper proportions
        // Use a base width of ~350 (approximate card width minus padding) to calculate proportional height
        let baseWidth: CGFloat = 350
        let proportionalHeight = baseWidth / aspectRatio
        
        // Clamp height to reasonable bounds for UI
        let minHeight: CGFloat = 150
        let maxHeight: CGFloat = 500
        
        // Photo height determines post height, always crop sides to fit width
        // Apply same logic for all aspect ratios - no special casing
        let clampedHeight = max(minHeight, min(maxHeight, proportionalHeight))
        return ImageDisplayMode(height: clampedHeight, contentMode: .fill)
    }
}

struct ImageDisplayMode {
    let height: CGFloat
    let contentMode: ContentMode
}

struct MultipleMediaView: View {
    let media: [LoopMedia]
    let cornerRadius: CGFloat
    @Binding var currentIndex: Int
    /// The namespace the photo viewer zooms out of and back into, if the photos open one
    var transitionNamespace: Namespace.ID? = nil
    let onPhotoTap: (Int) -> Void
    var showDebugOverlay: Bool = false
    
    // Local state for scroll position (needs to be optional for ScrollView API)
    @State private var scrollPosition: Int?
    
    // Use the same height calculation as single photos
    var carouselHeight: CGFloat {
        guard let firstMedia = media.first else { return 300 }
        return determineDisplayMode(media: firstMedia).height
    }
    
    private func determineDisplayMode(media: LoopMedia) -> ImageDisplayMode {
        guard let width = media.width, let height = media.height, height > 0 else {
            // Default to square if no dimensions - use .fill to crop
            return ImageDisplayMode(height: 300, contentMode: .fill)
        }
        
        let aspectRatio = width / height
        
        // Calculate height based on aspect ratio to show proper proportions
        // Use a base width of ~350 (approximate card width minus padding) to calculate proportional height
        let baseWidth: CGFloat = 350
        let proportionalHeight = baseWidth / aspectRatio
        
        // Clamp height to reasonable bounds for UI
        let minHeight: CGFloat = 150
        let maxHeight: CGFloat = 500
        
        // Photo height determines post height, always crop sides to fit width
        // Apply same logic for all aspect ratios - no special casing
        let clampedHeight = max(minHeight, min(maxHeight, proportionalHeight))
        return ImageDisplayMode(height: clampedHeight, contentMode: .fill)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let containerWidth = geometry.size.width
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: CardLayoutConstants.photoCarouselSpacing) {
                    ForEach(Array(media.enumerated()), id: \.offset) { index, mediaItem in
                        CarouselPhotoView(
                            media: mediaItem,
                            cornerRadius: cornerRadius,
                            height: carouselHeight,
                            onPhotoTap: { onPhotoTap(index) },
                            showDebugOverlay: showDebugOverlay
                        )
                        .photoViewerSource(index: index, in: transitionNamespace, cornerRadius: cornerRadius)
                        .frame(width: containerWidth, height: carouselHeight)
                        .containerRelativeFrame(.horizontal)
                        .id(index)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrollPosition)
            .onChange(of: scrollPosition) { _, newValue in
                if let newValue = newValue {
                    currentIndex = newValue
                }
            }
            // Follows the photo viewer as it pages, so closing it zooms back into a visible photo
            .onChange(of: currentIndex) { _, newValue in
                if scrollPosition != newValue {
                    scrollPosition = newValue
                }
            }
        }
        .frame(height: carouselHeight)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            Group {
                if showDebugOverlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.red, lineWidth: 1)
                }
            }
        )
        .overlay(alignment: .bottom) {
            // Page indicators inside photo container
            PageIndicator(currentPage: currentIndex, pageCount: media.count)
                .padding(.bottom, 8)
        }
    }
}

struct CarouselPhotoView: View {
    let media: LoopMedia
    let cornerRadius: CGFloat
    let height: CGFloat
    let onPhotoTap: () -> Void
    var showDebugOverlay: Bool = false
    
    var body: some View {
        switch media.type {
        case .image:
            GeometryReader { geometry in
                CachedAsyncImage(
                    url: URL(string: media.url),
                    targetSize: CGSize(width: geometry.size.width, height: height)
                ) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: height)
                } placeholder: {
                    ZStack {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(Color.secondary.opacity(0.2))
                        ProgressView()
                            .scaleEffect(1.0)
                    }
                    .frame(width: geometry.size.width, height: height)
                }
            }
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                Group {
                    if showDebugOverlay {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.red, lineWidth: 1)
                    }
                }
            )
            .onTapGesture {
                onPhotoTap()
            }
            
        case .video:
            // Placeholder for video - would implement video player here
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 200)
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                        Text("Video")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                )
            
        case .text:
            EmptyView()
        }
    }
}

// Compact page indicator component
struct PageIndicator: View {
    let currentPage: Int
    let pageCount: Int
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<pageCount, id: \.self) { index in
                Circle()
                    .fill(currentPage == index ? Color.white : Color.white.opacity(0.5))
                    .frame(width: 4, height: 4)
            }
        }
    }
}
