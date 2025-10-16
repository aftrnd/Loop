import SwiftUI

struct MainTabView: View {
    @State private var searchText = ""
    @State private var chatsViewModel = ChatsListViewModel()
    @State private var selectedTab = "Home" // Default to Home tab
    
    var filteredChats: [Chat] {
        if searchText.isEmpty {
            return []
        }
        return (chatsViewModel.recent + chatsViewModel.pinned).filter { chat in
            chat.displayTitle.localizedCaseInsensitiveContains(searchText) ||
            chat.lastMessagePreview.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            Tab("Home", systemImage: "house", value: "Home") {
                HomeView()
            }
            
            // Home2 Tab - New modular architecture
            Tab("Home v2", systemImage: "house.fill", value: "Home2") {
                Home2View()
            }
            
            // Messages Tab
            Tab("Messages", systemImage: "message", value: "Messages") {
                ChatsListView()
            }
            .badge(chatsViewModel.totalUnreadCount > 0 ? chatsViewModel.totalUnreadCount : 0)
            
            // Search Tab - Uses .search role for native iOS 26 behavior
            Tab("Search", systemImage: "magnifyingglass", value: "Search", role: .search) {
                NavigationStack {
                    VStack {
                        if searchText.isEmpty {
                            // Empty state
                            VStack(spacing: 20) {
                                Spacer()
                                
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 60))
                                    .foregroundColor(.secondary)
                                
                                Text("Search")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                
                                Text("Search your messages and conversations")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                
                                Spacer()
                            }
                        } else if filteredChats.isEmpty {
                            // No results state
                            VStack(spacing: 16) {
                                Spacer()
                                
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                                
                                Text("No Results")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                
                                Text("No conversations found for \"\(searchText)\"")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                
                                Spacer()
                            }
                        } else {
                            // Search results
                            List {
                                ForEach(filteredChats) { chat in
                                    ChatRowView(chat: chat, onAvatarTap: nil)
                                        .listRowSeparator(.hidden)
                                        .listRowBackground(Color.clear)
                                }
                            }
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                        }
                    }
                    .navigationTitle("Search")
                    .navigationBarTitleDisplayMode(.inline)
                }
                .searchable(text: $searchText, prompt: "Search messages")
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .environment(\.horizontalSizeClass, .compact)
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}

#Preview {
    MainTabView()
}
