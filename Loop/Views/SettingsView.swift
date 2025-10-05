import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @State private var currentUser: User?
    @State private var showDebugSettings = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            // Account Section
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
            } header: {
                Text("Account")
            }

            // Developer Section
            Section {
                Button {
                    showDebugSettings = true
                } label: {
                    HStack {
                        Image(systemName: "hammer.fill")
                            .foregroundColor(.orange)
                            .frame(width: 30)
                        
                        Text("Developer Settings")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Developer")
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Settings")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Color.clear
                            .glassEffect(.regular, in: Capsule())
                    )
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(isPresented: $showDebugSettings) {
            DebugMenuView()
        }
        .onAppear {
            loadCurrentUser()
        }
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
                }
            } catch {
                print("Error loading user: \(error)")
            }
        }
    }
}

#Preview {
    SettingsView()
}
