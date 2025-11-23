import SwiftUI

// MARK: - Photo Background Overlay
/// Separate component that handles the background fade animation
/// Goes from transparent to black as photo opens, and back to transparent on close
struct PhotoViewerBackgroundOverlay: View {
    @Binding var opacity: Double
    
    var body: some View {
        Color.black
            .opacity(opacity)
            .ignoresSafeArea()
            .allowsHitTesting(false) // Don't intercept gestures
    }
}

// MARK: - Full Screen Photo Viewer
/// Clean photo viewer component that only handles the photo display and interactions
/// Background is handled separately by PhotoViewerBackgroundOverlay
struct FullScreenPhotoViewer: View {
    let allMedia: [LoopMedia]
    let startingIndex: Int
    @Binding var isPresented: Bool
    @Binding var backgroundOpacity: Double
    
    @State private var currentIndex: Int
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var contentOpacity: Double = 0.0 // Start invisible
    @State private var contentScale: CGFloat = 0.85 // Start slightly smaller
    @State private var cornerRadius: CGFloat = 0 // Rounds as we dismiss
    
    init(allMedia: [LoopMedia], startingIndex: Int, isPresented: Binding<Bool>, backgroundOpacity: Binding<Double>) {
        self.allMedia = allMedia
        self.startingIndex = startingIndex
        self._isPresented = isPresented
        self._backgroundOpacity = backgroundOpacity
        self._currentIndex = State(initialValue: startingIndex)
    }
    
