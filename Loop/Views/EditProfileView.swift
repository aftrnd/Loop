import SwiftUI
import FirebaseAuth
import PhotosUI
import os

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    
    // User data
    @State private var currentUser: User?
    @State private var isLoading: Bool
    
    // Logout
    @State private var showLogoutConfirmation = false
    
    // Avatar editing
    @State private var showAvatarPicker = false
    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    
    // Banner editing
    @State private var showBannerPicker = false
    @State private var bannerPickerItem: PhotosPickerItem?
    @State private var selectedBanner: UIImage?
    
    // Track changes
    @State private var hasUnsavedChanges = false
    @State private var showDiscardAlert = false
    
    // Navigation
    @State private var showAppSettings = false
    
    private static let logger = Logger(subsystem: "com.nejack.Loop", category: "EditProfileView")
    
    /// - Parameter user: The profile as already loaded. It shows right away and refreshes in the background;
    ///   without it the screen shows a spinner until the profile loads.
    init(user: User? = nil) {
        _currentUser = State(initialValue: user)
        _isLoading = State(initialValue: user == nil)
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
                                        Task {
                                            try? await FirebaseService.shared.updateUserProfile(
                                                displayName: newValue,
                                                username: nil,
                                                bio: nil,
                                                location: nil
                                            )
                                            await reloadUser()
                                        }
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
                                        Task {
                                            try? await FirebaseService.shared.updateUserProfile(
                                                displayName: nil,
                                                username: nil,
                                                bio: newValue,
                                                location: nil
                                            )
                                            await reloadUser()
                                        }
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
                                        Task {
                                            try? await FirebaseService.shared.updateUserProfile(
                                                displayName: nil,
                                                username: newValue,
                                                bio: nil,
                                                location: nil
                                            )
                                            await reloadUser()
                                        }
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
                        if hasUnsavedChanges {
                            showDiscardAlert = true
                        } else {
                            dismiss()
                        }
                    } label: {
                        if hasUnsavedChanges {
                            Text("Cancel")
                                .fontWeight(.medium)
                        } else {
                            Image(systemName: "chevron.left")
                                .font(.body.weight(.medium))
                        }
                    }
                }
            }
            .interactiveDismissDisabled(hasUnsavedChanges)
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
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                    hasUnsavedChanges = true
                    do {
                        _ = try await FirebaseService.shared.uploadAvatarImage(image)
                        await reloadUser()
                        hasUnsavedChanges = false
                    } catch {
                        print("Error uploading avatar: \(error.localizedDescription)")
                        hasUnsavedChanges = false
                    }
                }
            }
        }
        .onChange(of: bannerPickerItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedBanner = image
                    hasUnsavedChanges = true
                    do {
                        _ = try await FirebaseService.shared.uploadBannerImage(image)
                        await reloadUser()
                        hasUnsavedChanges = false
                    } catch {
                        print("Error uploading banner: \(error.localizedDescription)")
                        hasUnsavedChanges = false
                    }
                }
            }
        }
        .alert("Discard Changes?", isPresented: $showDiscardAlert) {
            Button("Keep Editing", role: .cancel) { }
            Button("Discard", role: .destructive) {
                dismiss()
            }
        } message: {
            Text("You have unsaved changes. Are you sure you want to discard them?")
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
        if let firebaseUser = Auth.auth().currentUser {
            if let firestoreUser = try? await FirebaseService.shared.getUser(
                withId: firebaseUser.uid,
                forceRefresh: true
            ) {
                await MainActor.run {
                    self.currentUser = firestoreUser
                }
            }
        }
    }
    
    private func logout() {
        do {
            try Auth.auth().signOut()
            dismiss()
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
}

// MARK: - Edit Detail Views

struct EditDisplayNameView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    let onSave: (String) -> Void
    
    init(currentValue: String, onSave: @escaping (String) -> Void) {
        _text = State(initialValue: currentValue)
        self.onSave = onSave
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
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    onSave(text)
                    dismiss()
                }
                .fontWeight(.semibold)
                .disabled(text.isEmpty)
            }
        }
    }
}

struct EditBioView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    let onSave: (String) -> Void
    
    init(currentValue: String, onSave: @escaping (String) -> Void) {
        _text = State(initialValue: currentValue)
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
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    onSave(text)
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
    }
}

struct EditUsernameView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    let onSave: (String) -> Void
    
    init(currentValue: String, onSave: @escaping (String) -> Void) {
        _text = State(initialValue: currentValue)
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
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    onSave(text)
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
    }
    
    private func sanitizeUsername(_ username: String) -> String {
        let lowercased = username.lowercased()
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let filtered = lowercased.unicodeScalars.filter { allowedCharacters.contains($0) }
        return String(String.UnicodeScalarView(filtered))
    }
}

#Preview {
    EditProfileView()
}
