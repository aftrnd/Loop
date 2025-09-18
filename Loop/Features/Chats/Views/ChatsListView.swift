import SwiftUI
import UIKit

struct ChatsListView: View {
    @StateObject private var viewModel = ChatsListViewModel()
    @State private var topDistance: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 0) {
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
                        
                        if !viewModel.pinned.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Pinned")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 20)
                                
                                ForEach(Array(viewModel.pinned.enumerated()), id: \.element.id) { index, chat in
                                    GeometryReader { geo in
                                        let midY = geo.frame(in: .global).midY
                                        let screenMid = UIScreen.main.bounds.midY
                                        let screen = UIScreen.main.bounds
                                        let edgeZone: CGFloat = max(120, screen.height * 0.18)
                                        let topZoneEnd = screen.minY + edgeZone
                                        let bottomZoneStart = screen.maxY - edgeZone
                                        let topFactor = max(0, 1 - max(0, midY - screen.minY) / edgeZone)
                                        let bottomFactor = max(0, (midY - bottomZoneStart) / edgeZone)
                                        let edgeFactor = min(1, max(topFactor, bottomFactor))
                                        let rotationSign: CGFloat = topFactor >= bottomFactor ? 1 : -1
                                        // Smoothly ramp in/out near extremes based on distance from each edge
                                        let disableThreshold: CGFloat = 28
                                        let edgeGateTop = min(1, topDistance / disableThreshold)
                                        let computedRemaining = max(0, contentHeight - viewportHeight - scrollOffset)
                                        let edgeGateBottom: CGFloat = (contentHeight <= 0 || viewportHeight <= 0) ? 1 : min(1, computedRemaining / disableThreshold)
                                        
                                        // Disable effects for first and last items to ease into normal scrolling
                                        let isFirstPinnedItem = index == 0
                                        let isLastPinnedItem = index == viewModel.pinned.count - 1
                                        let isAtListStart = isFirstPinnedItem
                                        let isAtListEnd = isLastPinnedItem && viewModel.recent.isEmpty
                                        
                                        let listPositionGate: CGFloat = (isAtListStart || isAtListEnd) ? 0 : 1
                                        
                                        // Apply gates to their respective edge factors, then combine
                                        let effectiveTop = topFactor * edgeGateTop * listPositionGate
                                        let effectiveBottom = bottomFactor * edgeGateBottom * listPositionGate
                                        let effective = min(1, max(effectiveTop, effectiveBottom))
                                        let scale = 1 - (0.04 * effective)
                                        let rotation = Angle(degrees: rotationSign * 4 * effective)
                                        let opacity = 0.9 + (1 - effective) * 0.1
                                        let blur = 4 * effective
                                        let parallax = ((midY - screenMid) / 24) * effective
                                        
                                        VStack(spacing: 0) {
                                            NavigationLink(value: ChatsRoute.conversation(chat)) {
                                                ChatRowView(chat: chat)
                                                    .frame(height: 84)
                                                    .frame(maxWidth: .infinity)
                                                    .compositingGroup()
                                            }
                                            .buttonStyle(.plain)
                                            .contentShape(RoundedRectangle(cornerRadius: 18))
                                        }
                                        .overlay(alignment: .bottom) {
                                            if index < viewModel.pinned.count - 1 {
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
                                }
                            }
                        }
                        
                        if !viewModel.recent.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Recent")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 20)
                                
                                ForEach(Array(viewModel.recent.enumerated()), id: \.element.id) { index, chat in
                                    GeometryReader { geo in
                                        let midY = geo.frame(in: .global).midY
                                        let screenMid = UIScreen.main.bounds.midY
                                        let screen = UIScreen.main.bounds
                                        let edgeZone: CGFloat = max(120, screen.height * 0.18)
                                        let topZoneEnd = screen.minY + edgeZone
                                        let bottomZoneStart = screen.maxY - edgeZone
                                        let topFactor = max(0, 1 - max(0, midY - screen.minY) / edgeZone)
                                        let bottomFactor = max(0, (midY - bottomZoneStart) / edgeZone)
                                        let edgeFactor = min(1, max(topFactor, bottomFactor))
                                        let rotationSign: CGFloat = topFactor >= bottomFactor ? 1 : -1
                                        // Smoothly ramp in/out near extremes based on distance from each edge
                                        let disableThreshold: CGFloat = 28
                                        let edgeGateTop = min(1, topDistance / disableThreshold)
                                        let computedRemaining = max(0, contentHeight - viewportHeight - scrollOffset)
                                        let edgeGateBottom: CGFloat = (contentHeight <= 0 || viewportHeight <= 0) ? 1 : min(1, computedRemaining / disableThreshold)
                                        
                                        // Disable effects for first and last items to ease into normal scrolling
                                        let isFirstRecentItem = index == 0
                                        let isLastRecentItem = index == viewModel.recent.count - 1
                                        let isAtListStart = isFirstRecentItem && viewModel.pinned.isEmpty
                                        let isAtListEnd = isLastRecentItem
                                        
                                        let listPositionGate: CGFloat = (isAtListStart || isAtListEnd) ? 0 : 1
                                        
                                        // Apply gates to their respective edge factors, then combine
                                        let effectiveTop = topFactor * edgeGateTop * listPositionGate
                                        let effectiveBottom = bottomFactor * edgeGateBottom * listPositionGate
                                        let effective = min(1, max(effectiveTop, effectiveBottom))
                                        let scale = 1 - (0.04 * effective)
                                        let rotation = Angle(degrees: rotationSign * 4 * effective)
                                        let opacity = 0.9 + (1 - effective) * 0.1
                                        let blur = 4 * effective
                                        let parallax = ((midY - screenMid) / 24) * effective
                                        
                                        VStack(spacing: 0) {
                                            NavigationLink(value: ChatsRoute.conversation(chat)) {
                                                ChatRowView(chat: chat)
                                                    .frame(height: 84)
                                                    .frame(maxWidth: .infinity)
                                                    .compositingGroup()
                                            }
                                            .buttonStyle(.plain)
                                            .contentShape(RoundedRectangle(cornerRadius: 18))
                                        }
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
                                }
                            }
                        }
                        
                        // End of content
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    // Measure total content height for bottom edge distance
                    .background(
                        GeometryReader { gp in
                            Color.clear
                                .onAppear { contentHeight = gp.size.height }
                                .onChange(of: gp.size.height) { _, newValue in
                                    contentHeight = newValue
                                }
                        }
                    )
                }
                .coordinateSpace(name: "chatScroll")
                .background(
                    GeometryReader { gp in
                        Color.clear
                            .onAppear { viewportHeight = gp.size.height }
                            .onChange(of: gp.size.height) { _, newValue in
                                viewportHeight = newValue
                            }
                    }
                )
                
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


