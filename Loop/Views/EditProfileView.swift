import SwiftUI
import FirebaseAuth
import PhotosUI
import ImageIO
import os

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    
    // User data
    @State private var currentUser: User?
    @State private var isLoading: Bool
    
    // Logout
    @State private var showLogoutConfirmation = false
    
    // Avatar editing
    @State private var showAvatarPicker = false
    @State private var avatarPickerItem: PhotosPickerItem?
    /// Downsampled preview of the picked avatar, shown while it uploads and after.
    @State private var selectedImage: UIImage?
    
    // Banner editing
    @State private var showBannerPicker = false
    @State private var bannerPickerItem: PhotosPickerItem?
    /// Downsampled preview of the picked banner, shown while it uploads and after.
    @State private var selectedBanner: UIImage?
    
    // Photo uploads
    /// Avatar and banner uploads in flight. Text fields save on their own screens, so this is the only work
    /// that leaving could interrupt.
    @State private var activeUploads = 0
    @State private var showLeaveDuringUploadAlert = false
    @State private var photoError: String?
    
    // Navigation
    @State private var showAppSettings = false
    
    private static let logger = Logger(subsystem: "com.nejack.Loop", category: "EditProfileView")
    
    /// - Parameter user: The profile as already loaded. It shows right away and refreshes in the background;
    ///   without it the screen shows a spinner until the profile loads.
    init(user: User? = nil) {
        _currentUser = State(initialValue: user)
        _isLoading = State(initialValue: user == nil)
    }
    
    private var isUploadingPhoto: Bool {
        activeUploads > 0
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                } else {
                    Form {
                        // MARK: - Banner & Avatar Section
                        Section {
                            HStack(spacing: 12) {
                                // Avatar
                                Button {
                                    Task {
                                        let hasAccess = await PhotoLibraryManager.shared.requestPhotoLibraryAccess()
                                        if hasAccess {
                                            showAvatarPicker = true
                                            if PhotoLibraryManager.shared.hasLimitedAccess {
                                                PhotoLibraryManager.shared.promptForFullAccessIfLimited()
                                            }
                                        }
                                    }
                                } label: {
                                    ZStack(alignment: .bottomTrailing) {
                                        // Avatar Image
                                        Group {
                                            if let image = selectedImage {
                                                Image(uiImage: image)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 80, height: 80)
                                                    .clipShape(Circle())
                                            } else if let avatarURL = currentUser?.avatarURL,
                                                      let url = URL(string: avatarURL) {
                                                CachedAsyncImage(url: url) { image in
                                                    image
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                        .frame(width: 80, height: 80)
                                                        .clipShape(Circle())
                                                } placeholder: {
                                                    avatarPlaceholder
                                                }
                                            } else {
                                                avatarPlaceholder
                                            }
                                        }
                                        
                                        // Camera icon with liquid glass
                                        Image(systemName: "camera")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                            .padding(6)
                                            .background {
                                                Color.clear
                                                    .glassEffect(.regular, in: Circle())
                                            }
                                            .offset(x: -2, y: -2)
                                    }
                                    .frame(width: 80, height: 80)
                                }
                                .buttonStyle(.plain)
                                
                                // Banner Preview
                                Button {
                                    Task {
                                        let hasAccess = await PhotoLibraryManager.shared.requestPhotoLibraryAccess()
                                        if hasAccess {
                                            showBannerPicker = true
                                            if PhotoLibraryManager.shared.hasLimitedAccess {
                                                PhotoLibraryManager.shared.promptForFullAccessIfLimited()
                                            }
                                        }
                                    }
                                } label: {
                                    ZStack(alignment: .bottomTrailing) {
                                        // Banner Image
                                        Group {
                                            if let banner = selectedBanner {
                                                Image(uiImage: banner)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                            } else if let bannerURL = currentUser?.bannerURL,
                                                      let url = URL(string: bannerURL) {
                                                CachedAsyncImage(url: url) { image in
                                                    image
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                } placeholder: {
                                                    Color(.systemGray5)
                                                }
                                            } else {
                                                Color(.systemGray5)
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        
                                        // Camera icon with liquid glass
                                        Image(systemName: "camera")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                            .padding(6)
                                            .background {
                                                Color.clear
                                                    .glassEffect(.regular, in: Circle())
                                            }
                                            .offset(x: -6, y: -6)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 8)
                            .listRowBackground(Color.clear)
                        }
                        
                        // MARK: - Profile Information Section
                        Section {
                            // Display Name
                            NavigationLink {
                                EditDisplayNameView(
                                    currentValue: currentUser?.displayName ?? "",
                                    onSave: { newValue in
                                        try await saveProfile(displayName: newValue)
                                    }
                                )
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "person")
                                        .foregroundColor(.primary)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .frame(width: 28)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Name")
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        
                                        if let displayName = currentUser?.displayName, !displayName.isEmpty {
                                            Text(displayName)
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                            }
                            
                            // Bio
                            NavigationLink {
                                EditBioView(
                                    currentValue: currentUser?.bio ?? "",
                                    onSave: { newValue in
                                        try await saveProfile(bio: newValue)
                                    }
                                )
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "pencil")
                                        .foregroundColor(.primary)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .frame(width: 28)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Bio")
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        
                                        if let bio = currentUser?.bio, !bio.isEmpty {
                                            Text(bio)
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                            }
                            
                            // Username
                            NavigationLink {
                                EditUsernameView(
                                    currentValue: currentUser?.username ?? "",
                                    onSave: { newValue in
                                        try await saveProfile(username: newValue)
                                    }
                                )
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "at")
                                        .foregroundColor(.primary)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .frame(width: 28)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Username")
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        
                                        if let username = currentUser?.username, !username.isEmpty {
                                            Text("@\(username)")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // MARK: - Account Section
                        Section {
                            // Phone Number (Read-only)
                            HStack(spacing: 12) {
                                Image(systemName: "phone")
                                    .foregroundColor(.green)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .frame(width: 28)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Phone Number")
                                        .font(.body)
                                    Text(formattedPhoneNumber)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "checkmark.seal")
                                    .foregroundColor(.green)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }
                            
                            // Settings
                            Button {
                                showAppSettings = true
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "gear")
                                        .foregroundColor(.primary)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .frame(width: 28)
                                    
                                    Text("Settings")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        // MARK: - Logout Section
                        Section {
                            Button(role: .destructive) {
                                showLogoutConfirmation = true
                            } label: {
                                HStack {
                                    Spacer()
                                    Text("Log Out")
                                        .font(.body)
                                        .fontWeight(.medium)
                                    Spacer()
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if isUploadingPhoto {
                            showLeaveDuringUploadAlert = true
                        } else {
                            dismiss()
                        }
                    } label: {
                        if isUploadingPhoto {
                            Text("Cancel")
                                .fontWeight(.medium)
                        } else {
                            Image(systemName: "chevron.left")
                                .font(.body.weight(.medium))
                        }
                    }
                }
            }
            .interactiveDismissDisabled(isUploadingPhoto)
        }
        .task {
            await loadCurrentUser()
        }
        .photosPicker(
            isPresented: $showAvatarPicker,
            selection: $avatarPickerItem,
            matching: .images
        )
        .photosPicker(
            isPresented: $showBannerPicker,
            selection: $bannerPickerItem,
            matching: .images
        )
        .onChange(of: avatarPickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await uploadPhoto(newItem, as: .avatar)
            }
        }
        .onChange(of: bannerPickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await uploadPhoto(newItem, as: .banner)
            }
        }
        // Leaving doesn't stop an upload, so say what actually happens instead of offering to discard
        .alert("Photo still uploading", isPresented: $showLeaveDuringUploadAlert) {
            Button("Keep editing", role: .cancel) { }
            Button("Leave") {
                dismiss()
            }
        } message: {
            Text("If you leave now, the upload will finish in the background.")
        }
        .alert("Couldn't update photo", isPresented: photoErrorBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(photoError ?? "")
        }
        .alert("Log Out", isPresented: $showLogoutConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Log Out", role: .destructive) {
                logout()
            }
        } message: {
            Text("Are you sure you want to log out?")
        }
        .sheet(isPresented: $showAppSettings) {
            SettingsView()
        }
    }
    
    // MARK: - Avatar Placeholder
    
    private var avatarPlaceholder: some View {
        ZStack {
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 80, height: 80)
            
            Text(userInitials)
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(.primary)
        }
    }
    
    // MARK: - Helper Properties
    
    private var userInitials: String {
        let name = currentUser?.displayName ?? ""
        
        guard !name.isEmpty else {
            return "?"
        }
        
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        } else if components.count == 1 {
            return String(name.prefix(2)).uppercased()
        }
        
        return "?"
    }
    
    private var formattedPhoneNumber: String {
        guard let phoneNumber = currentUser?.phoneNumber else {
            return "No phone number"
        }
        
        let digits = phoneNumber.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        guard digits.count == 11 && digits.hasPrefix("1") else {
            return phoneNumber
        }
        
        let areaCode = String(digits.dropFirst(1).prefix(3))
        let firstPart = String(digits.dropFirst(4).prefix(3))
        let lastPart = String(digits.dropFirst(7))
        
        return "+1 (\(areaCode)) \(firstPart)-\(lastPart)"
    }
    
    // MARK: - Methods
    
    private func loadCurrentUser() async {
        if currentUser == nil {
            isLoading = true
        }
        defer { isLoading = false }
        
        guard let firebaseUser = Auth.auth().currentUser else { return }
        do {
            if let firestoreUser = try await FirebaseService.shared.getUser(withId: firebaseUser.uid) {
                currentUser = firestoreUser
            }
        } catch {
            Self.logger.error("Profile load failed: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    private func reloadUser() async {
        guard let firebaseUser = Auth.auth().currentUser else { return }
        if let firestoreUser = try? await FirebaseService.shared.getUser(withId: firebaseUser.uid, forceRefresh: true) {
            currentUser = firestoreUser
        }
    }
    
    /// Writes the given fields and reloads the profile, so the list shows the new values when the edit screen closes.
    private func saveProfile(displayName: String? = nil, username: String? = nil, bio: String? = nil) async throws {
        try await FirebaseService.shared.updateUserProfile(
            displayName: displayName,
            username: username,
            bio: bio,
            location: nil
        )
        await reloadUser()
    }
    
    // MARK: - Photos
    
    private enum PhotoKind {
        case avatar
        case banner
        
        /// The frame the preview fills, in points. The banner's width is generous so wide screens stay sharp.
        var previewSize: CGSize {
            switch self {
            case .avatar: CGSize(width: 80, height: 80)
            case .banner: CGSize(width: 600, height: 80)
            }
        }
    }
    
    /// Shows a downsampled preview of the picked photo, then uploads the full image. On failure the
    /// preview is removed and the error is shown.
    private func uploadPhoto(_ item: PhotosPickerItem, as kind: PhotoKind) async {
        guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
            photoError = "That photo couldn't be opened. Please try another."
            return
        }
        
        activeUploads += 1
        defer { activeUploads -= 1 }
        
        let preview = await PhotoPreview.make(from: data, filling: kind.previewSize, scale: displayScale)
        setPreview(preview, for: kind)
        
        do {
            switch kind {
            case .avatar:
                _ = try await FirebaseService.shared.uploadAvatarImage(image)
            case .banner:
                _ = try await FirebaseService.shared.uploadBannerImage(image)
            }
            await reloadUser()
        } catch {
            Self.logger.error("Photo upload failed: \(error.localizedDescription, privacy: .public)")
            setPreview(nil, for: kind)
            photoError = error.localizedDescription
        }
    }
    
    private func setPreview(_ preview: UIImage?, for kind: PhotoKind) {
        switch kind {
        case .avatar: selectedImage = preview
        case .banner: selectedBanner = preview
        }
    }
    
    private var photoErrorBinding: Binding<Bool> {
        Binding(
            get: { photoError != nil },
            set: { isPresented in
                if !isPresented {
                    photoError = nil
                }
            }
        )
    }
    
    private func logout() {
        do {
            try Auth.auth().signOut()
            dismiss()
        } catch {
            Self.logger.error("Sign out failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - Photo Preview

/// Decodes a picked photo at the size its preview is drawn, off the main actor, so an 80pt circle doesn't
/// decode and draw a full-resolution camera image on the main thread.
private nonisolated enum PhotoPreview {
    static func make(from data: Data, filling pointSize: CGSize, scale: CGFloat) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            downsample(data, filling: pointSize, scale: scale)
        }.value
    }
    
    private static func downsample(_ data: Data, filling pointSize: CGSize, scale: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat,
              width > 0, height > 0 else {
            return nil
        }
        
        // EXIF orientations 5 to 8 are rotated a quarter turn, so the drawn width is the stored height
        let orientation = properties[kCGImagePropertyOrientation] as? UInt32 ?? 1
        let isQuarterTurned = (5...8).contains(orientation)
        let drawnWidth = isQuarterTurned ? height : width
        let drawnHeight = isQuarterTurned ? width : height
        
        // The smallest size that still fills the frame at full sharpness, never larger than the original
        let fillScale = max(pointSize.width * scale / drawnWidth, pointSize.height * scale / drawnHeight)
        let maxPixelSize = (max(width, height) * min(fillScale, 1)).rounded(.up)
        
        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Edit Detail Views

struct EditDisplayNameView: View {
    @State private var text: String
    private let originalValue: String
    let onSave: (String) async throws -> Void
    
    init(currentValue: String, onSave: @escaping (String) async throws -> Void) {
        _text = State(initialValue: currentValue)
        self.originalValue = currentValue
        self.onSave = onSave
    }
    
    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var body: some View {
        Form {
            Section {
                TextField("Display Name", text: $text)
                    .font(.body)
            } footer: {
                Text("This is the name that will be displayed on your profile.")
                    .font(.caption)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Name")
        .navigationBarTitleDisplayMode(.inline)
        .modifier(EditFieldToolbar(canSave: !trimmedText.isEmpty, hasChanges: trimmedText != originalValue) {
            try await onSave(trimmedText)
        })
    }
}

struct EditBioView: View {
    @State private var text: String
    private let originalValue: String
    let onSave: (String) async throws -> Void
    
    init(currentValue: String, onSave: @escaping (String) async throws -> Void) {
        _text = State(initialValue: currentValue)
        self.originalValue = currentValue
        self.onSave = onSave
    }
    
    var body: some View {
        Form {
            Section {
                TextField("Add a bio...", text: $text, axis: .vertical)
                    .font(.body)
                    .lineLimit(2...6)
            } footer: {
                Text("Write a few words about yourself. This will be visible on your profile.")
                    .font(.caption)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Bio")
        .navigationBarTitleDisplayMode(.inline)
        // An empty bio is allowed: it clears the bio
        .modifier(EditFieldToolbar(canSave: true, hasChanges: text != originalValue) {
            try await onSave(text)
        })
    }
}

struct EditUsernameView: View {
    @State private var text: String
    private let originalValue: String
    let onSave: (String) async throws -> Void
    
    init(currentValue: String, onSave: @escaping (String) async throws -> Void) {
        _text = State(initialValue: currentValue)
        self.originalValue = currentValue
        self.onSave = onSave
    }
    
    var body: some View {
        Form {
            Section {
                HStack(spacing: 4) {
                    Text("@")
                        .foregroundColor(.secondary)
                    TextField("username", text: $text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: text) { _, newValue in
                            text = sanitizeUsername(newValue)
                        }
                }
                .font(.body)
            } footer: {
                Text("Your username must be unique. Only letters, numbers, hyphens, and underscores are allowed.")
                    .font(.caption)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Username")
        .navigationBarTitleDisplayMode(.inline)
        .modifier(EditFieldToolbar(canSave: !text.isEmpty, hasChanges: text != originalValue) {
            try await onSave(text)
        })
    }
    
    private func sanitizeUsername(_ username: String) -> String {
        let lowercased = username.lowercased()
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let filtered = lowercased.unicodeScalars.filter { allowedCharacters.contains($0) }
        return String(String.UnicodeScalarView(filtered))
    }
}

/// Cancel and Save for the edit screens. Save waits for the write: while it runs the button shows a spinner
/// and is disabled; on success the screen closes, and on failure the error is shown and the edit is kept.
private struct EditFieldToolbar: ViewModifier {
    let canSave: Bool
    let hasChanges: Bool
    let save: () async throws -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var saveState = SaveState.idle
    
    private enum SaveState: Equatable {
        case idle
        case saving
        case failed(String)
    }
    
    private var failureMessage: String? {
        if case .failed(let message) = saveState {
            return message
        }
        return nil
    }
    
    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await submit()
                        }
                    } label: {
                        if saveState == .saving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave || saveState == .saving)
                }
            }
            .alert("Couldn't save", isPresented: failureBinding) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(failureMessage ?? "")
            }
    }
    
    private var failureBinding: Binding<Bool> {
        Binding(
            get: { failureMessage != nil },
            set: { isPresented in
                if !isPresented {
                    saveState = .idle
                }
            }
        )
    }
    
    private func submit() async {
        // Nothing changed, so there is nothing to write
        guard hasChanges else {
            dismiss()
            return
        }
        
        saveState = .saving
        do {
            try await save()
            saveState = .idle
            dismiss()
        } catch {
            saveState = .failed(error.localizedDescription)
        }
    }
}

#Preview {
    EditProfileView()
}
