import SwiftUI
import FirebaseAuth

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
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollView {
                        profileHeaderSection
                        
                        Spacer(minLength: 40)
                    }
                    
                    if !isEditing {
                        List {
                            Section {
                                settingsButton
                                logoutButton
                            }
                        }
                        .listStyle(.insetGrouped)
                        .scrollDisabled(true)
                        .frame(height: 120)
                        .safeAreaPadding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isEditing {
                        Button("Cancel") {
                            cancelEditing()
                        }
                    } else {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    titlePill
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    trailingToolbarButton
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear {
                loadCurrentUser()
            }
            .navigationDestination(isPresented: $showSettings) {
                SettingsView()
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
    
    private var profileHeaderSection: some View {
        VStack(spacing: 0) {
            avatarView
            displayNameView
            usernameView
            bioView
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 32)
    }
    
    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 140, height: 140)
            
            Color.clear
                .frame(width: 140, height: 140)
                .glassEffect(.regular, in: Circle())
            
            Text(userInitials)
                .font(.system(size: 56, weight: .semibold))
                .foregroundColor(.primary)
        }
        .padding(.top, 20)
        .padding(.bottom, 20)
    }
    
    private var displayNameView: some View {
        Group {
            if isEditing {
                TextField("Display Name", text: $editDisplayName)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 40)
            } else {
                Text(currentUser?.displayName ?? "Display Name")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
        }
    }
    
    private var usernameView: some View {
        HStack(spacing: 0) {
            Text("@")
                .font(.title3)
                .foregroundColor(.secondary)
            
            if isEditing {
                TextField("username", text: $editUsername)
                    .font(.title3)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: 200)
            } else {
                HStack(spacing: 6) {
                    Text(currentUser?.username ?? "username")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
            }
        }
        .padding(.top, 2)
    }
    
    private var bioView: some View {
        Group {
            if isEditing {
                TextField("Add a bio...", text: $editBio, axis: .vertical)
                    .font(.body)
                    .lineLimit(3...5)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 16)
            } else {
                if let bio = currentUser?.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.top, 16)
                } else {
                    Text("Add a bio")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 16)
                }
            }
        }
    }
    
    private var settingsButton: some View {
        Button {
            showSettings = true
        } label: {
            HStack {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.gray)
                    .frame(width: 30)
                
                Text("Settings")
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var logoutButton: some View {
        Button {
            showLogoutConfirmation = true
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .foregroundColor(.red)
                    .frame(width: 30)
                
                Text("Log Out")
                    .foregroundColor(.red)
                
                Spacer()
            }
        }
    }
    
    private var titlePill: some View {
        Text("Profile")
            .font(.headline)
            .fontWeight(.semibold)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Color.clear
                    .glassEffect(.regular, in: Capsule())
            )
    }
    
    private var trailingToolbarButton: some View {
        Group {
            if isEditing {
                Button {
                    if isSaving { return }
                    saveProfile()
                } label: {
                    if isSaving {
                        ProgressView()
                            .tint(.blue)
                    } else {
                        Text("Done")
                            .fontWeight(.semibold)
                    }
                }
                .disabled(isSaving)
            } else {
                Button("Edit") {
                    startEditing()
                }
                .fontWeight(.semibold)
            }
        }
    }
    
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
    
    private func loadCurrentUser() {
        isLoading = true
        
        Task {
            do {
                // First try to get user from Firestore
                if let firebaseUser = Auth.auth().currentUser {
                    if let firestoreUser = try await FirebaseService.shared.getUser(withId: firebaseUser.uid) {
                        currentUser = firestoreUser
                    } else {
                        // Create user in Firestore if doesn't exist
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
        
        // Reset edit fields
        editDisplayName = ""
        editUsername = ""
        editBio = ""
    }
    
    private func saveProfile() {
        isSaving = true
        
        Task {
            do {
                // Clean up username (remove @ if user added it)
                let cleanUsername = editUsername.trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "@", with: "")
                
                // Update in Firestore
                try await FirebaseService.shared.updateUserProfile(
                    displayName: editDisplayName.isEmpty ? nil : editDisplayName,
                    username: cleanUsername.isEmpty ? nil : cleanUsername,
                    bio: editBio.isEmpty ? nil : editBio
                )
                
                // Reload user data
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
            // The app should automatically navigate back to login screen
            // via the AuthenticationViewModel's state listener
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
}

#Preview {
    ProfileView()
}
