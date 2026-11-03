import SwiftUI
import os

/// A topic account's page, opened from one of its posts. Topic accounts have no profile document, so the post carries
/// everything the card shows: the topic's look and its name.
struct TopicPage: Hashable {
    let topic: LoopTopic
    let name: String
    /// The author id the topic's posts are written under
    let authorId: String

    init?(loop: Loop) {
        guard let topic = loop.topic else { return nil }
        self.topic = topic
        self.name = loop.displayAuthorName
        self.authorId = loop.authorId
    }
}

/// A topic's page, laid out like a profile: the topic post's header at twice the scale on a wallpaper in the topic's
/// look, Follow at the card's foot, and the topic's latest posts on the page at full height.
struct TopicView: View {
    let page: TopicPage

    private static let logger = Logger(subsystem: "com.nejack.Loop", category: "TopicView")
    /// How many of the topic's latest posts the page shows. A topic posts up to twice an hour, so about a day of them
    private static let postLimit = 50

    /// The card's detent, worked out before the sheet opened
    private let collapsedHeight: CGFloat

    @State private var currentDetent: PresentationDetent
    @State private var sheetMetrics = ProfileSheetMetrics()
    @State private var feedViewModel: ProfileFeedViewModel
    /// How far the page is scrolled. Only the full-height page scrolls; the card always shows the header
    @State private var scrollPosition = ScrollPosition(edge: .top)

    /// Whether the signed-in user follows the topic, nil until it has been read
    @State private var isFollowing: Bool?
    @State private var isFollowLoading = false
    /// Set to a new value to play the follow sparkle once.
    @State private var sparkleBurstID: UUID?
    /// A failed follow, shown in an alert.
    @State private var actionError: String?

    @Environment(\.dismiss) private var dismiss
    /// The sheet's glass, which makes secondary text vibrant on the card
    @Environment(\.backgroundMaterial) private var sheetMaterial
    @Environment(SheetRouter.self) private var sheetRouter: SheetRouter?

    private var isSheetFullyExpanded: Bool {
        currentDetent == .large
    }

    /// The card's whole height, including the bottom safe area its detent leaves out
    private var cardHeight: CGFloat {
        collapsedHeight + (sheetRouter?.profileLayout?.bottomInset ?? 0)
    }

    /// A team's own color, as its squircle wears it; every other topic is in ink, so the dark gray of a profile with
    /// no wallpaper
    private var wallpaperColor: Color {
        let ink = Color(.systemGray5)
        guard page.topic.isTeam else { return ink }
        return Color(hex: page.topic.color) ?? ink
    }

    /// - Parameter collapsedHeight: The card's detent from `collapsedHeight(for:in:)`, or nil when the layout isn't
    ///   known, which leaves out the bottom safe area
    init(page: TopicPage, collapsedHeight: CGFloat?) {
        self.page = page
        let height = collapsedHeight ?? ProfileGeometry.heroHeight + ProfileGeometry.cardActionHeight + ProfileGeometry.part
        self.collapsedHeight = height
        _currentDetent = State(initialValue: .height(height))
        _feedViewModel = State(initialValue: ProfileFeedViewModel(userId: page.authorId, postLimit: Self.postLimit))
    }

