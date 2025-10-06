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
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var debugManager = DebugManager.shared
    
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
            contentView
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
    }
    
    private var contentView: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            chatListView
            fadeOverlays
        }
    }
    
    private var chatListView: some View {
        GeometryReader { scrollGeometry in
            List {
                scrollSentinel
                
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
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                }
                
                ForEach(Array(viewModel.recent.enumerated()), id: \.element.id) { index, chat in
                    ChatItemView(
                        chat: chat,
                        index: index,
                        totalCount: viewModel.recent.count,
                        isLastItem: index == viewModel.recent.count - 1,
                        isAtListStart: index == 0 && scrollOffset <= 32,
                        hasPinnedMessages: !viewModel.pinned.isEmpty,
                        scrollOffset: scrollOffset,
                        contentHeight: contentHeight,
                        scrollViewHeight: scrollViewHeight,
                        navigationPath: $navigationPath,
                        profileUserToShow: $profileUserToShow
                    )
                    .frame(height: 84)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
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
                            Task {
                                try? await viewModel.deleteChat(withId: chat.id)
                            }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .tint(.red)
                    }
                }
                
                // Bottom sentinel to track content height
                GeometryReader { geo in
                    Color.clear
                        .onChange(of: geo.frame(in: .named("chatScroll")).maxY) { _, newValue in
                            contentHeight = newValue
                        }
                }
                .frame(height: 0)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .listSectionSeparator(.hidden)
            .coordinateSpace(name: "chatScroll")
            .scrollIndicators(.hidden)
            .contentMargins(.top, -32)
            .refreshable {
                await refreshChats()
            }
            .onAppear {
                scrollViewHeight = scrollGeometry.size.height
            }
            .onChange(of: scrollGeometry.size.height) { _, newValue in
                scrollViewHeight = newValue
            }
        }
    }
    
    private var scrollSentinel: some View {
        GeometryReader { geo in
            let topMinY = geo.frame(in: .named("chatScroll")).minY
            Color.clear
                .onChange(of: topMinY) { _, newValue in
                    let offset = max(0, -newValue)
                    scrollOffset = offset
                    topDistance = offset
                }
        }
        .frame(height: 0)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
    }
    
    
    private var fadeOverlays: some View {
        VStack {
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.systemBackground).opacity(0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 40)
            .allowsHitTesting(false)
            
            Spacer()
            
            LinearGradient(
                colors: [
                    Color(.systemBackground).opacity(0),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 40)
            .allowsHitTesting(false)
        }
        .ignoresSafeArea(.container, edges: .vertical)
    }
    
    private var toolbarContent: some View {
        Text("Messages")
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
        VStack(spacing: 8) {
            ZStack {
                if let avatarURLString = chat.otherParticipantAvatarURL, let avatarURL = URL(string: avatarURLString) {
                    // Show actual user avatar
                    CachedAsyncImage(url: avatarURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 90, height: 90)
                            .clipShape(Circle())
                    } placeholder: {
                        // Placeholder while loading
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 90, height: 90)
                            .overlay {
                                ProgressView()
                            }
                    }
                } else {
                    // Default avatar with initials
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 90, height: 90)

                    Color.clear
                        .frame(width: 90, height: 90)
                        .glassEffect(.regular, in: Circle())

                    Text(String(chat.displayTitle.prefix(1)).uppercased())
                        .font(.largeTitle)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
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
                } else if chat.unreadCount > 0 {
                    Circle()
                        .fill(colorScheme == .light ? Color.red : Color.blue)
                        .frame(width: 30, height: 30)
                        .overlay {
                            Text("\(min(chat.unreadCount, 99))")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        .offset(x: 8, y: -8)
                }
            }
            
            Text(chat.displayTitle)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: 105)
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

struct ChatItemView: View {
    let chat: Chat
    let index: Int
    let totalCount: Int
    let isLastItem: Bool
    let isAtListStart: Bool
    let hasPinnedMessages: Bool
    let scrollOffset: CGFloat
    let contentHeight: CGFloat
    let scrollViewHeight: CGFloat
    @Binding var navigationPath: NavigationPath
    @Binding var profileUserToShow: ProfileUser?
    
