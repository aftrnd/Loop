import SwiftUI

struct PhoneNumberInputView: View {
    @ObservedObject var viewModel: AuthenticationViewModel
    @FocusState private var isPhoneFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            headerSection
            
            inputSection
            
            actionSection
            
            Spacer()
        }
        .padding(.horizontal, AppConstants.UI.padding)
        .background(Color(.systemBackground))
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // App icon/logo area
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 120, height: 120)
                
                Color.clear
                    .frame(width: 120, height: 120)
                    .glassEffect(.regular, in: Circle())
                
                Image(systemName: "message.fill")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 8) {
                Text("Welcome to Loop")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Enter your phone number to get started")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var inputSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Phone Number")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    // Country code prefix
                    HStack(spacing: 4) {
                        Image(systemName: "flag")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        Text("+1")
                            .font(.body)
                            .foregroundColor(.primary)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        Color.clear
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                    )
                    
                    // Phone number input
                    TextField("(555) 123-4567", text: $viewModel.phoneNumber)
                        .keyboardType(.phonePad)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .focused($isPhoneFieldFocused)
                        .onChange(of: viewModel.phoneNumber) { _, newValue in
                            // Format phone number as user types
                            let digits = newValue.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
                            if digits.count <= 10 {
                                viewModel.phoneNumber = formatPhoneNumber(digits)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            Color.clear
                                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                        )
                }
            }
            
            if let errorMessage = viewModel.errorMessage {
                errorView(errorMessage)
            }
        }
    }
    
    private var actionSection: some View {
        VStack(spacing: 16) {
            Button(action: {
                // Validate phone number before sending
                let digits = viewModel.phoneNumber.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
                if digits.count == 10 {
                    viewModel.sendVerificationCode()
                } else {
                    viewModel.errorMessage = "Please enter a valid 10-digit phone number"
                }
            }) {
                HStack(spacing: 8) {
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.right")
                            .font(.body)
                            .fontWeight(.semibold)
                    }
                    
                    Text(viewModel.isLoading ? "Sending..." : "Continue")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                )
            }
            .disabled(viewModel.isLoading || viewModel.phoneNumber.isEmpty)
            .opacity(viewModel.isLoading || viewModel.phoneNumber.isEmpty ? 0.6 : 1.0)
            
            // Terms and privacy notice
            VStack(spacing: 4) {
                Text("By continuing, you agree to our")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    Button("Terms of Service") {
                        // Handle terms action
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    
                    Text("and")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Privacy Policy") {
                        // Handle privacy action
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
        }
    }
    
    private func errorView(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundColor(.orange)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Color.clear
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func formatPhoneNumber(_ digits: String) -> String {
        if digits.count >= 6 {
            let areaCode = String(digits.prefix(3))
            let firstPart = String(digits.dropFirst(3).prefix(3))
            let lastPart = String(digits.dropFirst(6))
            return "(\(areaCode)) \(firstPart)-\(lastPart)"
        } else if digits.count >= 3 {
            let areaCode = String(digits.prefix(3))
            let remaining = String(digits.dropFirst(3))
            return "(\(areaCode)) \(remaining)"
        } else {
            return digits
        }
    }
    
}

#Preview {
    PhoneNumberInputView(viewModel: AuthenticationViewModel())
}
