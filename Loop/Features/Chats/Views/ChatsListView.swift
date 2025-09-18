import SwiftUI
import UIKit

struct ChatsListView: View {
    @StateObject private var viewModel = ChatsListViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if !viewModel.pinned.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
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
                                        let scale = 1 - (0.06 * edgeFactor)
                                        let rotation = Angle(degrees: rotationSign * 6 * edgeFactor)
                                        let opacity = 0.9 + (1 - edgeFactor) * 0.1
                                        let blur = 6 * edgeFactor
                                        let parallax = ((midY - screenMid) / 18) * edgeFactor
                                        NavigationLink(value: ChatsRoute.conversation(chat)) {
                                            ChatRowView(chat: chat, parallax: parallax)
                                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                                .compositingGroup()
                                                .scaleEffect(scale)
                                                .rotation3DEffect(rotation, axis: (x: 1, y: 0, z: 0), anchor: .center)
                                                .opacity(opacity)
                                                .blur(radius: blur)
                                        }
                                        .buttonStyle(.plain)
                                        .contentShape(RoundedRectangle(cornerRadius: 18))
                                    }
                                    .frame(height: 99)
                                    if index < viewModel.pinned.count - 1 {
                                        Divider()
                                            .padding(.leading, 86)
                                    }
                                }
                            }
                        }
                        
                        if !viewModel.recent.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
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
                                        let scale = 1 - (0.06 * edgeFactor)
                                        let rotation = Angle(degrees: rotationSign * 6 * edgeFactor)
                                        let opacity = 0.9 + (1 - edgeFactor) * 0.1
                                        let blur = 6 * edgeFactor
                                        let parallax = ((midY - screenMid) / 18) * edgeFactor
                                        NavigationLink(value: ChatsRoute.conversation(chat)) {
                                            ChatRowView(chat: chat, parallax: parallax)
                                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                                .compositingGroup()
                                                .scaleEffect(scale)
                                                .rotation3DEffect(rotation, axis: (x: 1, y: 0, z: 0), anchor: .center)
                                                .opacity(opacity)
                                                .blur(radius: blur)
                                        }
                                        .buttonStyle(.plain)
                                        .contentShape(RoundedRectangle(cornerRadius: 18))
                                    }
                                    .frame(height: 99)
                                    if index < viewModel.recent.count - 1 {
                                        Divider()
                                            .padding(.leading, 86)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                }
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
