import SwiftUI

struct PhoneNumberInputView: View {
    @ObservedObject var viewModel: AuthenticationViewModel
    @FocusState private var isPhoneFieldFocused: Bool
    @State private var isFormattingInProgress = false
    
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
        .onTapGesture {
            // Dismiss keyboard when tapping outside
            isPhoneFieldFocused = false
        }
        .keyboardAdaptive() // Custom keyboard handling
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
                    .lightGlassEffect(.regular, in: Circle())
                
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
                            .lightGlassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                    )
                    
                    // Phone number input
                    TextField("(555) 123-4567", text: $viewModel.phoneNumber)
                        .keyboardType(.phonePad)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .focused($isPhoneFieldFocused)
                        .onChange(of: viewModel.phoneNumber) { _, newValue in
                            // Immediate formatting without debouncing to prevent flashing
                            formatPhoneNumberOptimized(newValue)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            Color.clear
                                .lightGlassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
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
                // Optimized validation - extract digits without regex
                let digits = String(viewModel.phoneNumber.compactMap { $0.isNumber ? $0 : nil })
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
                .lightGlassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    // Optimized phone number formatting without debouncing
    private func formatPhoneNumberOptimized(_ newValue: String) {
        // Prevent recursive updates
        guard !isFormattingInProgress else { return }
        isFormattingInProgress = true
        
        // Extract digits only (optimized character filtering)
        let digits = String(newValue.compactMap { $0.isNumber ? $0 : nil })
        
        // Limit to 10 digits max
        guard digits.count <= 10 else {
            isFormattingInProgress = false
            return
        }
        
        // Format the digits
        let formatted = formatPhoneNumber(digits)
        
        // Only update if different to prevent infinite loops
        if formatted != viewModel.phoneNumber {
            DispatchQueue.main.async {
                self.viewModel.phoneNumber = formatted
                self.isFormattingInProgress = false
            }
        } else {
            isFormattingInProgress = false
        }
    }
    
    private func formatPhoneNumber(_ digits: String) -> String {
        switch digits.count {
        case 0...3:
            return digits
        case 4...6:
            let areaCode = String(digits.prefix(3))
            let remaining = String(digits.dropFirst(3))
            return "(\(areaCode)) \(remaining)"
        case 7...10:
            let areaCode = String(digits.prefix(3))
            let firstPart = String(digits.dropFirst(3).prefix(3))
            let lastPart = String(digits.dropFirst(6))
            return "(\(areaCode)) \(firstPart)-\(lastPart)"
        default:
            return digits
        }
    }
    
}

// MARK: - Keyboard Adaptive Modifier
struct KeyboardAdaptiveModifier: ViewModifier {
    @State private var keyboardHeight: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboardHeight)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
                    let keyboardRectangle = keyboardFrame.cgRectValue
                    let keyboardHeight = keyboardRectangle.height
                    
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.keyboardHeight = keyboardHeight * 0.1 // Minimal adjustment
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.keyboardHeight = 0
                }
            }
    }
}

extension View {
    func keyboardAdaptive() -> some View {
        self.modifier(KeyboardAdaptiveModifier())
    }
}

#Preview {
    PhoneNumberInputView(viewModel: AuthenticationViewModel())
}
