import SwiftUI
import PhotosUI
import UIKit

struct ComposeLoopView: View {
    @Binding var draft: LoopDraft
    @Binding var isPresented: Bool
    let onPost: () async -> Void
    
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var isUploadingMedia = false
    @State private var showingImageSourceActionSheet = false
    @State private var showingCamera = false
    @FocusState private var isTextFieldFocused: Bool
    
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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if draft.isReply {
                        Text("Reply")
                            .font(.headline)
                            .fontWeight(.semibold)
                    } else {
                        Text("New Loop")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    Button("Post") {
                        Task {
                            await onPost()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(!canPost)
                    .foregroundColor(canPost ? .accentColor : .secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                
                Divider()
                
                // Content area
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // User info (current user)
                        HStack(spacing: 12) {
                            // Current user avatar placeholder
                            Circle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 16))
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("You")
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Text("@username")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        
                        // Text input
                        VStack(alignment: .leading, spacing: 8) {
                            TextField(
                                draft.isReply ? "Post your reply..." : "What's happening in the loop?",
                                text: $draft.content,
                                axis: .vertical
                            )
                            .font(.system(.body, design: .default))
                            .focused($isTextFieldFocused)
                            .lineLimit(10...20)
                            .padding(.horizontal, 16)
                            
                            // Character count
                            HStack {
                                Spacer()
                                Text("\(draft.remainingCharacters)")
                                    .font(.caption)
                                    .foregroundColor(characterCountColor)
                                    .padding(.horizontal, 16)
                            }
                        }
                        
                        // Media preview
                        if !draft.media.isEmpty {
                            MediaPreviewView(media: $draft.media)
                                .padding(.horizontal, 16)
                        }
                        
                        // Media upload progress
                        if isUploadingMedia {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Uploading media...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                        }
                        
                        Spacer(minLength: 100)
                    }
                }
                
                // Bottom toolbar
                VStack(spacing: 0) {
                    Divider()
                    
                    HStack(spacing: 20) {
                        // Combined photo/camera button
                        Button(action: {
                            showingImageSourceActionSheet = true
                        }) {
                            Image(systemName: "photo")
                                .font(.system(size: 20))
                                .foregroundColor(.accentColor)
                        }
                        .disabled(isUploadingMedia)
                        
                        Spacer()
                        
                        // Privacy indicator
                        HStack(spacing: 4) {
                            Image(systemName: "globe")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Text("Everyone can reply")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemBackground))
                }
            }
            .background(Color(.systemBackground))
            .onAppear {
                isTextFieldFocused = true
            }
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
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 200)
                    .overlay(
                        ProgressView()
                    )
            }
            .frame(maxHeight: 300)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Remove button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .background(Circle().fill(Color.black.opacity(0.6)))
            }
            .padding(8)
        }
    }
}

struct MultipleMediaPreview: View {
    @Binding var media: [LoopMedia]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(media, id: \.id) { mediaItem in
                    SingleMediaPreview(media: mediaItem) {
                        removeMedia(mediaItem)
                    }
                    .frame(width: 150)
                }
            }
            .padding(.horizontal, 16)
        }
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
