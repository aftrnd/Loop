import SwiftUI

/// Atomic component: Post content (text and/or media)
/// Handles text truncation, show more/less, and media display
struct PostContent: View {
    // MARK: - Properties
    let text: String
    let media: [LoopMedia]
    let maxPreviewLength: Int
    let showDebugOverlay: Bool
    
    @State private var showingFullText = false
    /// The photo showing, in the carousel and in the photo viewer alike
    @State private var currentMediaIndex: Int = 0
    @State private var isPhotoViewerPresented = false
    @Namespace private var photoTransition
    
    // MARK: - Initializer
    init(
        text: String,
        media: [LoopMedia] = [],
        maxPreviewLength: Int = 280,
        showDebugOverlay: Bool = false
    ) {
        self.text = text
        self.media = media
        self.maxPreviewLength = maxPreviewLength
        self.showDebugOverlay = showDebugOverlay
    }
    
    // MARK: - Body
    var body: some View {
        BaselineSpacedVStack(spacing: CardLayoutConstants.partSpacing) {
            // Text content - own container with debug outline
            if !text.isEmpty {
                textView
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .visibleTopAtCapHeight(of: .body)
                    .background(showDebugOverlay ? Color.green.opacity(0.1) : Color.clear)
                    .overlay(
                        Group {
                            if showDebugOverlay {
                                Rectangle()
                                    .stroke(Color.red, lineWidth: 1)
                            }
                        }
                    )
            }
            
            // Media content - own container with debug outline
            if hasMedia {
                mediaView
                    .photoViewer(isPresented: $isPhotoViewerPresented, media: media, currentIndex: $currentMediaIndex, namespace: photoTransition)
                    .background(showDebugOverlay ? Color.green.opacity(0.1) : Color.clear)
                    .overlay(
                        Group {
                            if showDebugOverlay {
                                Rectangle()
                                    .stroke(Color.red, lineWidth: 1)
                            }
                        }
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Computed Properties
    
    private var hasMedia: Bool {
        !media.isEmpty
    }
    
    // MARK: - Subviews
    
    private var textView: some View {
        VStack(alignment: .leading, spacing: 4) {
            let shouldTruncate = text.count > maxPreviewLength && !showingFullText
            let displayText = shouldTruncate ? String(text.prefix(maxPreviewLength)) + "..." : text
            
            Text(displayText)
                .font(.system(.body, design: .default))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            
            // Show more/less button
            if shouldTruncate {
                Button("Show more") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingFullText = true
                    }
                }
                .font(.caption)
                .foregroundColor(.accentColor)
            } else if text.count > maxPreviewLength && showingFullText {
                Button("Show less") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingFullText = false
                    }
                }
                .font(.caption)
                .foregroundColor(.accentColor)
            }
        }
    }
    
    @ViewBuilder
    private var mediaView: some View {
        if media.count == 1, let firstMedia = media.first {
            SingleMediaView(
                media: firstMedia,
                cornerRadius: CardLayoutConstants.mediaCornerRadius,
                transitionNamespace: photoTransition,
                onPhotoTap: {
                    openPhotoViewer(at: 0)
                },
                showDebugOverlay: showDebugOverlay
            )
        } else if media.count > 1 {
            MultipleMediaView(
                media: media,
                cornerRadius: CardLayoutConstants.mediaCornerRadius,
                currentIndex: $currentMediaIndex,
                transitionNamespace: photoTransition,
                onPhotoTap: { index in
                    openPhotoViewer(at: index)
                },
                showDebugOverlay: showDebugOverlay
            )
        }
    }
    
    private func openPhotoViewer(at index: Int) {
        currentMediaIndex = index
        isPhotoViewerPresented = true
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        VStack(spacing: 20) {
            // Text only
            PostContent(
                text: "Just launched our new app! Really excited to see how users respond. 🚀"
            )
            .padding()
            .background(Color(.systemBackground))
            
            // Long text
            PostContent(
                text: String(repeating: "This is a really long post with lots of text that should be truncated. ", count: 10)
            )
            .padding()
            .background(Color(.systemBackground))
            
            // Text + Image
            PostContent(
                text: "Check out this amazing photo!",
                media: [
                    LoopMedia(
                        type: .image,
                        url: "https://picsum.photos/400/400",
                        width: 400,
                        height: 400
                    )
                ]
            )
            .padding()
            .background(Color(.systemBackground))
            
            // Multiple images
            PostContent(
                text: "Photo carousel test",
                media: [
                    LoopMedia(type: .image, url: "https://picsum.photos/400/300", width: 400, height: 300),
                    LoopMedia(type: .image, url: "https://picsum.photos/300/400", width: 300, height: 400)
                ]
            )
            .padding()
            .background(Color(.systemBackground))
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}

