import SwiftUI

struct MainTabView: View {
    @State private var searchText = ""
    @State private var chatsViewModel = ChatsListViewModel()
    @State private var selectedTab = "Home" // Default to Home tab
    @AppStorage("showLayoutGrid") private var showLayoutGrid = false
    /// Touching the router here starts its notification observer no later than the tab view's creation
    private let notificationNavigation = NotificationNavigationManager.shared
    
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
        ZStack {
            TabView(selection: $selectedTab) {
                // Home Tab
                Tab("Home", systemImage: "house", value: "Home") {
                    HomeView()
                }
                
                // Messages Tab
                Tab("Messages", systemImage: "message", value: "Messages") {
                    ChatsListView()
                }
                .badge(chatsViewModel.totalUnreadCount)
                
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
            // Ties search activation to the search tab. On iOS 27 the search tab only gets its own
            // button, apart from the other tabs, with this set (checked in the iOS 27.0 simulator).
            .tabViewSearchActivation(.searchTabSelection)
            .environment(chatsViewModel)
            
            #if DEBUG
            if showLayoutGrid {
                LayoutGridOverlay()
                    .zIndex(1000)
            }
            #endif
        }
        .task {
            // One chat listener for the whole app: it feeds the Messages tab, its badge and search
            chatsViewModel.start()
        }
        .onChange(of: notificationNavigation.pendingChatID, initial: true) { _, chatID in
            // ChatsListView opens the chat itself once its list has loaded
            if chatID != nil {
                selectedTab = "Messages"
            }
        }
    }
}

#Preview {
    MainTabView()
}
