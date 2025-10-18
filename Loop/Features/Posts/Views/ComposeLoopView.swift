import SwiftUI
import PhotosUI
import UIKit
import FirebaseAuth

struct ComposeLoopView: View {
    @Binding var draft: LoopDraft
    @Binding var isPresented: Bool
    let onPost: () async -> Void
    
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var isUploadingMedia = false
    @State private var showingImageSourceActionSheet = false
    @State private var showingCamera = false
    @State private var showingPhotoLibraryPicker = false
    @FocusState private var isTextFieldFocused: Bool
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // Current user state
    @State private var currentUser: User?
    
    // Dynamic height tracking
    @State private var textHeight: CGFloat = 0
    @State private var isSheetExpanded = false
    
    // Debug overlay
    @AppStorage("showLayoutDebugOverlays") private var showDebugOverlay = false
    
    private var characterCountColor: Color {
        let remaining = draft.remainingCharacters
        if remaining < 0 {
            return .red
        } else if remaining < 20 {
            return .orange
        } else {
            return .secondary
        }
    }
    
    private var canPost: Bool {
        draft.isValid && draft.isWithinCharacterLimit && !isUploadingMedia
    }
    
    // Calculate dynamic minimum height based on content
    private var dynamicMinHeight: CGFloat {
        let baseHeight: CGFloat = 280 // Base minimum height
        let additionalHeight = max(0, textHeight - 72) // 72 is roughly 3 lines
        return min(baseHeight + additionalHeight, 500) // Cap at reasonable max
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { outerGeometry in
                mainContent(geometry: outerGeometry)
                    .onAppear {
                        // Detect if sheet is expanded based on available height
                        isSheetExpanded = outerGeometry.size.height > 400
                    }
                    .onChange(of: outerGeometry.size.height) { _, newHeight in
                        isSheetExpanded = newHeight > 400
                    }
            }
            .containerShape(.rect(cornerRadius: 16, style: .continuous))
            .navigationTitle(draft.isReply ? "Reply" : "New Loop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Post") {
                        Task {
                            await onPost()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(!canPost)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.blue)
                }
            }
            .safeAreaInset(edge: .bottom) {
                // Bottom left camera button - centered vertically
                HStack {
                    Button(action: {
                        Task {
                            // Request photo library access first (iOS 18+ best practice)
                            let hasAccess = await PhotoLibraryManager.shared.requestPhotoLibraryAccess()
                            if hasAccess {
                                showingImageSourceActionSheet = true
                            } else {
                                // Handle permission denied - could show settings alert
                                print("Photo library access denied")
                            }
                        }
                    }) {
                        Image(systemName: "camera")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.blue)
                    }
                    .disabled(isUploadingMedia)
                    .buttonStyle(.plain)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8) // Minimal bottom padding like iOS Messages
                .padding(.top, 16)
            }
        }
        .onAppear {
            // Load current user
            loadCurrentUser()
            
            // Don't auto-focus - let user tap to focus
        }
        .interactiveDismissDisabled(draft.content.count > 0 || !draft.media.isEmpty)
        .onChange(of: selectedPhotos) { _, newPhotos in
            Task {
                await processSelectedPhotos(newPhotos)
            }
        }
        .confirmationDialog("Add Photo", isPresented: $showingImageSourceActionSheet) {
            Button("Camera") {
                showingCamera = true
            }
            
            Button("Photo Library") {
                showingPhotoLibraryPicker = true
                // iOS 18+ best practice: prompt for full access if limited
                if PhotoLibraryManager.shared.hasLimitedAccess {
                    PhotoLibraryManager.shared.promptForFullAccessIfLimited()
                }
            }
            
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Choose how you'd like to add a photo")
        }
        .photosPicker(
            isPresented: $showingPhotoLibraryPicker,
            selection: $selectedPhotos,
            maxSelectionCount: 4,
            matching: .images
        )
        .fullScreenCover(isPresented: $showingCamera) {
            ImagePicker(sourceType: .camera) { image in
                Task {
                    await processCameraImage(image)
                }
            }
        }
    }
    
    @ViewBuilder
    private func mainContent(geometry: GeometryProxy) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // User info section using PostHeader component for consistency
                PostHeader(
                    avatarURL: currentUser?.avatarURL,
                    displayName: currentUser?.displayName ?? "You",
                    username: currentUser?.username,
                    badgeType: currentUser?.badgeType,
                    // No timestamp in compose view
                    showDebugOverlay: showDebugOverlay
                )
                .padding(.horizontal, 20)
                .padding(.top, 4)
                    
                    // Text input section - expanded to fill safe area
                    VStack(alignment: .leading, spacing: 8) {
                        ZStack(alignment: .bottomTrailing) {
                            TextField(
                                draft.isReply ? "Post your reply..." : "What's happening in your loop?",
                                text: $draft.content,
                                axis: .vertical
                            )
                            .foregroundStyle(.primary)
                            .accentColor(.blue)
                            .font(.body)
                            .focused($isTextFieldFocused)
                            .lineLimit(isSheetExpanded ? (4...Int.max) : (3...4))
                            .textInputAutocapitalization(.sentences)
                            .frame(
                                minHeight: isSheetExpanded ? 96 : 72, // 4 lines when expanded, 3 when compact
                                maxHeight: isSheetExpanded ? nil : 96 // No height limit when expanded, limited when compact
                            )
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .padding(.trailing, 60) // Make room for character counter
                            
                            // Character counter inside textbox
                            Text("\(draft.remainingCharacters)")
                                .font(.caption)
                                .foregroundColor(characterCountColor)
                                .monospacedDigit()
                                .padding(.trailing, 16)
                                .padding(.bottom, 12)
                        }
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            ConcentricRectangle(
                                topLeadingCorner: .concentric(minimum: 12),
                                topTrailingCorner: .concentric(minimum: 12),
                                bottomLeadingCorner: .concentric(minimum: 12),
                                bottomTrailingCorner: .concentric(minimum: 12)
                            )
                            .stroke(
                                Color(.separator).opacity(0.6), 
                                lineWidth: 1.0
                            )
                        )
                        .padding(.horizontal, 16) // Match toolbar button alignment
                        .padding(.bottom, 16) // Add padding under textbox
                    }
                    
                    // Media preview
                    if !draft.media.isEmpty {
                        MediaPreviewView(media: $draft.media)
                            .padding(.horizontal, 20)
                    }
                    
                    // Upload progress
                    if isUploadingMedia {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Uploading media...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    Spacer(minLength: 20)
            }
        }
        .scrollDisabled(!isSheetExpanded)
    }
    
    private func loadCurrentUser() {
        Task {
            do {
                guard let userId = Auth.auth().currentUser?.uid else { return }
                let user = try await FirebaseService.shared.getUser(withId: userId)
                await MainActor.run {
                    currentUser = user
                }
            } catch {
                print("Error loading current user: \(error)")
            }
        }
    }
    
    private func processSelectedPhotos(_ photos: [PhotosPickerItem]) async {
        guard !photos.isEmpty else { return }
        
        isUploadingMedia = true
        
        for photo in photos {
            do {
                if let data = try await photo.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    
                    // Upload to Firebase and get LoopMedia
                    let loopMedia = try await FirebaseService.shared.uploadLoopMedia(uiImage, type: .image)
                    
                    // Add to draft
                    await MainActor.run {
                        draft.media.append(loopMedia)
                    }
                }
            } catch {
                print("Error processing photo: \(error)")
            }
        }
        
        isUploadingMedia = false
        selectedPhotos = []
    }
    
    private func processCameraImage(_ image: UIImage) async {
        isUploadingMedia = true
        
        do {
            // Upload to Firebase and get LoopMedia
            let loopMedia = try await FirebaseService.shared.uploadLoopMedia(image, type: .image)
            
            // Add to draft
            await MainActor.run {
                draft.media.append(loopMedia)
            }
        } catch {
            print("Error processing camera image: \(error)")
        }
        
        isUploadingMedia = false
    }
}