    var body: some View {
        GeometryReader { geo in
            createChatItem(geo: geo)
        }
    }
    
    private func createChatItem(geo: GeometryProxy) -> some View {
        let midY = geo.frame(in: .global).midY
        let screenMid = UIScreen.main.bounds.midY
        let screen = UIScreen.main.bounds
        let edgeZone: CGFloat = max(120, screen.height * 0.18)
        
        // Calculate distance factors
        let distanceFromTop = max(0, midY - screen.minY)
        let distanceFromBottom = max(0, screen.maxY - midY)
        let topFactor = max(0, 1 - distanceFromTop / edgeZone)
        let bottomFactor = max(0, 1 - distanceFromBottom / edgeZone)
        
        let rotationSign: CGFloat = topFactor >= bottomFactor ? 1 : -1
        
        // Better scroll position detection
        let itemFrame = geo.frame(in: .named("chatScroll"))
        
        // Calculate if we're at the absolute bottom by checking if the last item is fully visible
        let isAtAbsoluteBottom = isLastItem && itemFrame.maxY <= scrollViewHeight + 10 // 10px tolerance
        let isAtAbsoluteTop = scrollOffset <= 10 // Very close to top
        
        // Effect gates - disable at absolute boundaries
        var topEffectGate: CGFloat = 1
        var bottomEffectGate: CGFloat = 1
        
        // At the very top of the list
        // When there are no pinned messages, the first item should still get parallax effect
        // because it's not at the visual "top" of the interface
        if isAtListStart && isAtAbsoluteTop && !hasPinnedMessages {
            // Don't disable top effect when there are no pinned messages
            topEffectGate = 1
        } else if isAtListStart && isAtAbsoluteTop {
            // Only disable when there are pinned messages and we're at the very top
            topEffectGate = 0
        }
        
        // At the very bottom of the list - completely disable effect when at bottom
        if isAtAbsoluteBottom {
            bottomEffectGate = 0
        }
        
        // Apply effects with smoother transitions
        let effectiveTop = topFactor * topEffectGate
        let effectiveBottom = bottomFactor * bottomEffectGate
        let effective = min(1, max(effectiveTop, effectiveBottom))
        
        // Calculate transforms
        let scale = 1 - (0.04 * effective)
        let rotation = Angle(degrees: rotationSign * 4 * effective)
        let opacity = 0.9 + (1 - effective) * 0.1
        let blur = 4 * effective
        let parallaxDistance = (midY - screenMid) / 24
        let parallax = parallaxDistance * effective
        
        return ChatRowView(chat: chat,             onAvatarTap: {
                // Open the other user's profile for 1:1 chats
                if let otherUserId = chat.otherParticipantId, !chat.isGroupChat {
                    print("👆 Avatar tapped - opening profile for user: \(otherUserId)")
                    profileUserToShow = ProfileUser(userId: otherUserId)
                    print("   profileUserToShow set to: \(profileUserToShow?.userId ?? "nil")")
                }
            })
            .frame(height: 84)
            .frame(maxWidth: .infinity)
            .compositingGroup()
            .listRowSeparator(.hidden)
            .contentShape(RoundedRectangle(cornerRadius: 18))
            .onTapGesture {
                navigationPath.append(ChatsRoute.conversation(chat))
            }
        .overlay(alignment: .bottom) {
            if index < totalCount - 1 {
                Rectangle()
                    .fill(Color(.separator))
                    .frame(height: 1.15)
                    .padding(.leading, 82)
                    .padding(.trailing, 16)
            }
        }
        .compositingGroup()
        .scaleEffect(scale)
        .rotation3DEffect(rotation, axis: (x: 1, y: 0, z: 0), anchor: .center)
        .opacity(opacity)
        .blur(radius: blur)
        .offset(y: parallax)
    }
}

// Helper struct for presenting user profiles
struct ProfileUser: Identifiable {
    let id: String
    let userId: String
    
    init(userId: String) {
        self.id = userId
        self.userId = userId
    }
}

#Preview {
    NavigationStack {
        ChatsListView()
    }
}


