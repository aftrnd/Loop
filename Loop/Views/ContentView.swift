import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @State private var isAuthenticated = false
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                // Loading state
                VStack {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading...")
                        .padding(.top, 8)
                        .foregroundColor(.secondary)
                }
            } else if isAuthenticated {
                MainTabView()
            } else {
                AuthenticationView()
            }
        }
        .onAppear {
            checkAuthenticationState()
        }
        .onReceive(NotificationCenter.default.publisher(for: .AuthStateDidChange)) { _ in
            checkAuthenticationState()
        }
    }
    
    private func checkAuthenticationState() {
        if let _ = Auth.auth().currentUser {
            isAuthenticated = true
        } else {
            isAuthenticated = false
        }
        isLoading = false
    }
}

#Preview {
    ContentView()
}
