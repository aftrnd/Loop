import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Int = 1 // Start with Messages tab
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            HomeView()
                .tabItem {
                    Image(systemName: "house")
                    Text("Home")
                }
                .tag(0)
            
            // Messages Tab
            ChatsListView()
                .tabItem {
                    Image(systemName: "message")
                    Text("Messages")
                }
                .tag(1)
            
            // Groups Tab
            GroupsView()
                .tabItem {
                    Image(systemName: "person.3")
                    Text("Groups")
                }
                .tag(2)
            
            // Notes Tab
            NotesView()
                .tabItem {
                    Image(systemName: "note.text")
                    Text("Notes")
                }
                .tag(3)
        }
    }
}

#Preview {
    MainTabView()
}
