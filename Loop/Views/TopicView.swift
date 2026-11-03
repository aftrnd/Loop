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

/// A topic's page, laid out like a profile without the avatar: the topic's name and the line under it on a wallpaper of
/// its latest stories' photos, which move on by themselves and swipe, with the headline of the one showing, Follow in
/// Liquid Glass at the card's foot, and the topic's latest posts on the page at full height.
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

    /// The wallpaper's photo showing, nil for the first
    @State private var shownPhoto: TopicPhoto?

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
    ///   known, which opens it at a profile card's height and leaves out the bottom safe area
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

    /// The wallpaper with the topic's name and line, and Follow under them, a part spacing apart.
    private var header: some View {
        TopicHeaderLayout(page: page, feed: feedViewModel, shownPhoto: shownPhoto) {
            followButton
                .modifier(SheetExpansionHeight(
                    metrics: sheetMetrics,
                    minimumHeight: collapsedHeight,
                    isFullyExpanded: isSheetFullyExpanded,
                    collapsed: ProfileGeometry.cardActionHeight,
                    expanded: ProfileGeometry.fullHeightActionHeight
                ))
        }
        // The wallpaper always renders dark, like a contact poster, and so do the type and the glass on it
        .environment(\.colorScheme, .dark)
        .padding(.horizontal, ProfileGeometry.margin)
        // The wallpaper ends as far below Follow as it sits from the sides, so on the card it stays concentric with
        // the sheet's corners
        .padding(.bottom, ProfileGeometry.part)
        .foregroundStyle(.white)
        .background {
            // Darkest from Follow's top down, a part spacing below the text, as a profile's is from a part spacing
            // below its avatar
            let heroHeight = cardHeight - ProfileGeometry.part - ProfileGeometry.cardActionHeight
            // Its photos swipe
            ProfileBackdrop(
                cardHeight: cardHeight,
                heroHeight: heroHeight,
                shade: page.topic.pageColor,
                isInteractive: true
            ) {
                TopicWallpaper(page: page, feed: feedViewModel, shown: $shownPhoto)
            }
            // On under the page's rounded corners
            .padding(.bottom, -ProfileGeometry.wallpaperReach)
        }
        // Nothing in the header sits on the sheet's glass, so nothing in it is vibrant
        .environment(\.backgroundMaterial, nil)
    }

    // MARK: - Follow

    /// Follow in clear Liquid Glass with a white label, the glass made for controls on photos, which the wallpaper's
    /// shade keeps legible. Following stays on the same glass with its own symbol and title. Its label shows once
    /// whether you follow it is known, so it never flips from Follow to Following as the page opens.
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
                .foregroundStyle(.white)
                .opacity(self.isFollowing == nil ? 0 : 1)
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.glass(.clear))
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
    /// The card's detent, worked out before the sheet is presented with the same header layout the card shows, Follow
    /// standing in at its card height, so the sheet opens at its final height.
    static func collapsedHeight(for page: TopicPage, in context: ProfileLayoutContext) -> CGFloat {
        let contentWidth = context.width - ProfileGeometry.margin * 2
        let header = TopicHeaderLayout(page: page, feed: nil, shownPhoto: nil) {
            Color.clear
                .frame(height: ProfileGeometry.cardActionHeight)
        }
        // The app's type, which the sheet inherits from the root
        .fontDesign(.rounded)
        .environment(\.dynamicTypeSize, context.dynamicTypeSize)
        .environment(\.legibilityWeight, context.legibilityWeight)
        .environment(\.displayScale, context.displayScale)
        let headerHeight = UIHostingController(rootView: header)
            .sizeThatFits(in: CGSize(width: contentWidth, height: .greatestFiniteMagnitude))
            .height
        return headerHeight + ProfileGeometry.part - context.bottomInset
    }
}

// MARK: - Topic Text

/// The topic's name a part spacing below the close button, as a profile's avatar is, the line under it, then the
/// headline of the story on the wallpaper, a dot for each photo, and Follow, each a part spacing below the last. News
/// topics set the name in New York, as their posts' headlines are. A view of its own so the card's height, its detent,
/// can be worked out with the same layout before the sheet opens.
private struct TopicHeaderLayout<Follow: View>: View {
    let page: TopicPage
    /// The topic's posts, once they load; until then the lines come from the post the page was opened from
    let feed: ProfileFeedViewModel?
    let shownPhoto: TopicPhoto?
    @ViewBuilder let follow: Follow

