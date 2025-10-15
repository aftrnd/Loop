import SwiftUI
import UIKit

struct ChatsListView: View {
    @State private var viewModel = ChatsListViewModel()
    @State private var topDistance: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var scrollViewHeight: CGFloat = 0
    @State private var navigationPath = NavigationPath()
    @State private var showNewMessage = false
    @State private var showProfile = false
    @State private var profileUserToShow: ProfileUser?
    @State private var chatToDelete: Chat?
    @State private var showDeleteConfirmation = false
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var debugManager = DebugManager.shared
    @StateObject private var notificationManager = NotificationNavigationManager.shared
    
    var body: some View {
        mainView
    }
    
    // MARK: - Methods
    
    private func refreshChats() async {
        print("🔄 Pull-to-refresh triggered...")
        await viewModel.refreshChats()
        print("✅ Pull-to-refresh completed")
    }
    
    private var mainView: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                chatListView
            }
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: {
                            showNewMessage = true
                        }) {
                            Image(systemName: "square.and.pencil")
                                .font(.body)
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.plain)
                    }

                    ToolbarItem(placement: .principal) {
                        toolbarContent
                    }
                    
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            // Haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            
                            showProfile = true
                        }) {
                            Image(systemName: "person")
                                .font(.body)
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.plain)
                    }

                }
                .toolbarBackground(.hidden, for: .navigationBar)
                .navigationDestination(for: ChatsRoute.self) { route in
                    switch route {
                    case .conversation(let chat):
                        ConversationView(chat: chat)
                    }
                }
        }
        .sheet(isPresented: $showNewMessage) {
            NewMessageView(chatsViewModel: viewModel)
        }
        .sheet(isPresented: $showProfile) {
            ProfileView()
        }
        .sheet(item: $profileUserToShow) { profileUser in
            ProfileView(userId: profileUser.userId)
        }
        .sheet(isPresented: $debugManager.isDebugMenuVisible) {
            DebugMenuView()
        }
        .onChange(of: notificationManager.chatToOpen) { _, chatId in
            guard let chatId = chatId else { return }
            handleNotificationNavigation(chatId: chatId)
        }
        .alert("Delete Conversation?", isPresented: $showDeleteConfirmation, presenting: chatToDelete) { chat in
            Button("Delete", role: .destructive) {
                Task {
                    try? await viewModel.deleteChat(withId: chat.id)
                }
            }
            Button("Cancel", role: .cancel) {
                chatToDelete = nil
            }
        } message: { chat in
            Text("This will remove the conversation from your list. Your messages will still be there if you message \(chat.displayTitle) again.\n\nThis won't delete the conversation for the other person.")
        }
    }
    
    private func handleNotificationNavigation(chatId: String) {
        // Find the chat in our list
        let allChats = viewModel.pinned + viewModel.recent
        guard let chat = allChats.first(where: { $0.id.uuidString == chatId }) else {
            print("⚠️ Chat not found for notification: \(chatId)")
            notificationManager.clearNavigation()
            return
        }
        
        print("📱 Navigating to chat: \(chat.displayTitle)")
        navigationPath.append(ChatsRoute.conversation(chat))
        notificationManager.clearNavigation()
    }
    
    
    private var chatListView: some View {
        GeometryReader { scrollGeometry in
            List {
                // Scroll sentinel
                GeometryReader { geo in
                    let topMinY = geo.frame(in: .named("loopScroll")).minY
                    Color.clear
                        .onChange(of: topMinY) { _, newValue in
                            let offset = max(0, -newValue)
                            scrollOffset = offset
                        }
                }
                .frame(height: 0)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                // Show loading indicator while initial data loads
                if viewModel.isLoadingInitialData {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Loading chats...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 40)
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                
                if !viewModel.pinned.isEmpty {
                    PinnedMessagesView(
                        pinnedChats: viewModel.pinned,
                        colorScheme: colorScheme,
                        navigationPath: $navigationPath,
                        viewModel: viewModel,
                        profileUserToShow: $profileUserToShow
                    )
                    .padding(.top, 0) // No top padding for pinned items
                    .padding(.bottom, 8)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
                }
                
                ForEach(Array(viewModel.recent.enumerated()), id: \.element.id) { index, chat in
                    ChatRowView(chat: chat, onAvatarTap: {
                        // Open the other user's profile for 1:1 chats
                        if let otherUserId = chat.otherParticipantId, !chat.isGroupChat {
                            print("👆 Avatar tapped - opening profile for user: \(otherUserId)")
                            profileUserToShow = ProfileUser(userId: otherUserId)
                        }
                    })
                    .overlay(alignment: .bottom) {
                        if index < viewModel.recent.count - 1 {
                            Rectangle()
                                .fill(CardLayoutConstants.dividerColor)
                                .frame(maxWidth: .infinity)
                                .frame(height: CardLayoutConstants.dividerHeight)
                                .padding(.leading, 82)
                                .padding(.trailing, 10)
                        }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 18))
                    .onTapGesture {
                        navigationPath.append(ChatsRoute.conversation(chat))
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            viewModel.pinChat(chat)
                        } label: {
                            Image(systemName: "pin.fill")
                        }
                        .tint(.yellow)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            chatToDelete = chat
                            showDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .tint(.red)
                    }
                }
            
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .listSectionSeparator(.hidden)
            .coordinateSpace(name: "loopScroll")
            .scrollIndicators(.hidden)
            .contentMargins(.top, AppConstants.Layout.listContentTopMargin)
            .refreshable {
                await refreshChats()
            }
        }
    }
    
    
    private var toolbarContent: some View {
        Text("Messages")
            .font(.headline)
            .fontWeight(.semibold)
    }
}

