import SwiftUI

struct GroupsView: View {
    var body: some View {
        NavigationView {
            VStack {
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "person.3")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    
                    Text("Groups")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Manage your group conversations")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
            }
            .navigationTitle("Groups")
        }
    }
}

#Preview {
    GroupsView()
}
