import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationView {
            VStack {
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "house")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    
                    Text("Home")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Welcome to your home screen")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
            }
            .navigationTitle("Home")
        }
    }
}

#Preview {
    HomeView()
}
