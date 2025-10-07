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
    @FocusState private var isTextFieldFocused: Bool
    
    @Environment(\.dismiss) private var dismiss
    
    // Current user state
    @State private var currentUser: User?
    
    // Dynamic height tracking
    @State private var textHeight: CGFloat = 0
    @State private var isSheetExpanded = false
    
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
                        showingImageSourceActionSheet = true
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
            
            PhotosPicker(
                selection: $selectedPhotos,
                maxSelectionCount: 4,
                matching: .images
            ) {
                Text("Photo Library")
            }
            
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Choose how you'd like to add a photo")
        }
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
                // User info section - exact same styling as LoopCardView
                HStack(spacing: 16) {
                        // Avatar - exact same as LoopCardView
                        ZStack {
                            if let avatarURLString = currentUser?.avatarURL, let avatarURL = URL(string: avatarURLString) {
                                // Show actual user avatar
                                CachedAsyncImage(url: avatarURL) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 56, height: 56)
                                        .clipShape(Circle())
                                } placeholder: {
                                    // Placeholder while loading
                                    Circle()
                                        .fill(Color(.systemGray5))
                                        .frame(width: 56, height: 56)
                                        .overlay {
                                            ProgressView()
                                                .scaleEffect(0.7)
                                        }
                                }
                            } else {
                                // Default avatar with initials - exact same as LoopCardView
                                Circle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 50, height: 50)
                                
                                Color.clear
                                    .frame(width: 50, height: 50)
                                    .glassEffect(.regular, in: Circle())
                                
                                Text(String((currentUser?.displayName ?? "You").prefix(1)).uppercased())
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .center) {
                                HStack(spacing: 4) {
                                    Text(currentUser?.displayName ?? "You")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .lineLimit(1)
                                    
                                    // Badge if user has one - exact same as LoopCardView
                                    if let badgeType = currentUser?.badgeType {
                                        Image(systemName: badgeType.iconName)
                                            .font(.system(size: 14))
                                            .foregroundColor(badgeType.color)
                                    }
                                }
                                
                                Spacer()
                            }
                            
                            // Username on its own line below the name - exact same as LoopCardView
                            if let username = currentUser?.username, !username.isEmpty {
                                HStack {
                                    Text("@\(username)")
                                        .font(.callout)
                                        .fontWeight(.regular)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                }
                            }
                        }
                        .frame(maxHeight: .infinity, alignment: .center)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    
                    // Text input section - expanded to fill safe area
                    VStack(alignment: .leading, spacing: 8) {
                        ZStack(alignment: .bottomTrailing) {
                            TextField(
                                draft.isReply ? "Post your reply..." : "What's happening in the loop?",
                                text: $draft.content,
                                axis: .vertical
                            )
                            .font(.body)
                            .focused($isTextFieldFocused)
                            .lineLimit(isSheetExpanded ? (4...Int.max) : (3...4))
                            .textInputAutocapitalization(.sentences)
                            .frame(
                                minHeight: isSheetExpanded ? 96 : 72, // 4 lines when expanded, 3 when compact
                                maxHeight: isSheetExpanded ? .infinity : 96 // Limit height in compact mode to not cover camera
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
                        .background(
                            .ultraThinMaterial.opacity(0.6),
                            in: ConcentricRectangle(
                                topLeadingCorner: .concentric(minimum: 12),
                                topTrailingCorner: .concentric(minimum: 12),
                                bottomLeadingCorner: .concentric(minimum: 12),
                                bottomTrailingCorner: .concentric(minimum: 12)
                            )
                        )
                        .overlay(
                            ConcentricRectangle(
                                topLeadingCorner: .concentric(minimum: 12),
                                topTrailingCorner: .concentric(minimum: 12),
                                bottomLeadingCorner: .concentric(minimum: 12),
                                bottomTrailingCorner: .concentric(minimum: 12)
                            )
                            .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
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