    var body: some View {
        ZStack {
            TabView(selection: $currentIndex) {
                ForEach(Array(allMedia.enumerated()), id: \.element.id) { index, media in
                    if media.type == .image {
                        photoView(for: media, index: index)
                            .tag(index)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never)) // Hide default indicators
            .onTapGesture {
                // Single tap to dismiss (only works when not zoomed)
                if scale <= 1.0 && !isDragging {
                    dismissViewer()
                }
            }
            
            // Custom page indicator - matches home tab size exactly
            if allMedia.count > 1 {
                VStack {
                    Spacer()
                    HStack(spacing: 4) {
                        ForEach(0..<allMedia.count, id: \.self) { index in
                            Circle()
                                .fill(currentIndex == index ? Color.white : Color.white.opacity(0.5))
                                .frame(width: 4, height: 4)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .scaleEffect(contentScale)
        .opacity(contentOpacity)
        .ignoresSafeArea()
        .onAppear {
            // Buttery smooth entrance animation
            withAnimation(.smooth(duration: 0.45, extraBounce: 0)) {
                contentOpacity = 1.0
                contentScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.4)) {
                backgroundOpacity = 1.0
            }
        }
    }
    
    private func dismissViewer() {
        withAnimation(.smooth(duration: 0.4, extraBounce: 0)) {
            contentOpacity = 0
            contentScale = 0.85
            cornerRadius = 30 // Max 30pts as requested
        }
        withAnimation(.easeIn(duration: 0.35)) {
            backgroundOpacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isPresented = false
        }
    }
    
    private func photoView(for media: LoopMedia, index: Int) -> some View {
        GeometryReader { geometry in
            CachedAsyncImage(url: URL(string: media.url)) { image in
                let dragProgress = min(abs(dragOffset.height) / 300, 1.0)
                let dragDismissScale = 1.0 - (dragProgress * 0.15) // Subtle scale down
                
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)) // Round the photo itself
                    .scaleEffect(scale * dragDismissScale)
                    .offset(dragOffset)
                    .gesture(
                        // Pinch to zoom
                        MagnificationGesture()
                            .onChanged { value in
                                scale = lastScale * value
                            }
                            .onEnded { _ in
                                lastScale = scale
                                // Reset if zoomed out too much - buttery smooth
                                if scale < 1.0 {
                                    withAnimation(.smooth(duration: 0.4, extraBounce: 0)) {
                                        scale = 1.0
                                        lastScale = 1.0
                                    }
                                }
                            }
                    )
                    .highPriorityGesture(
                        // Vertical drag to dismiss (only when not zoomed)
                        DragGesture(minimumDistance: 30)
                            .onChanged { value in
                                // Only respond to primarily vertical drags when not zoomed
                                if scale <= 1.0 {
                                    let horizontalAmount = abs(value.translation.width)
                                    let verticalAmount = abs(value.translation.height)
                                    
                                    // Only activate if clearly vertical (2:1 ratio)
                                    if verticalAmount > horizontalAmount * 1.5 {
                                        isDragging = true
                                        // Apply drag offset immediately for smooth following
                                        dragOffset = CGSize(
                                            width: 0,
                                            height: value.translation.height
                                        )
                                        
                                        // Interactive spring for buttery smooth updates
                                        withAnimation(.interactiveSpring(duration: 0.15)) {
                                            // Fade background based on drag progress
                                            let newOpacity = max(0, 1.0 - dragProgress * 0.9)
                                            backgroundOpacity = newOpacity
                                            
                                            // Round corners progressively - max 30pt radius
                                            cornerRadius = min(dragProgress * 50, 30)
                                        }
                                    }
                                } else {
                                    // Allow free drag when zoomed
                                    dragOffset = value.translation
                                }
                            }
                            .onEnded { value in
                                if scale <= 1.0 {
                                    let horizontalAmount = abs(value.translation.width)
                                    let verticalAmount = abs(value.translation.height)
                                    
                                    // Dismiss if primarily vertical drag
                                    if verticalAmount > horizontalAmount {
                                        let threshold: CGFloat = 100
                                        let velocity = value.predictedEndTranslation.height - value.translation.height
                                        
                                        // Dismiss if dragged far enough OR with high velocity
                                        if verticalAmount > threshold || abs(velocity) > 400 {
                                            dismissViewer()
                                        } else {
                                            // Buttery smooth bounce back
                                            withAnimation(.smooth(duration: 0.5, extraBounce: 0.1)) {
                                                dragOffset = .zero
                                                backgroundOpacity = 1.0
                                                cornerRadius = 0
                                            }
                                            
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                                isDragging = false
                                            }
                                        }
                                    } else {
                                        // Reset on horizontal swipe
                                        withAnimation(.smooth(duration: 0.5, extraBounce: 0.1)) {
                                            dragOffset = .zero
                                            backgroundOpacity = 1.0
                                            cornerRadius = 0
                                        }
                                        
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            isDragging = false
                                        }
                                    }
                                } else {
                                    // Reset when zoomed
                                    withAnimation(.smooth(duration: 0.4)) {
                                        dragOffset = .zero
                                    }
                                    
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                        isDragging = false
                                    }
                                }
                            }
                    )
                    .onTapGesture(count: 2) {
                        // Double tap to zoom - buttery smooth
                        withAnimation(.smooth(duration: 0.4, extraBounce: 0)) {
                            if scale > 1.0 {
                                // Zoom out
                                scale = 1.0
                                lastScale = 1.0
                                dragOffset = .zero
                            } else {
                                // Zoom in to 2x
                                scale = 2.0
                                lastScale = 2.0
                            }
                        }
                    }
            } placeholder: {
                ZStack {
                    Color.clear
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }
}

#Preview {
    @Previewable @State var isPresented = true
    @Previewable @State var backgroundOpacity: Double = 1.0
    
    ZStack {
        // Background overlay
        PhotoViewerBackgroundOverlay(opacity: $backgroundOpacity)
        
        // Photo viewer
        if isPresented {
            FullScreenPhotoViewer(
                allMedia: [
                    LoopMedia(type: .image, url: "https://picsum.photos/800/600", width: 800, height: 600),
                    LoopMedia(type: .image, url: "https://picsum.photos/600/800", width: 600, height: 800)
                ],
                startingIndex: 0,
                isPresented: $isPresented,
                backgroundOpacity: $backgroundOpacity
            )
        }
    }
}

