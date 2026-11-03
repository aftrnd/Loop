import SwiftUI
import os

/// A topic account's page, opened from one of its posts. Topic accounts have no profile document, so the post carries
/// everything the card shows until the topic's posts load: the topic's look, its name, a source and a time.
struct TopicPage: Hashable {
    let topic: LoopTopic
    let name: String
    /// The author id the topic's posts are written under
    let authorId: String
    /// The post the page was opened from
    let post: Loop

    init?(loop: Loop) {
        guard let topic = loop.topic else { return nil }
        self.topic = topic
        self.name = loop.displayAuthorName
        self.authorId = loop.authorId
        self.post = loop
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
            TopicIdentityRow(page: page, feed: feedViewModel)
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
            ProfileBackdrop(cardHeight: cardHeight, heroHeight: ProfileGeometry.heroHeight, shade: page.topic.pageColor) {
                TopicWallpaper(page: page, feed: feedViewModel)
            }
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
        let row = TopicIdentityRow(page: page, feed: nil)
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

/// The topic's avatar on the left, lit and shadowed like a profile's, with its name and two lines beside it.
private struct TopicIdentityRow: View {
    let page: TopicPage
    /// The topic's posts, once they load; until then the lines come from the post the page was opened from
    let feed: ProfileFeedViewModel?

    var body: some View {
        ProfileIdentityRow(name: page.name) {
            TopicAvatar(topic: page.topic, size: ProfileGeometry.avatarSize)
                .overlay {
                    ProfileAvatarRim()
                }
                .modifier(ProfileAvatarShadow())
                .accessibilityHidden(true)
        } lines: {
            TopicLines(page: page, feed: feed)
        }
    }
}

/// The line under a topic's name, as a topic post's second line has the AI mark and its story's source: the mark
/// with the sources its latest posts summarize. Reading the feed here keeps its loads from re-rendering the rest of the
/// page.
private struct TopicLines: View {
    let page: TopicPage
    let feed: ProfileFeedViewModel?

    /// The publishers its posts summarize, the most summarized first, ties in order of their latest post
    private var sources: [String] {
        let loaded = feed?.posts ?? []
        var counts: [String: Int] = [:]
        var order: [String] = []
        for post in loaded.isEmpty ? [page.post] : loaded {
            guard let source = post.link?.source, !source.isEmpty else { continue }
            if counts[source] == nil {
                order.append(source)
            }
            counts[source, default: 0] += 1
        }
        return order.enumerated()
            .sorted { (counts[$0.element] ?? 0, -$0.offset) > (counts[$1.element] ?? 0, -$1.offset) }
            .map(\.element)
    }

    var body: some View {
        let sources = sources
        TopicSourcesLine(variants: Self.variants(sources), spokenText: Self.spokenText(sources))
    }

    /// The sources, longest first: up to two by name and how many more, then one by name, then only how many
    private static func variants(_ sources: [String]) -> [String] {
        switch sources.count {
        case 0: return ["News summaries"]
        case 1: return [sources[0]]
        case 2: return ["\(sources[0]) and \(sources[1])", "\(sources[0]) and 1 more", "2 sources"]
        default:
            return [
                "\(sources[0]), \(sources[1]) and \(sources.count - 2) more",
                "\(sources[0]) and \(sources.count - 1) more",
                "\(sources.count) sources"
            ]
        }
    }

    private static func spokenText(_ sources: [String]) -> String {
        guard !sources.isEmpty else { return "News summaries written by AI" }
        return "Summaries written by AI, from " + ListFormatter.localizedString(byJoining: sources)
    }
}

/// The AI mark, then the longest of the texts that fits on one line, in callout like a profile's lines.
private struct TopicSourcesLine: View {
    /// The text, longest first
    let variants: [String]
    let spokenText: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize))
        let font = UIFont.roundedSystemFont(.callout, weight: .regular, compatibleWith: traits)
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            AIMark(fill: .white.opacity(0.85))

            ViewThatFits(in: .horizontal) {
                ForEach(variants, id: \.self) { text in
                    Text(text)
                        .lineLimit(1)
                        // Its ink starts 5pt from the mark, whatever its first letter
                        .offset(x: -font.leadingSideBearing(of: text))
                }
            }
        }
        .font(.callout)
        .foregroundStyle(.white.opacity(0.85))
        .frame(maxWidth: .infinity, alignment: .leading)
        .visibleTopAtCapHeight(of: .callout)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenText)
    }
}

// MARK: - Wallpaper

