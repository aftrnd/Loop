import SwiftUI

struct NewMessageView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var phoneNumber = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @FocusState private var isPhoneFieldFocused: Bool
    let chatsViewModel: ChatsListViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("New Message")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Enter a phone number to start a conversation")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)

                // Phone number input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Phone Number")
                        .font(.headline)
                        .foregroundColor(.primary)

                    TextField("Enter phone number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .focused($isPhoneFieldFocused)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemBackground))
                                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isPhoneFieldFocused ? Color.blue : Color(.separator), lineWidth: 2)
                        )
                }
                .padding(.horizontal)

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    Button(action: {
                        startNewConversation()
                    }) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Start Conversation")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(phoneNumber.isEmpty ? Color(.systemGray4) : Color.blue)
                    )
                    .foregroundColor(.white)
                    .disabled(phoneNumber.isEmpty || isLoading)

                    Button(action: {
                        dismiss()
                    }) {
                        Text("Cancel")
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isPhoneFieldFocused = true
                }
            }
        }
    }

    private func startNewConversation() {
        // Basic phone number validation
        let cleanedNumber = phoneNumber.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)

        guard !cleanedNumber.isEmpty else {
            errorMessage = "Please enter a phone number"
            return
        }

        guard cleanedNumber.count >= 10 else {
            errorMessage = "Please enter a valid phone number"
            return
        }

        errorMessage = ""
        isLoading = true

        Task {
            do {
                // Generate display name for the user
                let displayName = UserNameGenerator.generateDisplayName(for: cleanedNumber)

                // Create chat with Firebase
                try await chatsViewModel.createChat(with: cleanedNumber, displayName: displayName)

                isLoading = false
                dismiss()
            } catch {
                isLoading = false
                errorMessage = "Failed to create conversation. Please try again."
                print("Error creating chat: \(error)")
            }
        }
    }
}

#Preview {
    NewMessageView(chatsViewModel: ChatsListViewModel())
}
