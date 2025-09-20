import SwiftUI
import UIKit

struct ChatsListView: View {
    @StateObject private var viewModel = ChatsListViewModel()
    @State private var topDistance: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var scrollViewHeight: CGFloat = 0
    @State private var navigationPath = NavigationPath()
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var debugManager = DebugManager.shared
    
    var body: some View {
        mainView
    }
    
    private var mainView: some View {
        NavigationStack(path: $navigationPath) {
            contentView
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        toolbarContent
                    }
                    
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            DebugManager.shared.showDebugMenu()
                        }) {
                            Image(systemName: "gear")
                        }
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
                
                if !viewModel.pinned.isEmpty {
                    PinnedMessagesView(
                        pinnedChats: viewModel.pinned,
                        colorScheme: colorScheme,
                        navigationPath: $navigationPath
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
                        isAtListStart: index == 0 && viewModel.pinned.isEmpty,
                        scrollOffset: scrollOffset,
                        contentHeight: contentHeight,
                        scrollViewHeight: scrollViewHeight,
                        navigationPath: $navigationPath
                    )
                    .frame(height: 84)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            viewModel.deleteRecentChats(at: IndexSet([index]))
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
    
    var body: some View {
        VStack(spacing: 16) {
            // First row of 3
            HStack(spacing: 0) {
                ForEach(Array(pinnedChats.prefix(3).enumerated()), id: \.element.id) { index, chat in
                    pinnedChatItem(chat: chat)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Second row of 3 if we have more than 3 pinned
            if pinnedChats.count > 3 {
                HStack(spacing: 0) {
                    ForEach(Array(pinnedChats.dropFirst(3).prefix(3).enumerated()), id: \.element.id) { index, chat in
                        pinnedChatItem(chat: chat)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
    
    private func pinnedChatItem(chat: Chat) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 90, height: 90)
                
                Color.clear
                    .frame(width: 90, height: 90)
                    .glassEffect(.regular, in: Circle())
                
                Text(String(chat.title.prefix(1)).uppercased())
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            .overlay(alignment: .topTrailing) {
                if chat.unreadCount > 0 {
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
            
            Text(chat.title)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: 105)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            navigationPath.append(ChatsRoute.conversation(chat))
        }
    }
}

struct ChatItemView: View {
    let chat: Chat
    let index: Int
    let totalCount: Int
    let isLastItem: Bool
    let isAtListStart: Bool
    let scrollOffset: CGFloat
    let contentHeight: CGFloat
    let scrollViewHeight: CGFloat
    @Binding var navigationPath: NavigationPath
    
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
        if isAtListStart && isAtAbsoluteTop {
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
        
        return ChatRowView(chat: chat)
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

#Preview {
    NavigationStack {
        ChatsListView()
    }
}


