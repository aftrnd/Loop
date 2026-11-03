import SwiftUI
import os

/// Every topic Loop writes news posts for, each laid out as a topic post's header with Follow beside it and the
/// topic's brief under it, as a post's text. Home shows the posts of the topics you follow; a topic opens its page.
struct DiscoverView: View {
    @Environment(SheetRouter.self) private var sheetRouter
    private let directory = TopicDirectory.shared

    /// Topics whose follow is saving; their buttons ignore taps until it has
    @State private var savingIds: Set<String> = []
    /// A new value for a topic plays the follow sparkle on its button once
    @State private var sparkleBursts: [String: UUID] = [:]
    /// A failed follow, shown in an alert
    @State private var actionError: String?

    private static let logger = Logger(subsystem: "com.nejack.Loop", category: "DiscoverView")

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Discover")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                }
                .toolbarBackground(.hidden, for: .navigationBar)
        }
        .task {
            async let directoryLoad: Void = directory.loadDirectory()
            async let followsLoad = directory.follows()
            _ = await (directoryLoad, followsLoad)
        }
        .alert("Error", isPresented: errorAlertBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(actionError ?? "")
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { actionError != nil },
            set: { isPresented in
                if !isPresented {
                    actionError = nil
                }
            }
        )
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if !directory.topics.isEmpty {
            topicList
        } else {
            switch directory.state {
            case .idle, .loading:
                ProgressView()
            case .failed(let message):
                ContentUnavailableView {
                    Label("Topics didn't load", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try again") {
                        Task {
                            await directory.loadDirectory()
                        }
                    }
                }
            case .loaded:
                ContentUnavailableView(
                    "No topics yet",
                    systemImage: "square.grid.2x2",
                    description: Text("Topics show here once they post their first news.")
                )
            }
        }
    }

    private var topicList: some View {
        FeedListView(
            onRefresh: {
                // For the latest briefs
                await directory.loadDirectory(refresh: true)
            }
        ) {
            let firstId = directory.topics.first?.id
            let lastId = directory.topics.last?.id

            ForEach(directory.topics) { entry in
                // Spaced as Home's posts are: a divider a part spacing below where a topic visibly ends, the next
                // topic as far below it
                BaselineSpacedVStack(spacing: CardLayoutConstants.partSpacing) {
                    DiscoverTopicRow(entry: entry) {
                        sheetRouter.showTopic(TopicPage(entry: entry))
                    } follow: {
                        followButton(for: entry)
                    }
                    .padding(.top, entry.id == firstId ? 0 : CardLayoutConstants.partSpacing - CardLayoutConstants.topPadding)

                    if entry.id != lastId {
                        PostDivider()
                    }
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
            }
        }
    }

    // MARK: - Follow

    /// Follow in glass tinted ink, Following in plain glass, as on a profile's page. Its label shows once whether you
    /// follow the topic is known, so it never flips from Follow to Following as the list appears.
    private func followButton(for entry: TopicEntry) -> some View {
        let isFollowing = directory.isFollowing(entry.id)
        return Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            Task {
                await toggleFollow(entry)
            }
        } label: {
            // As wide as Following either way, so the text beside it never moves
            ZStack {
                ProfileActionLabel(symbol: "checkmark", title: "Following", isLoading: false)
                    .hidden()
                ProfileActionLabel(
                    symbol: isFollowing ? "checkmark" : "plus",
                    title: isFollowing ? "Following" : "Follow",
                    isLoading: savingIds.contains(entry.id)
                )
            }
            .fixedSize()
            // Following is plain glass, so its label is in the type's color rather than the page's. The page's color
            // is the system background color, as on the composer's Post: the background style resolves to white on
            // the ink glass in dark mode
            .foregroundStyle(isFollowing ? Color.primary : Color(.systemBackground))
        }
        // Not disabled while the follow saves, so the glass doesn't dim for the length of the write; toggleFollow
        // ignores taps until it finishes
        .modifier(ProfileActionGlass(isProminent: !isFollowing))
        .tint(.primary)
        .opacity(directory.followsState == .unread ? 0 : 1)
        .overlay {
            // A fresh SparkleAnimation plays once when it appears, so each follow inserts a new one
            if let burst = sparkleBursts[entry.id] {
                SparkleAnimation()
                    .id(burst)
                    .allowsHitTesting(false)
                    .task(id: burst) {
                        // The burst runs 0.1s plus 1.5s; remove it once it has faded out
                        try? await Task.sleep(for: .seconds(1.6))
                        if !Task.isCancelled, sparkleBursts[entry.id] == burst {
                            sparkleBursts[entry.id] = nil
                        }
                    }
            }
        }
        .accessibilityLabel(isFollowing ? "Following \(entry.name)" : "Follow \(entry.name)")
    }

    private func toggleFollow(_ entry: TopicEntry) async {
        guard directory.followsState != .unread, !savingIds.contains(entry.id) else { return }
        let wasFollowing = directory.isFollowing(entry.id)

        savingIds.insert(entry.id)
        defer { savingIds.remove(entry.id) }
        if !wasFollowing {
            sparkleBursts[entry.id] = UUID()
        }

        do {
            try await directory.setFollowing(!wasFollowing, topicId: entry.id)
        } catch {
            Self.logger.error("Topic follow change failed: \(error.localizedDescription, privacy: .public)")
            actionError = wasFollowing
                ? "Couldn't unfollow \(entry.name). Please try again."
                : "Couldn't follow \(entry.name). Please try again."
        }
    }
}

// MARK: - Topic Row

/// A topic as its posts begin: its squircle, name, and the AI mark with its sources, then its brief as a post's text.
/// The whole row opens the topic's page except Follow, which sits beside the header on the avatar's middle.
private struct DiscoverTopicRow<Follow: View>: View {
    let entry: TopicEntry
    let onOpen: () -> Void
    @ViewBuilder let follow: Follow

    var body: some View {
        let sources = TopicSources.variants(entry.sources)
        BaselineSpacedVStack(spacing: CardLayoutConstants.partSpacing) {
            HStack(spacing: CardLayoutConstants.avatarSpacing) {
                PostHeader(
                    avatarURL: nil,
                    displayName: entry.name,
                    username: nil,
                    badgeType: nil,
                    topic: entry.topic,
                    source: sources[0],
                    shorterSources: Array(sources.dropFirst())
                )
                .allowsHitTesting(false)

                follow
            }
            // It visibly spans the avatar, which is taller than Follow beside it
            .alignmentGuide(.visibleTop) { $0[.top] }
            .alignmentGuide(.visibleBottom) { $0[.bottom] }

            if let brief = entry.brief, !brief.isEmpty {
                PostContent(text: brief)
                    .allowsHitTesting(false)
            }
        }
        .padding(.horizontal, CardLayoutConstants.horizontalPadding)
        .padding(.top, CardLayoutConstants.topPadding)
        .padding(.bottom, CardLayoutConstants.bottomPadding)
        .background {
            // Behind the row, so Follow on top keeps its own taps
            Button(action: onOpen) {
                Color.clear
            }
            .buttonStyle(DiscoverRowButtonStyle())
            .accessibilityLabel("Open \(entry.name)")
        }
    }
}

/// The row's press: the card a post sits on, lit while it is held.
private struct DiscoverRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        RoundedRectangle(cornerRadius: CardLayoutConstants.cornerRadius)
            .fill(Color(.systemGray6))
            .opacity(configuration.isPressed ? 1 : 0)
            .animation(.easeOut(duration: configuration.isPressed ? 0.1 : 0.3), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

#Preview {
    DiscoverView()
        .environment(SheetRouter())
}