struct PinnedMessagesView: View {
    let pinnedChats: [Chat]
    let colorScheme: ColorScheme
    @Binding var navigationPath: NavigationPath
    let viewModel: ChatsListViewModel
    @State private var longPressedChat: Chat?
    @Binding var profileUserToShow: ProfileUser?
    
    var body: some View {
        VStack(spacing: 16) {
            // First row of 3
            HStack(spacing: 0) {
                ForEach(Array(pinnedChats.prefix(3).enumerated()), id: \.element.id) { index, chat in
                    pinnedChatItem(chat: chat, isLongPressed: longPressedChat?.id == chat.id, profileUserToShow: $profileUserToShow)
                        .frame(maxWidth: .infinity)
                        .onLongPressGesture {
                            withAnimation {
                                longPressedChat = longPressedChat?.id == chat.id ? nil : chat
                            }
                        }
                }
            }
            
            // Second row of 3 if we have more than 3 pinned
            if pinnedChats.count > 3 {
                HStack(spacing: 0) {
                    ForEach(Array(pinnedChats.dropFirst(3).prefix(3).enumerated()), id: \.element.id) { index, chat in
                        pinnedChatItem(chat: chat, isLongPressed: longPressedChat?.id == chat.id, profileUserToShow: $profileUserToShow)
                            .frame(maxWidth: .infinity)
                            .onLongPressGesture {
                                withAnimation {
                                    longPressedChat = longPressedChat?.id == chat.id ? nil : chat
                                }
                            }
                    }
                }
            }
        }
        .background {
            // Background tap to dismiss long press (behind content)
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation {
                        longPressedChat = nil
                    }
                }
                .zIndex(-1)
        }
    }
    
    private func pinnedChatItem(chat: Chat, isLongPressed: Bool, profileUserToShow: Binding<ProfileUser?>) -> some View {
        let avatarSize: CGFloat = 90
        let dotSize: CGFloat = 10
        
        return VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Unread indicator dot - positioned to the left of avatar
                    if chat.unreadCount > 0 && !isLongPressed {
                        let containerWidth = geometry.size.width
                        let leadingSpace = (containerWidth - avatarSize) / 2
                        let dotOffset = -(leadingSpace / 2 + dotSize / 2)
                        
                        Circle()
                            .fill(Color.blue)
                            .frame(width: dotSize, height: dotSize)
                            .offset(x: dotOffset) // Centered between edge and avatar
                    }
                    
                    ZStack {
                        if let avatarURLString = chat.otherParticipantAvatarURL, let avatarURL = URL(string: avatarURLString) {
                            // Show actual user avatar
                            CachedAsyncImage(url: avatarURL) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: avatarSize, height: avatarSize)
                                    .clipShape(Circle())
                            } placeholder: {
                                // Placeholder while loading
                                Circle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: avatarSize, height: avatarSize)
                                    .overlay {
                                        ProgressView()
                                    }
                            }
                        } else {
                            // Default avatar with initials
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: avatarSize, height: avatarSize)

                            Color.clear
                                .frame(width: avatarSize, height: avatarSize)
                                .glassEffect(.regular, in: Circle())

                            Text(String(chat.displayTitle.prefix(1)).uppercased())
                                .font(.largeTitle)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                    }
                    .frame(width: geometry.size.width, height: avatarSize)
                    .overlay(alignment: .topTrailing) {
                        if isLongPressed {
                            Circle()
                                .fill(Color.clear)
                                .frame(width: 30, height: 30)
                                .overlay {
                                    Image(systemName: "minus")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.primary)
                                }
                                .background(
                                    Circle()
                                        .fill(Color(.systemBackground))
                                        .glassEffect(.regular, in: Circle())
                                )
                                .onTapGesture {
                                    withAnimation {
                                        viewModel.unpinChat(chat)
                                        longPressedChat = nil
                                    }
                                }
                                .offset(x: 8, y: -8)
                        }
                    }
                    .onTapGesture(count: 1) {
                        // Avatar tap - show profile for 1:1 chats
                        if !chat.isGroupChat, let otherUserId = chat.otherParticipantId {
                            print("👆 Pinned avatar tapped - opening profile for user: \(otherUserId)")
                            profileUserToShow.wrappedValue = ProfileUser(userId: otherUserId)
                            print("   profileUserToShow set to: \(profileUserToShow.wrappedValue?.userId ?? "nil")")
                        }
                    }
                }
            }
            .frame(height: avatarSize)
            
            Text(chat.displayTitle)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: 105)
            
            // Badge if user has one (only for 1:1 chats)
            if !chat.isGroupChat, let badgeType = chat.otherParticipantBadgeType {
                Image(systemName: badgeType.iconName)
                    .font(.system(size: 10))
                    .foregroundColor(badgeType.color)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if longPressedChat?.id == chat.id {
                // If long pressed, tapping should dismiss the long press state
                withAnimation {
                    longPressedChat = nil
                }
            } else {
                // Normal tap - navigate to conversation
                navigationPath.append(ChatsRoute.conversation(chat))
            }
        }
    }
}



#Preview {
    NavigationStack {
        ChatsListView()
    }
}


