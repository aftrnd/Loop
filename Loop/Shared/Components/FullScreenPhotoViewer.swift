import SwiftUI

struct FullScreenPhotoViewer: View {
    let allMedia: [LoopMedia]
    let startingIndex: Int
    @Binding var isPresented: Bool
    
    @State private var currentIndex: Int
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    
    init(allMedia: [LoopMedia], startingIndex: Int, isPresented: Binding<Bool>) {
        self.allMedia = allMedia
        self.startingIndex = startingIndex
        self._isPresented = isPresented
        self._currentIndex = State(initialValue: startingIndex)
    }
    
    var body: some View {
        // Photo Gallery only - no background, just photos
        TabView(selection: $currentIndex) {
            ForEach(Array(allMedia.enumerated()), id: \.element.id) { index, media in
                if media.type == .image {
                    photoView(for: media)
                        .tag(index)
                }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: allMedia.count > 1 ? .automatic : .never))
        .ignoresSafeArea()
        .background(
            // Blur the actual content behind (the home feed)
            TranslucentBlurBackground(isDragging: isDragging, dragOffset: dragOffset.height)
        )
    }
    
    private func photoView(for media: LoopMedia) -> some View {
        GeometryReader { geometry in
            CachedAsyncImage(url: URL(string: media.url)) { image in
                let dragProgress = min(abs(dragOffset.height) / 300, 1.0)
                let dismissScale = 1.0 - (dragProgress * 0.3) // Scale down to 0.7 when fully dragged
                
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .scaleEffect(scale * dismissScale)
                    .offset(dragOffset)
                    .gesture(
                        // Pinch to zoom
                        MagnificationGesture()
                            .onChanged { value in
                                scale = lastScale * value
                            }
                            .onEnded { _ in
                                lastScale = scale
                                // Reset if zoomed out too much
                                if scale < 1.0 {
                                    withAnimation(.spring(response: 0.3)) {
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
                                            // Continue animation in dismiss direction
                                            let targetOffset: CGFloat = value.translation.height > 0 ? 1000 : -1000
                                            
                                            withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
                                                dragOffset = CGSize(width: 0, height: targetOffset)
                                            }
                                            
                                            // Dismiss after animation completes
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                                isPresented = false
                                            }
                                            
                                            // Keep isDragging true during dismiss animation
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                                isDragging = false
                                            }
                                        } else {
                                            // Bounce back with spring
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                                dragOffset = .zero
                                            }
                                            
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                                isDragging = false
                                            }
                                        }
                                    } else {
                                        // Reset on horizontal swipe
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                            dragOffset = .zero
                                        }
                                        
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                            isDragging = false
                                        }
                                    }
                                } else {
                                    // Reset when zoomed
                                    withAnimation(.spring(response: 0.3)) {
                                        dragOffset = .zero
                                    }
                                    
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                        isDragging = false
                                    }
                                }
                            }
                    )
                    .onTapGesture(count: 2) {
                        // Double tap to zoom
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
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
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }
        }
    }
}

// Blur background that shows the actual content behind
struct TranslucentBlurBackground: View {
    let isDragging: Bool
    let dragOffset: CGFloat
    
    var body: some View {
        let dragProgress = min(abs(dragOffset) / 300, 1.0)
        let backgroundOpacity = isDragging ? max(0.3, 0.7 - dragProgress * 0.5) : 0.7
        
        ZStack {
            // This will blur the actual content behind (home feed)
            Rectangle()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
            
            // Add darkening overlay
            Color.black
                .opacity(backgroundOpacity)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    FullScreenPhotoViewer(
        allMedia: [
            LoopMedia(type: .image, url: "https://picsum.photos/800/600", width: 800, height: 600),
            LoopMedia(type: .image, url: "https://picsum.photos/600/800", width: 600, height: 800)
        ],
        startingIndex: 0,
        isPresented: .constant(true)
    )
}

