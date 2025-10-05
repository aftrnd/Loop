import SwiftUI
import FirebaseAuth

struct ToolbarButtonStyle: ViewModifier {
    let isEditing: Bool

    func body(content: Content) -> some View {
        if isEditing {
            content
                .labelStyle(.titleAndIcon)
                .buttonStyle(.borderedProminent)
        } else {
            content
                .fontWeight(.semibold)
        }
    }
}

struct SettingsView: View {
    @State private var currentUser: User?
    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var isEditing = false
    @State private var showDebugSettings = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // Profile Section
                Section("Profile") {
                    // Avatar (read-only for now)
                    HStack {
                        Text("Avatar")
                        Spacer()
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 40, height: 40)
                            .overlay {
                                Text(userInitials)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }

                    // Username
                    HStack {
                        Text("Username")
                        Spacer()
                        if isEditing {
                            TextField("@username", text: $username)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 120)
                        } else {
                            Text(currentUser?.username ?? "@username")
                                .foregroundColor(.secondary)
                        }
                    }

                    // Bio
                    if isEditing {
                        TextField("Add a bio...", text: $bio, axis: .vertical)
                            .lineLimit(3)
                    } else {
                        if let bio = currentUser?.bio, !bio.isEmpty {
                            Text(bio)
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                        } else {
                            Text("Add a bio to tell people more about yourself...")
                                .foregroundColor(.secondary)
                                .italic()
                                .lineLimit(2)
                        }
                    }
                }

                // Account Section
                Section("Account") {
                    HStack {
                        Image(systemName: "phone.fill")
                            .foregroundColor(.green)
                        VStack(alignment: .leading) {
                            Text("Phone Number")
                                .font(.subheadline)
                            Text(formattedPhoneNumber)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }

                // Debug Section (at bottom)
                Section {
                    Button("Debug Settings") {
                        showDebugSettings = true
                    }
                    .foregroundColor(.orange)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(isEditing)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if isEditing {
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                saveProfile()
                            }
                        } label: {
                            Label("Done", systemImage: "checkmark")
                        }
                        .labelStyle(.titleAndIcon)
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("Edit") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isEditing = true
                            }
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showDebugSettings) {
                DebugMenuView()
            }
            .onAppear {
                loadCurrentUser()
            }
        }
    }

    private var userInitials: String {
        guard let displayName = currentUser?.displayName else {
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
        Task {
            do {
                if let firebaseUser = FirebaseAuth.Auth.auth().currentUser {
                    currentUser = try await FirebaseService.shared.getUser(withId: firebaseUser.uid)
                    // Populate edit fields
                    username = currentUser?.username ?? ""
                    bio = currentUser?.bio ?? ""
                }
            } catch {
                print("Error loading user: \(error)")
            }
        }
    }

    private func saveProfile() {
        Task {
            do {
                // Clean up username (remove @ if user added it)
                let cleanUsername = username.trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "@", with: "")
                
                try await FirebaseService.shared.updateUserProfile(
                    displayName: nil, // Don't update display name from settings
                    username: cleanUsername.isEmpty ? nil : cleanUsername,
                    bio: bio.isEmpty ? nil : bio
                )
                
                // Reload user
                if let firebaseUser = FirebaseAuth.Auth.auth().currentUser {
                    currentUser = try await FirebaseService.shared.getUser(withId: firebaseUser.uid)
                }
                
                await MainActor.run {
                    isEditing = false
                }
            } catch {
                print("Error saving profile: \(error)")
                await MainActor.run {
                    isEditing = false
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