    var body: some View {
        // Read during the body so the alert appears when either source sets an error
        let errorMessage = actionError ?? feedViewModel.errorMessage

        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                // As in ProfileView: only the SheetExpansion modifiers read the live height
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height + proxy.safeAreaInsets.top
                } action: { height in
                    withAnimation(ProfileView.expansionAnimation) {
                        sheetMetrics.height = height
                        if isSheetFullyExpanded {
                            sheetMetrics.recordFullHeight()
                        }
                    }
                }
                .onChange(of: sheetRouter?.profileLayout?.height, initial: true) { _, height in
                    sheetMetrics.expectedFullHeight = height
                }
                .onChange(of: isSheetFullyExpanded) { _, isExpanded in
                    if isExpanded {
                        withAnimation(ProfileView.expansionAnimation) {
                            sheetMetrics.recordFullHeight()
                        }
                    } else {
                        // Collapsed from a scrolled feed, the card would show nothing
                        scrollPosition.scrollTo(edge: .top)
                    }
                }
                .task {
                    await feedViewModel.load(.posts)
                }
                .task {
                    await loadFollowing()
                }
                .modifier(ProfileNavigationModifiers(
                    isSheetFullyExpanded: isSheetFullyExpanded,
                    dismissAction: { dismiss() }
                ))
                .alert("Error", isPresented: errorAlertBinding(isPresented: errorMessage != nil)) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(errorMessage ?? "")
                }
                .presentationDetents([.height(collapsedHeight), .large], selection: $currentDetent)
                .presentationDragIndicator(.visible)
        }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 0) {
                header

                // The topic's posts, fading in as the sheet opens on the page that rises over the wallpaper's foot
                ProfileFeedSection(viewModel: feedViewModel, selectedTab: .posts)
                    // The first post's avatar starts a part spacing below the page's top, and 8pt inside its card
                    .padding(.top, ProfileGeometry.part - CardLayoutConstants.topPadding)
                    .modifier(SheetExpansionFade(
                        metrics: sheetMetrics,
                        minimumHeight: collapsedHeight,
                        isFullyExpanded: isSheetFullyExpanded
                    ))
                    .background {
                        ProfilePageBackground(
                            metrics: sheetMetrics,
                            minimumHeight: collapsedHeight,
                            isFullyExpanded: isSheetFullyExpanded
                        )
                    }
            }
        }
        .scrollIndicators(.hidden)
        .scrollPosition($scrollPosition)
        // The card doesn't scroll: a drag on it resizes the sheet, as on a profile
        .scrollDisabled(!isSheetFullyExpanded)
        .scrollClipDisabled(!isSheetFullyExpanded)
        .background(isSheetFullyExpanded ? Color(.systemBackground) : Color.clear)
        .environment(\.backgroundMaterial, isSheetFullyExpanded ? nil : sheetMaterial)
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Header

    /// The wallpaper with the topic's avatar, name and AI line, and Follow under them, a part spacing apart.
    private var header: some View {
        BaselineSpacedVStack(spacing: ProfileGeometry.part) {
            TopicIdentityRow(page: page)
                // The wallpaper always renders dark, like a contact poster
                .environment(\.colorScheme, .dark)

            followButton
                .modifier(SheetExpansionHeight(
                    metrics: sheetMetrics,
                    minimumHeight: collapsedHeight,
                    isFullyExpanded: isSheetFullyExpanded,
                    collapsed: ProfileGeometry.cardActionHeight,
                    expanded: ProfileGeometry.fullHeightActionHeight
                ))
        }
        .padding(.top, ProfileGeometry.avatarTop)
        .padding(.horizontal, ProfileGeometry.margin)
        // The wallpaper ends as far below Follow as it sits from the sides, so on the card it stays concentric with
        // the sheet's corners
        .padding(.bottom, ProfileGeometry.part)
        .foregroundStyle(.white)
        // White glass, with its label in black
        .tint(.white)
        .backgroundStyle(.black)
        .background {
            ProfileBackdrop(
                bannerURL: nil,
                color: wallpaperColor,
                cardHeight: cardHeight,
                heroHeight: ProfileGeometry.heroHeight
            )
            // On under the page's rounded corners
            .padding(.bottom, -ProfileGeometry.wallpaperReach)
        }
        // Nothing in the header sits on the sheet's glass, so nothing in it is vibrant
        .environment(\.backgroundMaterial, nil)
    }

    // MARK: - Follow

    /// Follow in the profile's white glass, plain glass once you follow the topic. Its label shows once whether you
    /// follow it is known, so it never flips from Follow to Following as the page opens.
    private var followButton: some View {
        let isFollowing = isFollowing ?? false
        return GlassEffectContainer {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                Task {
                    await toggleFollow()
                }
            } label: {
                ProfileActionLabel(
                    symbol: isFollowing ? "checkmark" : "plus",
                    title: isFollowing ? "Following" : "Follow",
                    isLoading: isFollowLoading
                )
                .foregroundStyle(isFollowing ? AnyShapeStyle(.primary) : AnyShapeStyle(.background))
                .opacity(self.isFollowing == nil ? 0 : 1)
            }
            .frame(maxWidth: .infinity)
            .modifier(ProfileActionGlass(isProminent: !isFollowing))
            .overlay {
                // A fresh SparkleAnimation plays once when it appears, so each follow inserts a new one
                if let sparkleBurstID {
                    SparkleAnimation()
                        .id(sparkleBurstID)
                        .allowsHitTesting(false)
                        .task(id: sparkleBurstID) {
                            // The burst runs 0.1s plus 1.5s; remove it once it has faded out
                            try? await Task.sleep(for: .seconds(1.6))
                            if !Task.isCancelled {
                                self.sparkleBurstID = nil
                            }
                        }
                }
            }
        }
    }

    private func loadFollowing() async {
        do {
            isFollowing = try await FirebaseService.shared.followedTopics().contains(page.topic.id)
        } catch {
            Self.logger.error("Followed topics read failed: \(error.localizedDescription, privacy: .public)")
            isFollowing = false
        }
    }

    /// Follows or unfollows optimistically, and reverts if the write fails. Taps wait until the state is known and
    /// the last change has saved.
    private func toggleFollow() async {
        guard let wasFollowing = isFollowing, !isFollowLoading else { return }

        isFollowLoading = true
        defer { isFollowLoading = false }
        isFollowing = !wasFollowing
        if !wasFollowing {
            sparkleBurstID = UUID()
        }

        do {
            try await FirebaseService.shared.setFollowing(!wasFollowing, topicId: page.topic.id)
        } catch {
            Self.logger.error("Topic follow change failed: \(error.localizedDescription, privacy: .public)")
            isFollowing = wasFollowing
            actionError = wasFollowing ? "Couldn't unfollow. Please try again." : "Couldn't follow. Please try again."
        }
    }

    /// Presents follow and feed errors in one alert; dismissing it clears them both.
    private func errorAlertBinding(isPresented: Bool) -> Binding<Bool> {
        Binding(
            get: { isPresented },
            set: { newValue in
                if !newValue {
                    actionError = nil
                    feedViewModel.clearError()
                }
            }
        )
    }
}

