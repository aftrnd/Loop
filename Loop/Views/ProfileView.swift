import SwiftUI
import FirebaseAuth
import PhotosUI

struct ProfileView: View {
    // Optional userId - if nil, shows current user's profile (editable)
    // If provided, shows that user's profile (read-only)
    let userId: String?
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var currentUser: User?
    @State private var isLoading = true
    @State private var showSettings = false
    @State private var isEditing = false
    
    // Editable fields
    @State private var editDisplayName: String = ""
    @State private var editUsername: String = ""
    @State private var editBio: String = ""
    @State private var editLocation: String = ""
    
    // Save state
    @State private var isSaving = false
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""
    
    // Logout
    @State private var showLogoutConfirmation = false
    @Environment(\.dismiss) private var dismiss
    
    // Avatar editing with native PhotosPicker
    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var bannerPickerItem: PhotosPickerItem?
    @State private var selectedBanner: UIImage?
    
    // Layout constants
    private let avatarMaskSize: CGFloat = 110
    private let avatarImageSize: CGFloat = 100
    private let avatarLeadingPadding: CGFloat = 16
    private let avatarOverlapOffset: CGFloat = -55
    
    // Computed property to determine if viewing own profile
    private var isOwnProfile: Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return false }
        return userId == nil || userId == currentUserId
    }
    
    init(userId: String? = nil) {
        self.userId = userId
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let bannerHeight: CGFloat = 180
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Banner - extends to top edge
                        bannerContent
                            .frame(height: bannerHeight + geometry.safeAreaInsets.top)
                            .offset(y: -geometry.safeAreaInsets.top)
                            .padding(.bottom, -geometry.safeAreaInsets.top) // Collapse the extra space
                        
                        // Avatar and profile info - moves up to overlap banner
                        VStack(alignment: .leading, spacing: 0) {
                            // Avatar
                            avatarView
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, avatarLeadingPadding)
                            
                            // Profile info
                            VStack(alignment: .leading, spacing: 0) {
                                displayNameView
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                if isEditing && isOwnProfile {
                                    // Username and Location on same line when editing
                                    HStack(spacing: 8) {
                                        usernameView
                                        locationView
                                    }
                                    .padding(.vertical, 8)
                                } else {
                                    // Stacked when viewing
                                    VStack(alignment: .leading, spacing: 4) {
                                        usernameView
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.vertical, 8)
                                }
                                
                                if let bio = currentUser?.bio, !bio.isEmpty || (isEditing && isOwnProfile) {
                                    bioView
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 16)
                        }
                        .offset(y: avatarOverlapOffset)
                        .padding(.bottom, avatarOverlapOffset)
                        
                        // Settings section with fade effect (only for own profile)
                        if !isEditing && isOwnProfile {
                            GeometryReader { settingsGeo in
                                let minY = settingsGeo.frame(in: .global).minY
                                let screenHeight = UIScreen.main.bounds.height
                                let fadeStart = screenHeight * 0.7
                                let fadeEnd = screenHeight * 0.5
                                let opacity = min(max((fadeStart - minY) / (fadeStart - fadeEnd), 0), 1)
                                
                                settingsSection
                                    .opacity(opacity)
                            }
                        }
                        
                        Spacer(minLength: 40)
                    }
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
                .ignoresSafeArea(edges: .top)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isEditing {
                        Button("Cancel") {
                            cancelEditing()
                        }
                        .fontWeight(.medium)
                    } else {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.body.weight(.medium))
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if isOwnProfile {
                        if isEditing {
                            Button {
                                if isSaving { return }
                                saveProfile()
                            } label: {
                                if isSaving {
                                    ProgressView()
                                } else {
                                    Text("Done")
                                        .fontWeight(.medium)
                                }
                            }
                            .disabled(isSaving)
                        } else {
                            Button("Edit") {
                                startEditing()
                            }
                            .fontWeight(.medium)
                        }
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
            .onAppear {
                loadCurrentUser()
            }
            .navigationDestination(isPresented: $showSettings) {
                SettingsView()
            }
            .onChange(of: avatarPickerItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImage = image
                        // Upload to Firebase Storage
                        do {
                            _ = try await FirebaseService.shared.uploadAvatarImage(image)
                            // Reload user to get updated avatar URL
                            if let firebaseUser = Auth.auth().currentUser {
                                currentUser = try await FirebaseService.shared.getUser(withId: firebaseUser.uid)
                            }
                        } catch {
                            print("Error uploading avatar: \(error.localizedDescription)")
                        }
                    }
                }
            }
            .onChange(of: bannerPickerItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedBanner = image
                        // Upload to Firebase Storage
                        do {
                            _ = try await FirebaseService.shared.uploadBannerImage(image)
                            // Reload user to get updated banner URL
                            if let firebaseUser = Auth.auth().currentUser {
                                currentUser = try await FirebaseService.shared.getUser(withId: firebaseUser.uid)
                            }
                        } catch {
                            print("Error uploading banner: \(error.localizedDescription)")
                        }
                    }
                }
            }
            .alert("Log Out", isPresented: $showLogoutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Log Out", role: .destructive) {
                    logout()
                }
            } message: {
                Text("Are you sure you want to log out?")
            }
            .alert("Error Saving Profile", isPresented: $showSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(saveErrorMessage)
            }
        }
    }
    
    // MARK: - Banner
    
    private var bannerContent: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let banner = selectedBanner {
                        // Show locally selected image (while uploading or editing)
                        Image(uiImage: banner)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    } else if let bannerURL = currentUser?.bannerURL, let url = URL(string: bannerURL) {
                        // Load from Firebase Storage URL with caching
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                        } placeholder: {
                            ZStack {
                                Color(.systemGray5)
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                                
                                ProgressView()
                            }
                        }
                    } else {
                        // Default gray background
                        Color(.systemGray5)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                }
                .mask {
                    ZStack {
                        Rectangle()
                        // Cut out avatar ring area - positioned exactly where avatar will be
                        // Avatar center: x = leadingPadding + (maskSize / 2), y = banner bottom (height)
                        Circle()
                            .frame(width: avatarMaskSize, height: avatarMaskSize)
                            .offset(
                                x: -(geometry.size.width / 2) + avatarLeadingPadding + (avatarMaskSize / 2),
                                y: (geometry.size.height / 2)
                            )
                            .blendMode(.destinationOut)
                    }
                }
                
                if isEditing && isOwnProfile {
                    PhotosPicker(selection: $bannerPickerItem, matching: .images) {
                        Image(systemName: "camera.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(8)
                            .background {
                                Color.clear
                                    .glassEffect(.regular, in: Circle())
                            }
                    }
                    .padding(12)
                }
            }
        }
    }
    
    // MARK: - Avatar
    
    private var avatarView: some View {
        ZStack {
            if let image = selectedImage {
                // Show locally selected image (while uploading or editing)
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: avatarImageSize, height: avatarImageSize)
                    .clipShape(Circle())
            } else if let avatarURL = currentUser?.avatarURL, let url = URL(string: avatarURL) {
                // Load from Firebase Storage URL with caching
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: avatarImageSize, height: avatarImageSize)
                        .clipShape(Circle())
                } placeholder: {
                    ZStack {
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: avatarImageSize, height: avatarImageSize)
                        
                        ProgressView()
                    }
                }
            } else {
                // Default initials view
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: avatarImageSize, height: avatarImageSize)
                
                Color.clear
                    .frame(width: avatarImageSize, height: avatarImageSize)
                    .glassEffect(.regular, in: Circle())
                
                Text(userInitials)
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            if isEditing && isOwnProfile {
                PhotosPicker(selection: $avatarPickerItem, matching: .images) {
                    Image(systemName: "camera.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(8)
                        .background {
                            Color.clear
                                .glassEffect(.regular, in: Circle())
                        }
                }
                .offset(x: avatarImageSize / 2 - 8, y: avatarImageSize / 2 - 8)
            }
        }
        .frame(width: avatarMaskSize, height: avatarMaskSize) // Keep the overall frame for layout
    }
    
    // MARK: - User Info
    
    private var displayNameView: some View {
        Group {
            if isEditing && isOwnProfile {
                TextField("Display Name", text: $editDisplayName)
                    .font(.title3)
                    .fontWeight(.bold)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(height: 36)
                    .background {
                        Color.clear
                            .glassEffect(.regular, in: .rect(cornerRadius: 12))
                    }
            } else {
                Text(currentUser?.displayName ?? "Display Name")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
            }
        }
    }
    
    private var usernameView: some View {
        HStack(spacing: 4) {
            if isEditing && isOwnProfile {
                HStack(spacing: 4) {
                    Text("@")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    TextField("username", text: $editUsername)
                        .font(.callout)
                        .textFieldStyle(.plain)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: editUsername) { oldValue, newValue in
                            editUsername = sanitizeUsername(newValue)
                        }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, maxHeight: 36)
                .background {
                    Color.clear
                        .glassEffect(.regular, in: .rect(cornerRadius: 12))
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "at")
                        .font(.callout)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                    Text(currentUser?.username ?? "username")
                        .font(.callout)
                        .fontWeight(.regular)
                        .foregroundStyle(.secondary)
                }
                
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.blue)
                    .font(.callout)
                
                // Location - only show if exists
                if let location = currentUser?.location, !location.isEmpty {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Text(location)
                        .font(.callout)
                        .fontWeight(.regular)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var locationView: some View {
        HStack(spacing: 4) {
            Image(systemName: "location.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            TextField("Add location...", text: $editLocation)
                .font(.callout)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: 36)
        .background {
            Color.clear
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
        }
    }
    
    private var bioView: some View {
        Group {
            if isEditing && isOwnProfile {
                TextField("Add a bio...", text: $editBio, axis: .vertical)
                    .font(.callout)
                    .lineLimit(2...4)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
                    .background {
                        Color.clear
                            .glassEffect(.regular, in: .rect(cornerRadius: 12))
                    }
            } else {
                if let bio = currentUser?.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
    
    // MARK: - Settings
    
    private var settingsSection: some View {
        List {
            // Phone Number Section
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "phone.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Phone Number")
                            .font(.body)
                        
                        Text(formattedPhoneNumber)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Verified badge
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                }
                .padding(.vertical, 4)
                .listRowBackground(colorScheme == .dark ? Color.black : Color(.systemGray6))
            } footer: {
                Text("Not public and only visible to you")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Settings & Actions Section
            Section {
                Button {
                    showSettings = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "gear")
                            .foregroundColor(.gray)
                            .font(.title3)
                            .frame(width: 30)
                        
                        Text("Settings")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .listRowBackground(colorScheme == .dark ? Color.black : Color(.systemGray6))
                
                Button {
                    showLogoutConfirmation = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle")
                            .foregroundColor(.red)
                            .font(.title3)
                            .frame(width: 30)
                        
                        Text("Log Out")
                            .foregroundColor(.red)
                        
                        Spacer()
                    }
                }
                .listRowBackground(colorScheme == .dark ? Color.black : Color(.systemGray6))
            }
        }
        .listStyle(.insetGrouped)
        .scrollDisabled(true)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 0, for: .scrollContent)
        .frame(height: 250)
    }
    
    // MARK: - Helper Properties
    
    private var userInitials: String {
        let displayName = isEditing ? editDisplayName : (currentUser?.displayName ?? "")
        
        guard !displayName.isEmpty else {
            return "?"
        }
        
        let components = displayName.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        } else if components.count == 1 {
            return String(displayName.prefix(2)).uppercased()
        }
        
        return "?"
    }
    
    private var formattedPhoneNumber: String {
        guard let phoneNumber = currentUser?.phoneNumber else {
            return "No phone number"
        }
        
        // Format phone number for display (assuming US format)
        let digits = phoneNumber.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        guard digits.count == 11 && digits.hasPrefix("1") else {
            return phoneNumber // Return as-is if not in expected format
        }
        
        let areaCode = String(digits.dropFirst(1).prefix(3))
        let firstPart = String(digits.dropFirst(4).prefix(3))
        let lastPart = String(digits.dropFirst(7))
        
        return "(\(areaCode)) \(firstPart)-\(lastPart)"
    }
    
    // MARK: - Helper Methods
    
    private func sanitizeUsername(_ username: String) -> String {
        // Convert to lowercase
        let lowercased = username.lowercased()
        
        // Only allow alphanumeric, hyphen, and underscore
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let filtered = lowercased.unicodeScalars.filter { allowedCharacters.contains($0) }
        
        return String(String.UnicodeScalarView(filtered))
    }
    
    // MARK: - Methods
    
    private func loadCurrentUser() {
        isLoading = true
        
        Task {
            do {
                if let targetUserId = userId {
                    // Loading another user's profile
                    if let user = try await FirebaseService.shared.getUser(withId: targetUserId) {
                        currentUser = user
                    }
                } else {
                    // Loading own profile
                    if let firebaseUser = Auth.auth().currentUser {
                        if let firestoreUser = try await FirebaseService.shared.getUser(withId: firebaseUser.uid) {
                            currentUser = firestoreUser
                        } else {
                            currentUser = try await FirebaseService.shared.createUserIfNotExists(
                                phoneNumber: firebaseUser.phoneNumber ?? "",
                                displayName: firebaseUser.displayName
                            )
                        }
                    }
                }
                isLoading = false
            } catch {
                print("Error loading user: \(error)")
                isLoading = false
            }
        }
    }
    
    private func startEditing() {
        editDisplayName = currentUser?.displayName ?? ""
        editUsername = currentUser?.username ?? ""
        editBio = currentUser?.bio ?? ""
        editLocation = currentUser?.location ?? ""
        
        withAnimation(.easeInOut(duration: 0.25)) {
            isEditing = true
        }
    }
    
    private func cancelEditing() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isEditing = false
        }
        
        editDisplayName = ""
        editUsername = ""
        editBio = ""
        editLocation = ""
    }
    
    private func saveProfile() {
        isSaving = true
        
        Task {
            do {
                // Sanitize username: lowercase, alphanumeric + hyphen + underscore only
                let cleanUsername = sanitizeUsername(editUsername.trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "@", with: ""))
                
                try await FirebaseService.shared.updateUserProfile(
                    displayName: editDisplayName.isEmpty ? nil : editDisplayName,
                    username: cleanUsername.isEmpty ? nil : cleanUsername,
                    bio: editBio.isEmpty ? nil : editBio,
                    location: editLocation.isEmpty ? nil : editLocation
                )
                
                if let firebaseUser = Auth.auth().currentUser {
                    currentUser = try await FirebaseService.shared.getUser(withId: firebaseUser.uid)
                }
                
                await MainActor.run {
                    isSaving = false
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isEditing = false
                    }
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    saveErrorMessage = error.localizedDescription
                    showSaveError = true
                }
            }
        }
    }
    
    private func logout() {
        do {
            try Auth.auth().signOut()
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
}

#Preview {
    ProfileView()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
}