private extension LoopTopic {
    /// The topic's color on its page: a team's own, exactly, or for a topic drawn in ink, its color darkened to a deep
    /// shade of its own
    var pageColor: Color {
        let color = Color(hex: self.color) ?? Color(.systemGray5)
        return isTeam ? color : color.mix(with: .black, by: 0.55)
    }
}

/// A story photo the wallpaper shows, with what its credit says
private struct TopicPhoto: Hashable {
    let url: URL
    let source: String
    let timeAgo: String
}

/// A topic's wallpaper: its latest story photos in full color, one after another, on the topic's color until the
/// first has loaded. The post the page was opened from stands in until the topic's posts load. Each photo loads before
/// it fades in over the last, which stays underneath, so the wallpaper never shows a photo half faded over its color.
private struct TopicWallpaper: View {
    let page: TopicPage
    let feed: ProfileFeedViewModel

    /// The latest photos it goes through
    private static let photoCount = 5
    /// How long each photo shows before the next fades in
    private static let hold: Duration = .seconds(6)
    private static let crossfade = Animation.easeInOut(duration: 1.2)

    private struct Shown: Equatable {
        let photo: TopicPhoto
        let image: UIImage
    }

    @State private var current: Shown?
    /// The photo before, under the current one while it fades in
    @State private var previous: Shown?

    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var photos: [TopicPhoto] {
        var urls: Set<URL> = []
        return (feed.posts.isEmpty ? [page.post] : feed.posts)
            .compactMap { post -> TopicPhoto? in
                guard let link = post.link,
                      let url = link.imageURL.flatMap(URL.init(string:)),
                      urls.insert(url).inserted else { return nil }
                return TopicPhoto(url: url, source: link.source, timeAgo: post.timeAgoString)
            }
            .prefix(Self.photoCount)
            .map { $0 }
    }

    var body: some View {
        page.topic.pageColor
            .overlay {
                if let previous {
                    photo(previous.image)
                }
            }
            .overlay {
                if let current {
                    photo(current.image)
                        .id(current.photo)
                        .transition(.opacity)
                }
            }
            .overlay(alignment: .topTrailing) {
                if let current {
                    TopicPhotoCredit(photo: current.photo)
                }
            }
            .clipped()
            // Starts again from the photo showing when the topic's posts arrive
            .task(id: photos) {
                await show(photos)
            }
    }

    private func photo(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
    }

    private func show(_ photos: [TopicPhoto]) async {
        guard !photos.isEmpty else { return }
        var index = photos.firstIndex { $0 == current?.photo } ?? 0
        while !Task.isCancelled {
            let photo = photos[index]
            // News photos, so trimmed of the edge some publishers bake in, as in link cards
            let request = ImageRequest(url: photo.url, pointSize: nil, scale: displayScale, trimsEdges: true)
            if let image = await ImagePipeline.shared.image(for: request), !Task.isCancelled, current?.photo != photo {
                withAnimation(current == nil ? ProfileView.imageFadeIn : Self.crossfade) {
                    previous = current
                    current = Shown(photo: photo, image: image)
                }
            }
            guard !reduceMotion, photos.count > 1 else { return }
            try? await Task.sleep(for: Self.hold)
            index = (index + 1) % photos.count
        }
    }
}

/// The credit for the photo showing, at the top right: its publisher and how long ago its story was posted. Its
/// capitals are centered on the close button's middle at full height, and its ink ends a margin from the edge.
private struct TopicPhotoCredit: View {
    let photo: TopicPhoto

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize))
        let font = UIFont.roundedSystemFont(.footnote, weight: .semibold, compatibleWith: traits)
        let text = "\(photo.source) \u{00B7} \(photo.timeAgo)"
        let middle = ProfileGeometry.closeButtonTop + ProfileGeometry.closeButtonSize / 2
        Text(text)
            .font(.footnote)
            .fontWeight(.semibold)
            .foregroundStyle(.white.opacity(0.85))
            .lineLimit(1)
            // Legible on the photo's brightest skies, where the wallpaper isn't darkened
            .shadow(color: .black.opacity(0.35), radius: 6)
            // Changes with the photo: the old credit fades out, then the new one in, as two texts in one place
            // crossfaded read as neither
            .id(photo)
            .transition(.asymmetric(
                insertion: .opacity.animation(.easeOut(duration: 0.5).delay(0.7)),
                removal: .opacity.animation(.easeIn(duration: 0.5))
            ))
            .offset(x: font.trailingSideBearing(of: text))
            .padding(.trailing, ProfileGeometry.margin)
            // Centered in a band from the top twice as deep as the close button's middle: the font centers its
            // capitals in its line, so they center on that middle
            .frame(height: middle * 2)
    }
}