// MARK: - Collapsed Height

extension TopicView {
    /// The card's detent, worked out before the sheet is presented with the same identity row the card shows, so the
    /// sheet opens at its final height.
    static func collapsedHeight(for page: TopicPage, in context: ProfileLayoutContext) -> CGFloat {
        let contentWidth = context.width - ProfileGeometry.margin * 2
        let row = TopicIdentityRow(page: page)
            // The app's type, which the sheet inherits from the root
            .fontDesign(.rounded)
            .environment(\.dynamicTypeSize, context.dynamicTypeSize)
            .environment(\.legibilityWeight, context.legibilityWeight)
            .environment(\.displayScale, context.displayScale)
        let rowHeight = UIHostingController(rootView: row)
            .sizeThatFits(in: CGSize(width: contentWidth, height: .greatestFiniteMagnitude))
            .height
        let follow = ProfileGeometry.part + ProfileGeometry.cardActionHeight
        return ProfileGeometry.avatarTop + rowHeight + follow + ProfileGeometry.part - context.bottomInset
    }
}

// MARK: - Topic Text

/// The topic's avatar on the left, lit and shadowed like a profile's, with its name and AI line beside it.
private struct TopicIdentityRow: View {
    let page: TopicPage

    var body: some View {
        ProfileIdentityRow(name: page.name) {
            TopicAvatar(topic: page.topic, size: ProfileGeometry.avatarSize)
                .overlay {
                    ProfileAvatarRim()
                }
                .modifier(ProfileAvatarShadow())
                .accessibilityHidden(true)
        } lines: {
            TopicAILine()
        }
    }
}

/// The line under a topic's name: the AI mark, then what the topic posts, as a topic post's second line has the mark
/// and the story's source. In callout like a profile's lines, and the mark in their white.
private struct TopicAILine: View {
    private static let text = "News written by AI"

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize))
        let font = UIFont.roundedSystemFont(.callout, weight: .regular, compatibleWith: traits)
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            AIMark(fill: .white.opacity(0.85))

            Text(Self.text)
                .lineLimit(1)
                // Its ink starts 5pt from the mark
                .offset(x: -font.leadingSideBearing(of: Self.text))
        }
        .font(.callout)
        .foregroundStyle(.white.opacity(0.85))
        .frame(maxWidth: .infinity, alignment: .leading)
        .visibleTopAtCapHeight(of: .callout)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.text)
    }
}
