import SwiftUI

struct GroupsView: View {
    var body: some View {
        NavigationStack {
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
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Groups")
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
        }
    }
}

#Preview {
    GroupsView()
}
