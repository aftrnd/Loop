import SwiftUI
import FirebaseAuth
import os

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showLogoutConfirmation = false
    
    private static let logger = Logger(subsystem: "com.nejack.Loop", category: "SettingsView")
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                Form {
                    // MARK: - Account Section
                    Section {
                        NavigationLink {
                            Text("Account Settings")
                                .navigationTitle("Account")
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "person.circle")
                                    .foregroundColor(.primary)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .frame(width: 28)
                                
                                Text("Account")
                                    .font(.body)
                            }
                        }
                    } header: {
                        Text("Account")
                    }
                    
                    // MARK: - Preferences Section
                    Section {
                        NavigationLink {
                            AppearanceSettingsView()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "moon")
                                    .foregroundColor(.primary)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .frame(width: 28)
                                
                                Text("Appearance")
                                    .font(.body)
                            }
                        }
                        
                        NavigationLink {
                            Text("Chat Settings")
                                .navigationTitle("Chats")
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "message")
                                    .foregroundColor(.primary)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .frame(width: 28)
                                
                                Text("Chats")
                                    .font(.body)
                            }
                        }
                        
                        NavigationLink {
                            NotificationSettingsView()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "bell")
                                    .foregroundColor(.primary)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .frame(width: 28)
                                
                                Text("Notifications")
                                    .font(.body)
                            }
                        }
                    } header: {
                        Text("Preferences")
                    }
                    
                    // MARK: - Privacy & Security Section
                    Section {
                        NavigationLink {
                            PrivacySettingsView()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "lock")
                                    .foregroundColor(.primary)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .frame(width: 28)
                                
                                Text("Privacy")
                                    .font(.body)
                            }
                        }
                    } header: {
                        Text("Privacy & Security")
                    }
                    
                    // MARK: - Developer Section
                    #if DEBUG
                    Section {
                        NavigationLink {
                            DebugMenuView()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "hammer")
                                    .foregroundColor(.primary)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .frame(width: 28)
                                
                                Text("Developer Settings")
                                    .font(.body)
                            }
                        }
                    } header: {
                        Text("Developer")
                    }
                    #endif
                    
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
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.medium)
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
    }
    
    // MARK: - Methods
    
    private func logout() {
        do {
            try Auth.auth().signOut()
            dismiss()
        } catch {
            Self.logger.error("Sign out failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - Sub-Settings Views

struct AppearanceSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTheme = "System"
    
    var body: some View {
        Form {
            Section {
                Picker("Theme", selection: $selectedTheme) {
                    Text("System").tag("System")
                    Text("Light").tag("Light")
                    Text("Dark").tag("Dark")
                }
                .pickerStyle(.inline)
            } header: {
                Text("Theme")
            } footer: {
                Text("Choose how Loop looks. System matches your device's appearance.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var notificationsEnabled = true
    @State private var messagesEnabled = true
    @State private var likesEnabled = true
    @State private var commentsEnabled = true
    @State private var followersEnabled = true
    
    var body: some View {
        Form {
            Section {
                Toggle("Enable Notifications", isOn: $notificationsEnabled)
            } footer: {
                Text("Allow Loop to send you notifications")
            }
            
            Section {
                Toggle("Messages", isOn: $messagesEnabled)
                Toggle("Likes", isOn: $likesEnabled)
                Toggle("Comments", isOn: $commentsEnabled)
                Toggle("New Followers", isOn: $followersEnabled)
            } header: {
                Text("Notification Types")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var privateAccount = false
    
    var body: some View {
        Form {
            Section {
                Toggle("Private Account", isOn: $privateAccount)
            } footer: {
                Text("When your account is private, only people you approve can see your posts and followers.")
            }
            
            Section {
                NavigationLink("Blocked Users") {
                    Text("Blocked Users List")
                        .navigationTitle("Blocked Users")
                }
                NavigationLink("Muted Users") {
                    Text("Muted Users List")
                        .navigationTitle("Muted Users")
                }
            } header: {
                Text("Connections")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsView()
}
