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
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Profile Header
                    VStack(spacing: 12) {
                        // Avatar
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray6))
                                .frame(width: 120, height: 120)
                            
                            Text(userInitials)
                                .font(.system(size: 48, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 8)
                        
                        // Display Name
                        if isEditing {
                            TextField("Display Name", text: $editDisplayName)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .multilineTextAlignment(.center)
                                .textFieldStyle(.plain)
                                .padding(.horizontal, 40)
                        } else {
                            Text(currentUser?.displayName ?? "Display Name")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                        
                        // Username
                        HStack(spacing: 4) {
                            Text("@")
                                .font(.body)
                                .foregroundColor(.secondary)
                            
                            if isEditing {
                                TextField("username", text: $editUsername)
                                    .font(.body)
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: 200)
                            } else {
                                Text(currentUser?.username ?? "username")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.bottom, 32)
                    
                    // Main Content
                    VStack(spacing: 20) {
                        // Account Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("ACCOUNT")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 16)
                            
                            VStack(spacing: 0) {
                                // Phone Number
                                HStack(spacing: 12) {
                                    Image(systemName: "phone.fill")
                                        .foregroundColor(.green)
                                        .frame(width: 28)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Phone Number")
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        
                                        Text(formattedPhoneNumber)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    // Verified checkmark
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(.green)
                                        .font(.title3)
                                }
                                .padding(16)
                                .background(Color(.systemBackground))
                            }
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                            .padding(.horizontal, 16)
                        }
                        
                        // Bio Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("BIO")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 16)
                            
                            VStack(alignment: .leading, spacing: 0) {
                                if isEditing {
                                    TextField("Add a bio to tell people more about yourself...", text: $editBio, axis: .vertical)
                                        .font(.body)
                                        .lineLimit(5...10)
                                        .padding(16)
                                } else {
                                    if let bio = currentUser?.bio, !bio.isEmpty {
                                        Text(bio)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(16)
                                    } else {
                                        Text("Add a bio to tell people more about yourself...")
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                            .italic()
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(16)
                                    }
                                }
                            }
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                            .padding(.horizontal, 16)
                        }
                        
                        // Actions Section
                        if !isEditing {
                            VStack(spacing: 12) {
                                // Settings Button
                                Button(action: {
                                    showSettings = true
                                }) {
                                    HStack {
                                        Image(systemName: "gear")
                                            .frame(width: 28)
                                        Text("Settings")
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .padding(16)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                                
                                // Logout Button
                                Button(action: {
                                    showLogoutConfirmation = true
                                }) {
                                    HStack {
                                        Image(systemName: "rectangle.portrait.and.arrow.right")
                                            .frame(width: 28)
                                        Text("Log Out")
                                        Spacer()
                                    }
                                    .font(.body)
                                    .foregroundColor(.red)
                                    .padding(16)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                        }
                    }
                    
                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
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
                
                if isEditing {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") {
                            cancelEditing()
                        }
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
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
