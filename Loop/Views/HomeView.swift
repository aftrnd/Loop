import SwiftUI

/// HomeView: Home feed using modular component architecture
/// Built with atomic components (PostHeader, PostContent, PostActions) + composite (PostCard)
struct HomeView: View {
    @State private var viewModel = HomeFeedViewModel()
    @Environment(SheetRouter.self) private var sheetRouter
    
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
                        LoopWordmark()
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
        .task {
            viewModel.start()
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
        .alert("Error", isPresented: errorAlertBinding) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.clearError()
                }
            }
        )
    }
    
    // MARK: - Feed Content
    
    private var feedContent: some View {
        FeedListView(
            onRefresh: {
                await viewModel.refreshFeed()
            }
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
        let firstLoopId = viewModel.loops.first?.id
        let lastLoopId = viewModel.loops.last?.id
        
        ForEach(viewModel.loops) { loop in
            let replies = viewModel.replyPreviews[loop.id]
            let isFirst = loop.id == firstLoopId
            let isLast = loop.id == lastLoopId
            
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
                            showThread(loop)
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
                        sheetRouter.showProfile(userId: loop.authorId)
                    },
                    replyPreviews: replies,
                    onReplyPreviewTap: {
                        showThread(loop)
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
                .padding(.top, isFirst ? 0 : 5)
                .padding(.bottom, isLast ? 0 : 5)
                
                // Divider between posts
                if !isLast {
                    PostDivider()
                }
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
            .onAppear {
                // Load more content when near the end
                if isLast {
                    Task {
                        await viewModel.loadMoreContent()
                    }
                }
            }
        }
        
        // Loading more indicator
        if viewModel.isLoadingMore {
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
    
    private func showThread(_ loop: Loop) {
        sheetRouter.showThread(loop) {
            Task {
                await viewModel.refreshReplyPreviewForLoop(loop.id)
            }
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
        .frame(height: 600)
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
        .environment(SheetRouter())
}

