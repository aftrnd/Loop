import SwiftUI

/// HomeView: Home feed using modular component architecture
/// Built with atomic components (PostHeader, PostContent, PostActions) + composite (PostCard)
struct HomeView: View {
    @StateObject private var viewModel = HomeFeedViewModel()
    @State private var scrollOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var scrollViewHeight: CGFloat = 0
    @State private var profileUserToShow: ProfileUser?
    @State private var loopToShowDetail: Loop?
    
    // Debug settings
    @AppStorage("showLayoutDebugOverlays") private var showLayoutDebugOverlays = false
    @AppStorage("showDebugOverlayButton") private var showDebugOverlayButton = false
    
    var body: some View {
        NavigationStack {
            feedContent
                .background(Color(.systemBackground))
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
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
                    
                    if showDebugOverlayButton {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(action: {
                                showLayoutDebugOverlays.toggle()
                            }) {
                                Image(systemName: showLayoutDebugOverlays ? "eye.fill" : "eye.slash.fill")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(showLayoutDebugOverlays ? .orange : .secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Toggle layout debug overlays")
                        }
                    }
                }
                .toolbarBackground(.automatic, for: .navigationBar)
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
        .sheet(item: $profileUserToShow) { profileUser in
            ProfileView(userId: profileUser.userId)
        }
        .sheet(item: $loopToShowDetail) { loop in
            LoopDetailView(
                loop: loop,
                onRepliesChanged: {
                    Task {
                        await viewModel.refreshReplyPreviewForLoop(loop.id)
                    }
                }
            )
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
    
    // MARK: - Feed Content
    
    private var feedContent: some View {
        FeedListView(
            coordinateSpaceName: "home2Feed",
            onRefresh: {
                await viewModel.refreshFeed()
            },
            scrollOffset: $scrollOffset,
            contentHeight: $contentHeight,
            scrollViewHeight: $scrollViewHeight
        ) {
            if viewModel.isLoading && viewModel.loops.isEmpty {
                loadingView
            } else if viewModel.loops.isEmpty {
                emptyStateView
            } else {
                postsSection
            }
        }
    }
    
    // MARK: - Posts Section
    
    @ViewBuilder
    private var postsSection: some View {
        ForEach(Array(viewModel.loops.enumerated()), id: \.element.id) { index, loop in
            let replies = viewModel.replyPreviews[loop.id]
            
            VStack(spacing: 0) {
                // Single PostCard handles both cases
                PostCard(
                    loop: loop,
                    isLiked: viewModel.isLikedByCurrentUser(loop),
                    onLike: {
                        Task {
                            await viewModel.toggleLike(for: loop)
                        }
                    },
                    onComment: {
                        if loop.replyCount > 0 {
                            loopToShowDetail = loop
                        } else {
                            viewModel.replyToLoop(loop)
                        }
                    },
                    onShare: {
                        // TODO: Implement share
                    },
                    onDelete: viewModel.canDeleteLoop(loop) ? {
                        Task {
                            await viewModel.deleteLoop(loop)
                        }
                    } : nil,
                    onAvatarTap: {
                        profileUserToShow = ProfileUser(userId: loop.authorId)
                    },
                    replyPreviews: replies,
                    onReplyPreviewTap: {
                        loopToShowDetail = loop
                    },
                    onReplyDelete: { reply in
                        if viewModel.canDeleteLoop(reply) {
                            Task {
                                await viewModel.deleteLoop(reply)
                            }
                        }
                    },
                    isReplyLiked: { reply in
                        viewModel.isLikedByCurrentUser(reply)
                    },
                    showDebugOverlays: showLayoutDebugOverlays
                )
                .padding(.top, index == 0 ? 0 : 5)
                .padding(.bottom, index == viewModel.loops.count - 1 ? 0 : 5)
                
                // Divider between posts
                if index < viewModel.loops.count - 1 {
                    PostDivider()
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
    
    // MARK: - Loading View
    
    private var loadingView: some View {
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
        .frame(height: UIScreen.main.bounds.height - 200)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
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
    }
}

// MARK: - Preview
#Preview {
    HomeView()
}

