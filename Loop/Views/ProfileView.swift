import SwiftUI
import FirebaseAuth
import PhotosUI

struct ProfileView: View {
    @State private var currentUser: User?
    @State private var isLoading = true
    @State private var showSettings = false
    @State private var isEditing = false
    
    // Editable fields
    @State private var editDisplayName: String = ""
    @State private var editUsername: String = ""
    @State private var editBio: String = ""
    
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
                        VStack(alignment: isEditing ? .center : .leading, spacing: 0) {
                            // Avatar
                            avatarView
                                .frame(maxWidth: .infinity, alignment: isEditing ? .center : .leading)
                                .padding(.leading, isEditing ? 0 : 16)
                            
                            // Profile info
                            VStack(alignment: isEditing ? .center : .leading, spacing: 4) {
                                displayNameView
                                usernameView
                                
                                if let bio = currentUser?.bio, !bio.isEmpty || isEditing {
                                    bioView
                                        .padding(.top, 8)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: isEditing ? .center : .leading)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 32)
                        }
                        .offset(y: -60)
                        .padding(.bottom, -60)
                        
                        // Settings section
                        if !isEditing {
                            settingsSection
                        }
                        
                        Spacer(minLength: 40)
                    }
                }
                .scrollIndicators(.hidden)
                .ignoresSafeArea(edges: .top)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
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
            .toolbarBackground(.visible, for: .navigationBar)
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
                    }
                }
            }
            .onChange(of: bannerPickerItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedBanner = image
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
                if let banner = selectedBanner {
                    Image(uiImage: banner)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
                
                if isEditing {
                    PhotosPicker(selection: $bannerPickerItem, matching: .images) {
                        Image(systemName: "camera.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
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
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(Color(.systemBackground), lineWidth: 4)
                    }
            } else {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 120, height: 120)
                    .overlay {
                        Circle()
                            .strokeBorder(Color(.systemBackground), lineWidth: 4)
                    }
                
                Color.clear
                    .frame(width: 120, height: 120)
                    .glassEffect(.regular, in: Circle())
                
                Text(userInitials)
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            if isEditing {
                PhotosPicker(selection: $avatarPickerItem, matching: .images) {
                    Image(systemName: "camera.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
                .offset(x: 42, y: 42)
            }
        }
    }
    
    // MARK: - User Info
    
    private var displayNameView: some View {
        Group {
            if isEditing {
                TextField("Display Name", text: $editDisplayName)
                    .font(.title3)
                    .fontWeight(.bold)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
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
            if isEditing {
                HStack(spacing: 0) {
                    Text("@")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    TextField("username", text: $editUsername)
                        .font(.callout)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 200)
                }
            } else {
                Text("@\(currentUser?.username ?? "username")")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.blue)
                    .font(.callout)
            }
        }
    }
    
    private var bioView: some View {
        Group {
            if isEditing {
                TextField("Add a bio...", text: $editBio, axis: .vertical)
                    .font(.callout)
                    .lineLimit(2...4)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
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
        VStack(spacing: 0) {
            Divider()
                .padding(.horizontal, 24)
            
            Button {
                showSettings = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.gray)
                        .frame(width: 28)
                    
                    Text("Settings")
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
            }
            
            Divider()
                .padding(.horizontal, 24)
            
            Button {
                showLogoutConfirmation = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.red)
                        .frame(width: 28)
                    
                    Text("Log Out")
                        .foregroundColor(.red)
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
            }
            
            Divider()
                .padding(.horizontal, 24)
        }
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
    
    // MARK: - Methods
    
    private func loadCurrentUser() {
        isLoading = true
        
        Task {
            do {
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
    }
    
    private func saveProfile() {
        isSaving = true
        
        Task {
            do {
                let cleanUsername = editUsername.trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "@", with: "")
                
                try await FirebaseService.shared.updateUserProfile(
                    displayName: editDisplayName.isEmpty ? nil : editDisplayName,
                    username: cleanUsername.isEmpty ? nil : cleanUsername,
                    bio: editBio.isEmpty ? nil : editBio
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