    var body: some View {
        let photos = TopicPhoto.latest(for: page, feed: feed)
        // The one showing, or the first when the topic's posts arrive without it
        let index = photos.firstIndex { $0 == shownPhoto } ?? 0
        BaselineSpacedVStack(spacing: ProfileGeometry.part) {
            // Stands in for the close button at full height, which the card keeps room for so the text doesn't move
            // as the sheet expands
            Color.clear
                .frame(height: ProfileGeometry.closeButtonTop + ProfileGeometry.closeButtonSize)

            ProfileNameBlock(name: page.name, isSerif: page.topic.isArticle, lines: TopicLines(page: page, feed: feed))
                .modifier(TopicTypeShadow())
                // A swipe across the type pages the photos behind it
                .allowsHitTesting(false)

            TopicStoryLink(page: page, photo: photos.indices.contains(index) ? photos[index] : nil)
                .modifier(TopicTypeShadow())

            TopicPageDots(count: photos.count, index: index)
                .modifier(TopicTypeShadow())

            follow
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

/// The headline of the story whose photo the wallpaper shows, which changes as the photos are swiped and opens the
/// story. Set as the topic's posts set their headlines: New York for news topics, the link card's headline for the
/// rest. It always takes two lines, so the card is as tall whatever the headline.
private struct TopicStoryLink: View {
    let page: TopicPage
    /// The photo showing, nil when the topic has none
    let photo: TopicPhoto?

    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    // The serif is set as a fixed size, as in NewsArticle, so it scales with Dynamic Type itself
    @ScaledMetric(relativeTo: .headline) private var serifSize: CGFloat = 17

    var body: some View {
        let isSerif = page.topic.isArticle
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize))
        let font = isSerif
            ? UIFont.serifSystemFont(ofSize: serifSize, weight: .semibold)
            : UIFont.roundedSystemFont(.headline, weight: .semibold, compatibleWith: traits)
        let title = photo?.title ?? ""
        // An arrow for a link that leaves the app, quieter than the headline, as on the feed's link cards
        let arrow = Text(Image(systemName: "arrow.up.right")).foregroundStyle(.white.opacity(0.6))
        Button {
            if let url = photo?.articleURL {
                openURL(url)
            }
        } label: {
            // Changes with the photo as the credit does: the old headline fades out, then the new one in
            ZStack(alignment: .topLeading) {
                styled(Text("\(Text(title))  \(arrow)"))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2, reservesSpace: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // Its ink starts where the name's does, whatever its first letter
                    .offset(x: -font.leadingSideBearing(of: title))
                    .id(photo)
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.easeOut(duration: 0.5).delay(0.7)),
                        removal: .opacity.animation(.easeIn(duration: 0.5))
                    ))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.98))
        .opacity(photo == nil ? 0 : 1)
        .visibleTopAtCapHeight(of: font)
        // It visibly ends at its second line's baseline even when the headline takes one, so Follow doesn't move as
        // the photos change: the two lines it reserves are each half its height
        .alignmentGuide(.visibleBottom) { $0[.firstTextBaseline] + $0.height / 2 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isLink)
        .accessibilityHidden(photo == nil)
    }

    private func styled(_ text: Text) -> Text {
        page.topic.isArticle
            ? text.font(.system(size: serifSize, weight: .semibold)).fontDesign(.serif)
            : text.font(.headline)
    }
}

/// A dot for each photo on the wallpaper, the one showing brightest, centered above Follow. The line is always there,
/// its dots drawn once there is more than one photo, so the card is as tall before the topic's posts load as after.
private struct TopicPageDots: View {
    let count: Int
    let index: Int

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize))
        // As tall as the lowercase of the credit, the wallpaper's smallest type, and a dot apart
        let dot = UIFont.roundedSystemFont(.footnote, weight: .semibold, compatibleWith: traits).xHeight
        HStack(spacing: dot) {
            ForEach(0..<count, id: \.self) { page in
                Circle()
                    .opacity(page == index ? 1 : 0.4)
                    .frame(width: dot, height: dot)
            }
        }
        .frame(height: dot)
        .frame(maxWidth: .infinity)
        .foregroundStyle(.white.opacity(0.85))
        .opacity(count > 1 ? 1 : 0)
        .animation(.easeInOut(duration: 0.25), value: index)
        .animation(.easeOut(duration: 0.3), value: count > 1)
        .accessibilityHidden(true)
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

/// A soft shadow under the white type on the wallpaper, so it holds on the photos' brightest parts, where the shade is
/// lightest or none: faint and wide, with no offset, so it darkens around the letters without an edge
private struct TopicTypeShadow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: .black.opacity(0.35), radius: 6)
    }
}

