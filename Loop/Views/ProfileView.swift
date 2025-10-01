import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @State private var currentUser: User?
    @State private var isLoading = true
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Profile Header Section (Discord-style)
                    VStack(spacing: 16) {
                        // Avatar Circle
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: 140, height: 140)

                            Color.clear
                                .frame(width: 140, height: 140)
                                .glassEffect(.regular, in: Circle())

                            // User initials or avatar
                            Text(userInitials)
                                .font(.system(size: 50, weight: .medium))
                                .foregroundColor(.primary)
                        }

                        // User display name (required)
                        if let displayName = currentUser?.displayName {
                            Text(displayName)
                                .font(.title)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        } else {
                            Text("Display Name")
                                .font(.title)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                        }

                        // Username section (with @ prefix)
                        if let username = currentUser?.username {
                            Text("@\(username)")
                                .font(.title3)
                                .foregroundColor(.blue)
                        } else {
                            Text("@username")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Phone Number Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Account")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        HStack(spacing: 12) {
                            // Phone icon
                            Image(systemName: "phone.fill")
                                .foregroundColor(.green)
                                .frame(width: 24, height: 24)

                            // Phone number
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Phone Number")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Text(formattedPhoneNumber)
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }

                            Spacer()

                            // Verified checkmark
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title3)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(
                            Color.clear
                                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                        )
                    }

                    // Bio Section (placeholder for now)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("About")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        if let bio = currentUser?.bio, !bio.isEmpty {
                            Text(bio)
                                .font(.body)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(
                                    Color.clear
                                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                                )
                        } else {
                            Text("Add a bio to tell people more about yourself...")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .italic()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(
                                    Color.clear
                                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                                )
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
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

                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .background(Color(.systemBackground))
            .onAppear {
                loadCurrentUser()
            }
            .navigationDestination(isPresented: $showSettings) {
                SettingsView()
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
        isLoading = true

        Task {
            do {
                if let user = FirebaseService.shared.getCurrentUser() {
                    currentUser = user
                } else {
                    // Try to create user if they don't exist in Firestore
                    if let firebaseUser = FirebaseAuth.Auth.auth().currentUser {
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
}

#Preview {
    ProfileView()
}
