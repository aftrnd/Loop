import SwiftUI

struct OTPVerificationView: View {
    @ObservedObject var viewModel: AuthenticationViewModel
    @FocusState private var isOTPFieldFocused: Bool
    @State private var timeRemaining = 60
    @State private var timer: Timer?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            headerSection
            
            verificationSection
            
            actionSection
            
            Spacer()
        }
        .padding(.horizontal, AppConstants.UI.padding)
        .background(Color(.systemBackground))
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Back button
            HStack {
                Button(action: {
                    viewModel.resetVerification()
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .padding(12)
                        .background(
                            Color.clear
                                .glassEffect(.regular, in: Circle())
                        )
                }
                
                Spacer()
            }
            
            // Verification icon
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 100, height: 100)
                
                Color.clear
                    .frame(width: 100, height: 100)
                    .glassEffect(.regular, in: Circle())
                
                Image(systemName: "message.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 8) {
                Text("Verify Your Number")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("We sent a verification code to")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Text(viewModel.phoneNumber)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
        }
    }
    
    private var verificationSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Verification Code")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                TextField("123456", text: $viewModel.verificationCode)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.plain)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .focused($isOTPFieldFocused)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(
                        Color.clear
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                    )
            }
            
            if let errorMessage = viewModel.errorMessage {
                errorView(errorMessage)
            }
            
            // Resend code section
            VStack(spacing: 8) {
                if timeRemaining > 0 {
                    Text("Resend code in \(timeRemaining)s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Button("Resend Code") {
                        viewModel.sendVerificationCode()
                        timeRemaining = 60
                        startTimer()
                    }
                    .font(.body)
                    .foregroundColor(.blue)
                    .padding(.vertical, 8)
                }
            }
        }
    }
    
    private var actionSection: some View {
        VStack(spacing: 16) {
            Button(action: {
                viewModel.verifyCode()
            }) {
                HStack(spacing: 8) {
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.body)
                            .fontWeight(.semibold)
                    }
                    
                    Text(viewModel.isLoading ? "Verifying..." : "Verify")
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
            .disabled(viewModel.isLoading || viewModel.verificationCode.isEmpty)
            .opacity(viewModel.isLoading || viewModel.verificationCode.isEmpty ? 0.6 : 1.0)
            
            // Help text
            VStack(spacing: 4) {
                Text("Didn't receive the code?")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button("Check your messages") {
                    // Handle help action
                }
                .font(.caption)
                .foregroundColor(.blue)
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
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

#Preview {
    @Previewable @State var viewModel = AuthenticationViewModel()
    OTPVerificationView(viewModel: viewModel)
}