/// A story photo the wallpaper shows, with what its credit says. Sendable, as a scroll position's id
private nonisolated struct TopicPhoto: Hashable, Sendable {
    let url: URL
    let source: String
    let timeAgo: String
    /// The publisher's headline, and the story it opens
    let title: String
    let articleURL: URL?

    /// How many of the latest stories the wallpaper shows
    private static let limit = 3

    /// The photos of the topic's latest stories, newest first, or of the post the page was opened from until the
    /// topic's posts load
    @MainActor
    static func latest(for page: TopicPage, feed: ProfileFeedViewModel?) -> [TopicPhoto] {
        let loaded = feed?.posts ?? []
        var urls: Set<URL> = []
        return (loaded.isEmpty ? [page.post] : loaded)
            .compactMap { post -> TopicPhoto? in
                guard let link = post.link,
                      let url = link.imageURL.flatMap(URL.init(string:)),
                      urls.insert(url).inserted else { return nil }
                return TopicPhoto(
                    url: url,
                    source: link.source,
                    timeAgo: post.timeAgoString,
                    title: link.title,
                    articleURL: URL(string: link.url)
                )
            }
            .prefix(limit)
            .map { $0 }
    }
}

/// A topic's wallpaper: its latest stories' photos in full color, side by side to swipe through, each on the topic's
/// color until it has loaded. It moves on to the next photo by itself a few seconds after the last change, unless it is
/// being swiped or motion is reduced. The post the page was opened from stands in until the topic's posts load.
private struct TopicWallpaper: View {
    let page: TopicPage
    let feed: ProfileFeedViewModel
    /// The photo showing, nil for the first
    @Binding var shown: TopicPhoto?

    /// How long each photo shows before the next slides in
    private static let hold: Duration = .seconds(3)
    private static let slide = Animation.smooth(duration: 0.8)

    /// Where the photos are scrolled to. Moving on sets it; under a finger, `shown` follows the photo most in view.
    /// Bound to `shown` instead, the scroll view wrote the photo it was leaving back into it while it slid, and the
    /// dots and the headline flipped back until it landed
    @State private var position = ScrollPosition(idType: TopicPhoto.self)
    /// Whether the photos are moving, under a finger or settling; the next photo waits until they stop
    @State private var isScrolling = false
    /// Set while it moves on by itself, so the dots and the headline change once, to the photo it is going to, rather
    /// than to each photo it slides past going back to the first
    @State private var isAdvancing = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Advance: Hashable {
        let shown: TopicPhoto?
        let photos: [TopicPhoto]
        let isScrolling: Bool
    }

    var body: some View {
        let photos = TopicPhoto.latest(for: page, feed: feed)
        // The one swiped to, or the first when the topic's posts arrive without it
        let index = photos.firstIndex { $0 == shown } ?? 0
        // Each photo is the size the wallpaper is given. A horizontal scroll view is as tall as its content, and
        // photos sized relative to it came out 656pt tall on a 308pt card (iOS 27.2), centered past its top
        GeometryReader { proxy in
            ScrollView(.horizontal) {
                // Not lazy, so every photo loads before it is swiped to
                HStack(spacing: 0) {
                    ForEach(photos, id: \.self) { photo in
                        CachedAsyncImage(url: photo.url, trimsEdges: true, fadeIn: ProfileView.imageFadeIn) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            page.topic.pageColor
                        }
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition($position)
            .onScrollTargetVisibilityChange(idType: TopicPhoto.self, threshold: 0.5) { visible in
                if !isAdvancing, let photo = visible.first {
                    shown = photo
                }
            }
            .scrollIndicators(.hidden)
            // One photo stays put rather than bouncing
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .onScrollPhaseChange { _, phase in
                isScrolling = phase != .idle
                // Landed, or taken over by a finger
                if phase == .idle || phase == .interacting {
                    isAdvancing = false
                }
            }
        }
        .background(page.topic.pageColor)
        // Starts the wait again whenever the photo changes, by hand or by itself, and when the photos stop moving
        .task(id: Advance(shown: shown, photos: photos, isScrolling: isScrolling)) {
            guard !isScrolling, !reduceMotion, photos.count > 1 else { return }
            try? await Task.sleep(for: Self.hold)
            guard !Task.isCancelled else { return }
            // After the last, back to the first
            let next = photos[(index + 1) % photos.count]
            isAdvancing = true
            shown = next
            withAnimation(Self.slide) {
                position.scrollTo(id: next, anchor: .leading)
            }
        }
        .overlay(alignment: .topTrailing) {
            if photos.indices.contains(index) {
                TopicPhotoCredit(photo: photos[index])
                    .allowsHitTesting(false)
            }
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
            .modifier(TopicTypeShadow())
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
