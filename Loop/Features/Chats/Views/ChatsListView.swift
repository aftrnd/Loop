import SwiftUI
import UIKit

struct ChatsListView: View {
    @StateObject private var viewModel = ChatsListViewModel()
    @State private var topDistance: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var navigationPath = NavigationPath()
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                List {
                    // Top sentinel: measure scroll offset from top in named space
                    GeometryReader { geo in
                        let topMinY = geo.frame(in: .named("chatScroll")).minY
                        Color.clear
                            .onChange(of: topMinY) { _, newValue in
                                // Scroll offset is positive when scrolled down
                                let offset = max(0, -newValue)
                                scrollOffset = offset
                                topDistance = offset
                            }
                    }
                    .frame(height: 0)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    
                    // Pinned messages in iOS-style avatar grid
                    if !viewModel.pinned.isEmpty {
                        VStack(spacing: 16) {
                            // First row of 3
                            HStack {
                                ForEach(Array(viewModel.pinned.prefix(3).enumerated()), id: \.element.id) { index, chat in
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
                                    if index < viewModel.pinned.prefix(3).count - 1 {
                                        Spacer()
                                    }
                                }
                            }
                            
                            // Second row of 3 if we have more than 3 pinned
                            if viewModel.pinned.count > 3 {
                                HStack {
                                    ForEach(Array(viewModel.pinned.dropFirst(3).prefix(3).enumerated()), id: \.element.id) { index, chat in
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
                                        if index < viewModel.pinned.dropFirst(3).prefix(3).count - 1 {
                                            Spacer()
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 0)
                        .padding(.bottom, 8)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                        .environment(\.defaultMinListRowHeight, 0)
                    }
                    
                    // Regular chat list (combining all remaining chats)
                    ForEach(Array(viewModel.recent.enumerated()), id: \.element.id) { index, chat in
                        GeometryReader { geo in
                            let midY = geo.frame(in: .global).midY
                            let screenMid = UIScreen.main.bounds.midY
                            let screen = UIScreen.main.bounds
                            let edgeZone: CGFloat = max(120, screen.height * 0.18)
                            
                            // Simplified logic that mirrors top behavior for bottom
                            let topFactor = max(0, 1 - max(0, midY - screen.minY) / edgeZone)
                            let bottomFactor = max(0, 1 - max(0, screen.maxY - midY) / edgeZone)
                            
                            let rotationSign: CGFloat = topFactor >= bottomFactor ? 1 : -1
                            
                            // Disable effects for first and last items to ease into normal scrolling
                            let isFirstRecentItem = index == 0
                            let isLastRecentItem = index == viewModel.recent.count - 1
                            let isAtListStart = isFirstRecentItem && viewModel.pinned.isEmpty
                            let isAtListEnd = isLastRecentItem
                            
                            let listPositionGate: CGFloat = (isAtListStart || isAtListEnd) ? 0 : 1
                            
                            // Simple effective calculation that works consistently for both edges
                            let effective = min(1, max(topFactor, bottomFactor)) * listPositionGate
                            let scale = 1 - (0.04 * effective)
                            let rotation = Angle(degrees: rotationSign * 4 * effective)
                            let opacity = 0.9 + (1 - effective) * 0.1
                            let blur = 4 * effective
                            let parallax = ((midY - screenMid) / 24) * effective
                            
                            NavigationLink(value: ChatsRoute.conversation(chat)) {
                                ChatRowView(chat: chat)
                                    .frame(height: 84)
                                    .frame(maxWidth: .infinity)
                                    .compositingGroup()
                            }
                            .buttonStyle(.plain)
                            .contentShape(RoundedRectangle(cornerRadius: 18))
                            .overlay(alignment: .bottom) {
                                if index < viewModel.recent.count - 1 {
                                    Rectangle()
                                        .fill(Color(.separator))
                                        .frame(height: 1 / UIScreen.main.scale)
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
                        .frame(height: 84)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    }
                    .onDelete(perform: viewModel.deleteRecentChats)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .listSectionSeparator(.hidden)
                .coordinateSpace(name: "chatScroll")
                .contentMargins(.top, 0, for: .scrollContent)
                
                // Symmetric fade overlays for top and bottom
                VStack {
                    // Top fade overlay
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
                    
                    // Bottom fade overlay
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
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
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
            .navigationDestination(for: ChatsRoute.self) { route in
                switch route {
                case .conversation(let chat):
                    ConversationView(chat: chat)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ChatsListView()
    }
}


