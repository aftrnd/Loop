import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeFeedViewModel()
    @State private var showingProfile = false
    @State private var scrollOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var scrollViewHeight: CGFloat = 0
    @State private var isComposing = false
    @State private var composeText = ""
    @FocusState private var isComposeFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                feedListView
                fadeOverlays
                
                // Bottom compose input (hidden when scrolling)
                VStack {
                    Spacer()
                    
                    if scrollOffset < 50 { // Show when not scrolling much
                        InlineComposeView(
                            isComposing: $isComposing,
                            composeText: $composeText,
                            isComposeFieldFocused: $isComposeFieldFocused,
                            onPost: {
                                Task {
                                    // Create a draft and post
                                    viewModel.composeDraft.content = composeText
                                    await viewModel.postLoop()
                                    
                                    // Reset state
                                    composeText = ""
                                    isComposing = false
                                    isComposeFieldFocused = false
                                }
                            }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.3), value: scrollOffset < 50)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Loop")
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
        }
        .sheet(isPresented: $showingProfile) {
            // TODO: Present ProfileView
            Text("Profile View")
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
                scrollSentinel
                
                // Feed content
                if viewModel.isLoading && viewModel.loops.isEmpty {
                    // Loading state
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Loading your feed...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 40)
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
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
                        LoopItemView(
                            loop: loop,
                            index: index,
                            totalCount: viewModel.loops.count,
                            isLastItem: index == viewModel.loops.count - 1,
                            isAtListStart: index == 0 && scrollOffset <= 32,
                            scrollOffset: scrollOffset,
                            contentHeight: contentHeight,
                            scrollViewHeight: scrollViewHeight,
                            viewModel: viewModel
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
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
                
                // Bottom sentinel to track content height
                GeometryReader { geo in
                    Color.clear
                        .onChange(of: geo.frame(in: .named("loopScroll")).maxY) { _, newValue in
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
            .coordinateSpace(name: "loopScroll")
            .scrollIndicators(.hidden)
            .contentMargins(.top, -32)
            .refreshable {
                await viewModel.refreshFeed()
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
}

struct LoopItemView: View {
    let loop: Loop
    let index: Int
    let totalCount: Int
    let isLastItem: Bool
    let isAtListStart: Bool
    let scrollOffset: CGFloat
    let contentHeight: CGFloat
    let scrollViewHeight: CGFloat
    let viewModel: HomeFeedViewModel
    
    var body: some View {
        createLoopItem()
    }
    
    private func createLoopItem() -> some View {
        LoopCardView(
            loop: loop,
            isLiked: viewModel.isLikedByCurrentUser(loop),
            onLike: {
                Task {
                    await viewModel.toggleLike(for: loop)
                }
            },
            onReply: {
                viewModel.replyToLoop(loop)
            },
            onShare: {
                viewModel.shareLoop(loop)
            },
            onAvatarTap: {
                // TODO: Navigate to user profile
            }
        )
        .overlay(alignment: .bottom) {
            if index < totalCount - 1 {
                Rectangle()
                    .fill(Color(.separator))
                    .frame(height: 0.5)
                    .padding(.horizontal, 16) // Inset divider like Twitter
            }
        }
    }
}

struct InlineComposeView: View {
    @Binding var isComposing: Bool
    @Binding var composeText: String
    var isComposeFieldFocused: FocusState<Bool>.Binding
    let onPost: () -> Void
    @State private var showingImagePicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            if isComposing {
                // Expanded compose area
                VStack(spacing: 12) {
                    HStack {
                        Button("Cancel") {
                            isComposing = false
                            composeText = ""
                            isComposeFieldFocused.wrappedValue = false
                        }
                        .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button("Post") {
                            onPost()
                        }
                        .fontWeight(.semibold)
                        .disabled(composeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .foregroundColor(composeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : .accentColor)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    
                    TextField("What's happening in the loop?", text: $composeText, axis: .vertical)
                        .font(.body)
                        .focused(isComposeFieldFocused)
                        .lineLimit(5...10)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                }
                .background(
                    Color(.systemBackground)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            } else {
                // Collapsed compose bar
                Button(action: {
                    isComposing = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isComposeFieldFocused.wrappedValue = true
                    }
                }) {
                    HStack(spacing: 12) {
                        Text("What's happening in the loop?")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Button(action: {
                            showingImagePicker = true
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Color.clear
                            .glassEffect(.regular, in: Capsule())
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20) // Standard tab bar side padding
                .padding(.bottom, 8)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isComposing)
        .sheet(isPresented: $showingImagePicker) {
            // TODO: Implement image picker
            Text("Image Picker")
        }
    }
}

#Preview {
    HomeView()
}