struct MediaPreviewView: View {
    @Binding var media: [LoopMedia]
    
    var body: some View {
        if media.count == 1, let firstMedia = media.first {
            SingleMediaPreview(media: firstMedia) {
                removeMedia(firstMedia)
            }
        } else if media.count > 1 {
            MultipleMediaPreview(media: $media)
        }
    }
    
    private func removeMedia(_ mediaToRemove: LoopMedia) {
        media.removeAll { $0.id == mediaToRemove.id }
    }
}

struct SingleMediaPreview: View {
    let media: LoopMedia
    let onRemove: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            CachedAsyncImage(url: URL(string: media.url)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.systemGray5))
                    .frame(height: 200)
                    .overlay(
                        ProgressView()
                    )
            }
            .frame(maxHeight: 300)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            // Remove button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .background(
                        Circle()
                            .fill(.black.opacity(0.6))
                    )
            }
            .padding(8)
        }
    }
}

struct MultipleMediaPreview: View {
    @Binding var media: [LoopMedia]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(media, id: \.id) { mediaItem in
                    SingleMediaPreview(media: mediaItem) {
                        removeMedia(mediaItem)
                    }
                    .frame(width: 200)
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollTargetBehavior(.viewAligned)
    }
    
    private func removeMedia(_ mediaToRemove: LoopMedia) {
        media.removeAll { $0.id == mediaToRemove.id }
    }
}

#Preview {
    @State var draft = LoopDraft()
    @State var isPresented = true
    
    return ComposeLoopView(
        draft: $draft,
        isPresented: $isPresented,
        onPost: {
            print("Posting loop...")
        }
    )
}