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
    
    @Environment(\.dismiss) private var dismiss
    
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
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // User info section
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 16))
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("You")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Text("@username")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    // Text input section
                    VStack(alignment: .leading, spacing: 12) {
                        TextField(
                            draft.isReply ? "Post your reply..." : "What's happening in the loop?",
                            text: $draft.content,
                            axis: .vertical
                        )
                        .font(.body)
                        .focused($isTextFieldFocused)
                        .lineLimit(3...10)
                        .textInputAutocapitalization(.sentences)
                        .padding(.horizontal, 20)
                        
                        // Character count
                        HStack {
                            Spacer()
                            Text("\(draft.remainingCharacters)")
                                .font(.caption)
                                .foregroundColor(characterCountColor)
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 20)
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
                    
                    Spacer(minLength: 100)
                }
            }
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
                    .foregroundColor(canPost ? .accentColor : .secondary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                // Bottom toolbar
                VStack(spacing: 0) {
                    Divider()
                    
                    HStack(spacing: 20) {
                        // Photo button
                        Button(action: {
                            showingImageSourceActionSheet = true
                        }) {
                            Image(systemName: "photo")
                                .font(.system(size: 20, weight: .medium))
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
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.regularMaterial)
                }
            }
        }
        .onAppear {
            // Focus text field after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isTextFieldFocused = true
            }
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