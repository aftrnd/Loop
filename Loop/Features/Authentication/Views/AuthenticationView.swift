import SwiftUI

struct AuthenticationView: View {
    @StateObject private var viewModel = AuthenticationViewModel()
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                switch viewModel.authState {
                case .loading:
                    loadingView
                case .unauthenticated:
                    PhoneNumberInputView(viewModel: viewModel)
                        .navigationDestination(for: AuthenticationRoute.self) { route in
                            switch route {
                            case .phoneNumberInput:
                                PhoneNumberInputView(viewModel: viewModel)
                            case .otpVerification:
                                OTPVerificationView(viewModel: viewModel)
                            }
                        }
                case .authenticated(_):
                    // User is authenticated, show main app
                    ContentView()
                case .error(let message):
                    errorView(message)
                }
            }
            .animation(.easeInOut(duration: AppConstants.Animation.defaultDuration), value: viewModel.authState.id)
            .transaction { transaction in
                // Reduce animation overhead for loading states
                if case .loading = viewModel.authState {
                    transaction.animation = .linear(duration: 0.1)
                }
            }
        }
        .debugMenu() // Add debug menu support
        .onChange(of: viewModel.verificationID) { _, verificationID in
            // Debounce navigation to prevent multiple frame updates
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if verificationID != nil && navigationPath.isEmpty {
                    navigationPath.append(AuthenticationRoute.otpVerification)
                }
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 120, height: 120)
                
                Color.clear
                    .frame(width: 120, height: 120)
                    .glassEffect(.regular, in: Circle())
                
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.primary)
            }
            
            VStack(spacing: 8) {
                Text("Loading...")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Setting up your account")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, AppConstants.UI.padding)
        .background(Color(.systemBackground))
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)
                
                VStack(spacing: 8) {
                    Text("Something went wrong")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(message)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            Button("Try Again") {
                viewModel.checkAuthState()
            }
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            )
            
            Spacer()
        }
        .padding(.horizontal, AppConstants.UI.padding)
        .background(Color(.systemBackground))
    }
}

#Preview {
    AuthenticationView()
}
