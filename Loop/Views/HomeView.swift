import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeFeedViewModel()
    @State private var scrollOffset: CGFloat = 0
    @State private var profileUserToShow: ProfileUser?
    @State private var showProfile = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                feedListView
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        // Haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        
                        // Open compose sheet
                        viewModel.showCompose()
                    }) {
                        Image(systemName: "plus")
                            .font(.body)
                            .fontWeight(.medium)
                    }
                    .buttonStyle(.plain)
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Loop")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $viewModel.showingCompose) {
            ComposeLoopView(
                draft: $viewModel.composeDraft,
                isPresented: $viewModel.showingCompose,
                onPost: {
                    await viewModel.postLoop()
                }
            )
            .presentationDetents([.fraction(0.40), .large])
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.35)))
            .presentationContentInteraction(.scrolls)
        }
        .sheet(isPresented: $showProfile) {
            ProfileView()
        }
        .sheet(item: $profileUserToShow) { profileUser in
            ProfileView(userId: profileUser.userId)
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    private var feedListView: some View {
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
                // Feed content
                if viewModel.isLoading && viewModel.loops.isEmpty {
                    // Loading state
                    GeometryReader { geometry in
                        VStack {
                            Spacer()
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                Text("Getting your Loops...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                    .frame(height: UIScreen.main.bounds.height - 200) // Account for navigation and safe areas
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                } else if viewModel.loops.isEmpty {
                    // Empty state
                    HStack {
                        Spacer()
                        VStack(spacing: 20) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            
                            VStack(spacing: 8) {
                                Text("Welcome to Loop!")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text("Start following people to see their loops in your feed, or create your first loop!")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                            }
                        }
                        .padding(.vertical, 60)
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(Array(viewModel.loops.enumerated()), id: \.element.id) { index, loop in
                        LoopCardView(
                            loop: loop,
                            isLiked: viewModel.isLikedByCurrentUser(loop),
                            onLike: {
                                // Acquire lock synchronously before creating Task to prevent race conditions
                                guard viewModel.startLikeOperation(for: loop.id) else { return }
                                
                                // Stronger haptic feedback for satisfying like action
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                                
                                Task {
                                    await viewModel.toggleLike(for: loop)
                                }
                            },
                            onReply: {
                                // Haptic feedback
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                                
                                viewModel.replyToLoop(loop)
                            },
                            onDelete: viewModel.canDeleteLoop(loop) ? {
                                // Haptic feedback
                                let impactFeedback = UINotificationFeedbackGenerator()
                                impactFeedback.notificationOccurred(.warning)
                                
                                Task {
                                    await viewModel.deleteLoop(loop)
                                }
                            } : nil,
                            onAvatarTap: {
                                print("👆 Avatar tapped - opening profile for user: \(loop.authorId)")
                                profileUserToShow = ProfileUser(userId: loop.authorId)
                            }
                        )
                        .padding(.top, index == 0 ? 0 : 5) // Add top padding except for first post
                        .padding(.bottom, index == viewModel.loops.count - 1 ? 0 : 5) // Add bottom padding except for last post
                        .overlay(alignment: .bottom) {
                            if index < viewModel.loops.count - 1 {
                                Rectangle()
                                    .fill(Color(.separator))
                                    .frame(height: 1.15)
                                    .padding(.horizontal, 10)
                            }
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
                        .onAppear {
                            // Load more content when near the end
                            if loop.id == viewModel.loops.last?.id {
                                Task {
                                    await viewModel.loadMoreContent()
                                }
                            }
                        }
                    }
                    
                    // Loading more indicator
                    if viewModel.isLoading && !viewModel.loops.isEmpty {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding()
                            Spacer()
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
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
                await viewModel.refreshFeed()
            }
        }
    }
}


#Preview {
    HomeView()
}
