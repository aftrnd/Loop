import SwiftUI
import FirebaseAuth
import os

struct ProfileView: View {
    // Optional userId - if nil, shows current user's profile (editable)
    // If provided, shows that user's profile (read-only)
    let userId: String?
    /// The signed-in user, read once per view value.
    private let currentUserId: String?
    /// Whether this is the signed-in user's own profile.
    private let isOwnProfile: Bool
    
    private static let logger = Logger(subsystem: "com.nejack.Loop", category: "ProfileView")
    
    @State private var currentUser: User?
    @State private var isLoading = false
    @State private var showEditProfile = false
    /// Bumped when Edit Profile closes, which re-runs the profile load.
    @State private var profileRevision = 0
    @State private var loadError: String?
    @Environment(\.dismiss) private var dismiss
    /// The sheet's glass, which makes secondary text vibrant on the card
    @Environment(\.backgroundMaterial) private var sheetMaterial
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.displayScale) private var displayScale
    /// Present when the app's root presented this profile, or a sheet it presented did
    @Environment(SheetRouter.self) private var sheetRouter: SheetRouter?
    
    // Follow system
    @State private var isFollowLoading = false
    /// Set to a new value to play the follow sparkle once.
    @State private var sparkleBurstID: UUID?
    /// A failed follow or message action, shown in an alert.
    @State private var actionError: String?
    
    // Message system
    @State private var isMessageLoading = false
    
    // Dynamic sheet height
    @State private var currentDetent: PresentationDetent = .height(ProfileView.loadingCardHeight)
    @State private var sheetMetrics = ProfileSheetMetrics()
    /// The header's width and where its buttons start on the card, from its latest layout at any width
    @State private var headerLayout = HeaderLayout()
    /// The hero's width and height, from its latest layout at any width
    @State private var heroLayout = HeroLayout()
    /// The content's width and the sheet's bottom safe area, from a layout pass with a real height
    @State private var contentMetrics = ContentMetrics()
    
    /// The sheet's bottom safe area at rest. While the sheet animates in it reports 0 and only then the real
    /// inset, which used to move the card a second time once it had settled, so the root's inset is preferred.
    private var sheetBottomInset: CGFloat {
        sheetRouter?.profileLayout?.bottomInset ?? contentMetrics.bottomInset
    }
    /// The collapsed height worked out before the sheet opened, used until the header is measured
    @State private var predictedCollapsedHeight: CGFloat?
    
    // Profile feed
    @State private var feedViewModel: ProfileFeedViewModel
    @State private var selectedTab: ProfileFeedTab = .posts
    /// How far the profile is scrolled. Only the full-height profile scrolls; the card always shows the header
    @State private var scrollPosition = ScrollPosition(edge: .top)
    
    // Navigation for messages
    @State private var navigationPath = NavigationPath()
    
    // Computed property to check if sheet is fully expanded
    private var isSheetFullyExpanded: Bool {
        currentDetent == .large
    }

    private var supportedDetents: Set<PresentationDetent> {
        let minDetent = PresentationDetent.height(minimumProfileHeight)
        if currentDetent == .large || currentDetent == minDetent {
            return [minDetent, .large]
        }
        return [minDetent, currentDetent, .large]
    }
    
    /// Fades the tabs and feed in with the sheet's expansion without making this body depend on the live height.
    private var expansionFade: SheetExpansionFade {
        SheetExpansionFade(
            metrics: sheetMetrics,
            minimumHeight: minimumProfileHeight,
            isFullyExpanded: isSheetFullyExpanded
        )
    }
    
    // Layout constants
    /// The header's coordinate space, where its parts are measured from
    private static let headerCoordinateSpace = "profileHeader"
    /// How the profile follows the sheet's height as it opens and closes
    private static let expansionAnimation = Animation.easeInOut(duration: 0.2)
    /// The card's height while the profile loads: about a card with a two-line bio (362.33pt on iPhone 18 Pro), so
    /// a typical profile barely moves once it appears
    private static let loadingCardHeight: CGFloat = 362
    /// Measured on iOS 27.2 at 3x, light and dark: the segmented control lays out 31pt tall and draws its 32pt
    /// track from its top, so the track visibly ends 1pt below its frame
    private static let segmentedTrackOverhang: CGFloat = 1
    
    /// Read from the profile's followers list, so the button and the follower count always agree.
    private var isFollowing: Bool {
        guard let currentUserId else { return false }
        return currentUser?.followers.contains(currentUserId) ?? false
    }
    
    /// The header's height on the card, from a layout at the sheet's real width, or 0 before there is one.
    /// Presenting a sheet first lays its content out at throwaway sizes (120pt wide and 0 tall in the simulator)
    /// where the bio wraps across many lines; measured there, the card opened far too tall.
    /// It counts from where the buttons start, which their height doesn't move, so their shorter full-height size
    /// never changes the detent mid-drag. Rounded up to whole pixels like the height worked out before the sheet
    /// opens (UIHostingController sizes to whole pixels), so the two agree and the open sheet doesn't move by a
    /// fraction of a point.
    private var cardHeaderHeight: CGFloat {
        guard contentMetrics.width > 0, abs(headerLayout.width - contentMetrics.width) < 0.5 else { return 0 }
        let height = headerLayout.actionsTop + ProfileGeometry.cardActionHeight + ProfileGeometry.part
        return (height * displayScale).rounded(.up) / displayScale
    }
    
    /// From the header's top to a part spacing below the avatar and the name beside it, where the bio starts. Until
    /// the hero has been laid out at the sheet's width, the height of a hero whose avatar is taller than its name.
    private var heroHeight: CGFloat {
        guard contentMetrics.width > 0, abs(heroLayout.width - contentMetrics.width) < 0.5 else {
            return ProfileGeometry.heroHeight
        }
        return heroLayout.height
    }
    
    /// The collapsed detent: the card ends exactly where its header does.
    private var minimumProfileHeight: CGFloat {
        if cardHeaderHeight > 0 {
            // A height detent sizes the area above the bottom safe area, and the header runs into it
            return cardHeaderHeight - sheetBottomInset
        }
        return predictedCollapsedHeight ?? Self.loadingCardHeight
    }
    
    /// Size and safe area of the frame the profile content fills.
    private nonisolated struct ContentMetrics: Equatable {
        var width: CGFloat = 0
        var bottomInset: CGFloat = 0
    }
    
    /// The header's width, and where its buttons start on the card, from its top.
    private nonisolated struct HeaderLayout: Equatable {
        var width: CGFloat = 0
        var actionsTop: CGFloat = 0
    }
    
    /// The header's width, and how far down its hero reaches.
    private nonisolated struct HeroLayout: Equatable {
        var width: CGFloat = 0
        var height: CGFloat = 0
    }
    
    /// - Parameter preview: The profile and its collapsed height, when they are known before the sheet opens.
    ///   The sheet then opens at its final height with the profile already showing, instead of opening at an
    ///   estimate and moving once the header has been measured.
    init(userId: String? = nil, preview: ProfilePreview? = nil) {
        self.userId = userId
        let currentUserId = Auth.auth().currentUser?.uid
        self.currentUserId = currentUserId
        let isOwnProfile = currentUserId != nil && (userId == nil || userId == currentUserId)
        self.isOwnProfile = isOwnProfile
        if let preview {
            _currentUser = State(initialValue: preview.user)
            _currentDetent = State(initialValue: .height(preview.collapsedHeight))
            _predictedCollapsedHeight = State(initialValue: preview.collapsedHeight)
        } else if userId != nil {
            // Start in loading state if we need to fetch a user
            _isLoading = State(initialValue: true)
        }
        // Initialize feed view model with the target user ID or current user
        let targetUserId = userId ?? currentUserId ?? ""
        _feedViewModel = State(initialValue: ProfileFeedViewModel(userId: targetUserId))
    }
    
    @ViewBuilder
    private var profileContent: some View {
        // Unified view structure - always the same, components fade in/out
        if let currentUser {
            profileMainContent(for: currentUser)
        } else if isLoading {
            loadingView
        } else if loadError != nil {
            errorView
        }
    }

    private func syncDetentIfNeeded() {
        let minDetent = PresentationDetent.height(minimumProfileHeight)
        guard currentDetent != .large else { return }
        if currentDetent != minDetent {
            currentDetent = minDetent
        }
    }
    
    private func profileMainContent(for user: User) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                profileHeader(for: user)
                
                // Tabs and feed, always rendered, fading in as the sheet opens on the page that rises over the
                // wallpaper's foot
                VStack(spacing: 0) {
                    feedPicker
                    
                    // Its own view, so feed updates don't re-render the header
                    ProfileFeedSection(viewModel: feedViewModel, selectedTab: selectedTab)
                }
                .modifier(expansionFade)
                .background {
                    ProfilePageBackground(
                        metrics: sheetMetrics,
                        minimumHeight: minimumProfileHeight,
                        isFullyExpanded: isSheetFullyExpanded
                    )
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollPosition($scrollPosition)
        // The card doesn't scroll: a drag on it resizes the sheet the way the grabber does, so the full-height profile
        // opens at its top. Drags the scroll view handled opened it 70pt down, with the banner cut off
        .scrollDisabled(!isSheetFullyExpanded)
        // The collapsed card runs into the bottom safe area, but while the sheet animates in its content area stops
        // above it and grows only once the sheet settles, so clipping cut off the bottom of Follow and Message for
        // the length of the animation. The collapsed card doesn't scroll; the full-height feed still clips
        .scrollClipDisabled(!isSheetFullyExpanded)
        .background(isSheetFullyExpanded ? Color(.systemBackground) : Color.clear)
        // The sheet only drops its glass once it has settled at full height, so text that is vibrant on the glass
        // changed color a beat after the profile turned opaque. It turns plain with the profile instead
        .environment(\.backgroundMaterial, isSheetFullyExpanded ? nil : sheetMaterial)
        .ignoresSafeArea(edges: .top)
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .padding(.top, 100)
            Text("Loading profile...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 400)
    }
    
    private var errorView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            Text("Failed to load profile")
                .font(.headline)
            Text(loadError ?? "Unknown error")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Retry") {
                Task {
                    await loadUser()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 400)
        .padding(.top, 100)
    }
    
    var body: some View {
        profileNavigationStack
    }

    private var profileNavigationStack: some View {
        // Read during the body so the alert appears when either source sets an error
        let errorMessage = actionError ?? feedViewModel.errorMessage
        
        return NavigationStack(path: $navigationPath) {
            profileGeometryContent
                .modifier(ProfileNavigationModifiers(
                    isSheetFullyExpanded: isSheetFullyExpanded,
                    dismissAction: { dismiss() }
                ))
                // Runs alongside the feed's task below, so the header and the feed load in parallel. Runs again
                // after Edit Profile closes, since that screen saves as you go
                .task(id: profileRevision) {
                    await loadUser()
                    // Posts carry their author's name and avatar; refresh them in place rather than refetching
                    if let currentUser {
                        feedViewModel.applyAuthor(currentUser)
                    }
                }
                .alert("Error", isPresented: errorAlertBinding(isPresented: errorMessage != nil)) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(errorMessage ?? "")
                }
                .presentationDetents(supportedDetents, selection: $currentDetent)
                .presentationDragIndicator(.visible)
                .onAppear {
                    syncDetentIfNeeded()
                }
                .onChange(of: minimumProfileHeight) { _, _ in
                    syncDetentIfNeeded()
                }
        }
        .sheet(isPresented: $showEditProfile, onDismiss: { profileRevision += 1 }) {
            EditProfileView(user: currentUser)
        }
    }
    
    private var profileGeometryContent: some View {
        profileContent
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            // The height changes on every frame of a sheet drag; only the SheetExpansion modifiers read it. The top
            // safe area is included, so the toolbar appearing at full height doesn't make the sheet look shorter.
            // Changed in one animated transaction, so the layout around the buttons (the wallpaper's foot, the tabs)
            // moves with them as they shrink; animated on their own, the card cut them off
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height + proxy.safeAreaInsets.top
            } action: { height in
                withAnimation(Self.expansionAnimation) {
                    sheetMetrics.height = height
                    if isSheetFullyExpanded {
                        sheetMetrics.recordFullHeight()
                    }
                }
            }
            // Only passes with a real height count. The inset is the fallback for `sheetBottomInset`, rounded
            // because it drifts by fractions of a point while the sheet animates; both rarely change, so this
            // rarely re-renders
            .onGeometryChange(for: ContentMetrics?.self) { proxy in
                guard proxy.size.height > 0 else { return nil }
                return ContentMetrics(width: proxy.size.width, bottomInset: proxy.safeAreaInsets.bottom.rounded())
            } action: { metrics in
                if let metrics {
                    contentMetrics = metrics
                }
            }
            .onChange(of: sheetRouter?.profileLayout?.height, initial: true) { _, height in
                sheetMetrics.expectedFullHeight = height
            }
            .onChange(of: isSheetFullyExpanded) { _, isExpanded in
                if isExpanded {
                    withAnimation(Self.expansionAnimation) {
                        sheetMetrics.recordFullHeight()
                    }
                } else {
                    // Collapsed from a scrolled feed, the card would show nothing: the header scrolled away and
                    // the feed faded out. Not animated on its own, which would build every feed row on the way up;
                    // it moves with the sheet as it settles
                    scrollPosition.scrollTo(edge: .top)
                }
            }
            // Loads each tab the first time it is shown; cancelled when the profile is dismissed
            .task(id: selectedTab) {
                await feedViewModel.load(selectedTab)
            }
    }
    
    // MARK: - Header
    
    /// The wallpaper with every part on it, at every height: the avatar, the name and handle, the bio, the counts and
    /// the buttons, a part spacing apart.
    private func profileHeader(for user: User) -> some View {
        // The hero ends a part spacing below the handle, where the bio starts
        BaselineSpacedVStack(spacing: 0) {
            profileHero(for: user)
            
            profilePage(for: user)
        }
        .padding(.horizontal, ProfileGeometry.margin)
        // The wallpaper ends as far below the buttons as they sit from its sides, so on the card they stay concentric
        // with its corners
        .padding(.bottom, ProfileGeometry.part)
        .background {
            ProfileBackdrop(
                bannerURL: user.bannerURL,
                cardHeight: cardHeaderHeight,
                heroHeight: heroHeight
            )
            // On under the page's rounded corners
            .padding(.bottom, -ProfileGeometry.wallpaperReach)
        }
        // Nothing in the header sits on the sheet's glass, so nothing in it is vibrant
        .environment(\.backgroundMaterial, nil)
        .coordinateSpace(.named(Self.headerCoordinateSpace))
    }
    
    /// The avatar, lit like an icon, on the left, and the name and handle beside it.
    private func profileHero(for user: User) -> some View {
        BaselineSpacedVStack(spacing: ProfileGeometry.part) {
            ProfileIdentityRow(user: user) {
                avatarView
                    .overlay {
                        ProfileAvatarRim()
                    }
                    .modifier(ProfileAvatarShadow())
            }
            
            // Where the bio starts
            Color.clear
                .frame(height: 0)
                .onGeometryChange(for: HeroLayout.self) { proxy in
                    let header = NamedCoordinateSpace.named(Self.headerCoordinateSpace)
                    return HeroLayout(width: proxy.bounds(of: header)?.width ?? 0, height: proxy.frame(in: header).minY)
                } action: { layout in
                    heroLayout = layout
                }
        }
        .padding(.top, ProfileGeometry.avatarTop)
        // The wallpaper always renders dark, like a contact poster
        .environment(\.colorScheme, .dark)
    }
    
    /// The bio, the counts and the buttons, in white type and white glass on the wallpaper.
    private func profilePage(for user: User) -> some View {
        BaselineSpacedVStack(spacing: ProfileGeometry.part) {
            ProfileDetails(user: user)
            
            profileActions
                .modifier(SheetExpansionHeight(
                    metrics: sheetMetrics,
                    minimumHeight: minimumProfileHeight,
                    isFullyExpanded: isSheetFullyExpanded,
                    collapsed: ProfileGeometry.cardActionHeight,
                    expanded: ProfileGeometry.fullHeightActionHeight
                ))
                // Sizes the card; `syncDetentIfNeeded` moves the sheet when its height changes. The buttons' top
                // doesn't move as they shorten with the sheet's expansion, so the card's height doesn't either
                .onGeometryChange(for: HeaderLayout.self) { proxy in
                    let header = NamedCoordinateSpace.named(Self.headerCoordinateSpace)
                    return HeaderLayout(width: proxy.bounds(of: header)?.width ?? 0, actionsTop: proxy.frame(in: header).minY)
                } action: { layout in
                    headerLayout = layout
                }
        }
        .foregroundStyle(.white)
        // White glass, with labels in black
        .tint(.white)
        .backgroundStyle(.black)
    }
    
    // MARK: - Avatar
    
    private var avatarView: some View {
        ZStack {
            if let avatarURL = currentUser?.avatarURL, let url = URL(string: avatarURL) {
                // Load from Firebase Storage URL with caching
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: ProfileGeometry.avatarSize, height: ProfileGeometry.avatarSize)
                        .clipShape(AvatarShape())
                } placeholder: {
                    ZStack {
                        AvatarShape()
                            .fill(Color(.systemGray5))
                            .frame(width: ProfileGeometry.avatarSize, height: ProfileGeometry.avatarSize)
                        
                        ProgressView()
                    }
                }
            } else {
                // Default initials view
                AvatarShape()
                    .fill(Color(.systemGray5))
                    .frame(width: ProfileGeometry.avatarSize, height: ProfileGeometry.avatarSize)
                
                Color.clear
                    .frame(width: ProfileGeometry.avatarSize, height: ProfileGeometry.avatarSize)
                    .glassEffect(.regular, in: AvatarShape())
                
                Text(userInitials)
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundColor(.primary)
            }
        }
        .frame(width: ProfileGeometry.avatarSize, height: ProfileGeometry.avatarSize)
        .accessibilityHidden(true)
    }
    
    // MARK: - Helper Properties
    
    private var userInitials: String {
        let displayName = currentUser?.displayName ?? ""
        
        guard !displayName.isEmpty else {
            return "?"
        }
        
        let components = displayName.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        } else if components.count == 1 {
            return String(displayName.prefix(2)).uppercased()
        }
        
        return "?"
    }
    
    // MARK: - Loading
    
    /// Loads the profile shown in the header with a single read. A profile already on screen stays in place
    /// while it refreshes, so the banner, feed and scroll position don't rebuild.
    private func loadUser() async {
        if currentUser == nil {
            isLoading = true
        }
        loadError = nil
        defer { isLoading = false }
        
        do {
            if let userId {
                if let user = try await FirebaseService.shared.getUser(withId: userId) {
                    currentUser = user
                } else if currentUser == nil {
                    loadError = "User not found"
                }
            } else if let firebaseUser = Auth.auth().currentUser {
                if let user = try await FirebaseService.shared.getUser(withId: firebaseUser.uid) {
                    currentUser = user
                } else {
                    Self.logger.info("Creating a profile for the signed-in user")
                    currentUser = try await FirebaseService.shared.createUserIfNotExists(
                        phoneNumber: firebaseUser.phoneNumber ?? "",
                        displayName: firebaseUser.displayName
                    )
                }
            } else {
                loadError = "Not authenticated"
            }
        } catch {
            Self.logger.error("Profile load failed: \(error.localizedDescription, privacy: .public)")
            if currentUser == nil {
                loadError = error.localizedDescription
            }
        }
    }
    
    // MARK: - Follow
    
    /// Follows or unfollows optimistically: the button, follower count and sparkle update on tap,
    /// and revert if the write fails.
    private func toggleFollow() async {
        guard let targetUserId = userId, let currentUserId, currentUser != nil, !isFollowLoading else { return }
        
        let wasFollowing = isFollowing
        isFollowLoading = true
        setFollowing(!wasFollowing, viewerId: currentUserId)
        if !wasFollowing {
            sparkleBurstID = UUID()
        }
        
        do {
            if wasFollowing {
                try await FirebaseService.shared.unfollowUser(targetUserId)
            } else {
                try await FirebaseService.shared.followUser(targetUserId)
            }
        } catch {
            Self.logger.error("Follow change failed: \(error.localizedDescription, privacy: .public)")
            setFollowing(wasFollowing, viewerId: currentUserId)
            actionError = wasFollowing ? "Couldn't unfollow. Please try again." : "Couldn't follow. Please try again."
            isFollowLoading = false
            return
        }
        isFollowLoading = false
        
        // Pick up other people's follows since the profile loaded, unless a newer tap has changed the state
        if let fresh = try? await FirebaseService.shared.getUser(withId: targetUserId),
           !isFollowLoading,
           fresh.followers.contains(currentUserId) == isFollowing {
            currentUser = fresh
        }
    }
    
    private func setFollowing(_ following: Bool, viewerId: String) {
        guard var user = currentUser, user.followers.contains(viewerId) != following else { return }
        if following {
            user.followers.append(viewerId)
        } else {
            user.followers.removeAll { $0 == viewerId }
        }
        currentUser = user
    }
    
    /// Presents follow, message and feed errors in one alert; dismissing it clears them all.
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
    
    // MARK: - Action Buttons
    
    /// Follow and Message on someone else's profile, Edit profile on your own. Their glass takes the page's white
    /// tint and their labels its black background style.
    private var profileActions: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                if isOwnProfile {
                    editButton
                } else {
                    followButton
                    messageButton
                }
            }
        }
    }
    
    private var followButton: some View {
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
            // Following is plain glass, so its label is in the type's color rather than cut from a tinted capsule
            .foregroundStyle(isFollowing ? AnyShapeStyle(.primary) : AnyShapeStyle(.background))
        }
        .frame(maxWidth: .infinity)
        // Not disabled while the follow saves: the glass would dim for the length of the write. toggleFollow
        // ignores taps until it finishes
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
    
    private var messageButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            Task {
                await startMessage()
            }
        } label: {
            ProfileActionLabel(symbol: "message.fill", title: "Message", isLoading: isMessageLoading)
                .foregroundStyle(.background)
        }
        .frame(maxWidth: .infinity)
        // Not disabled while the conversation opens, for the same reason as Follow; startMessage ignores taps
        .modifier(ProfileActionGlass(isProminent: true))
    }
    
    /// Your own profile edits where someone else's follows and messages
    private var editButton: some View {
        Button {
            showEditProfile = true
        } label: {
            ProfileActionLabel(symbol: "pencil", title: "Edit profile", isLoading: false)
                .foregroundStyle(.background)
        }
        .frame(maxWidth: .infinity)
        .modifier(ProfileActionGlass(isProminent: true))
    }
    
    private func startMessage() async {
        guard let targetUserId = userId, currentUserId != nil, !isMessageLoading else { return }
        
        // Use already-loaded user data rather than fetching it again
        let targetUser = currentUser
        let chatTitle = targetUser?.displayName ?? "User"
        
        isMessageLoading = true
        defer { isMessageLoading = false }
        
        do {
            // createChat already returns the existing chat with this user if there is one
            var chat = try await FirebaseService.shared.createChat(withUserId: targetUserId, title: chatTitle)
            
            // Fill in the other participant from the loaded profile
            chat = Chat(
                id: chat.id,
                title: chat.title,
                lastMessagePreview: chat.lastMessagePreview,
                unreadCount: chat.unreadCount,
                messages: chat.messages,
                lastMessageTime: chat.lastMessageTime,
                participants: chat.participants,
                otherParticipantId: targetUserId,
                otherParticipantDisplayName: targetUser?.displayName ?? chat.otherParticipantDisplayName,
                otherParticipantAvatarURL: targetUser?.avatarURL ?? chat.otherParticipantAvatarURL,
                otherParticipantBadgeType: targetUser?.badgeType ?? chat.otherParticipantBadgeType
            )
            
            navigationPath.append(ChatsRoute.conversation(chat))
        } catch {
            Self.logger.error("Opening a conversation failed: \(error.localizedDescription, privacy: .public)")
            actionError = "Couldn't open the conversation. Please try again."
        }
    }
    
    // MARK: - Tabs
    
    /// Posts, Media and Likes in the system's segmented control at its own height
    private var feedPicker: some View {
        Picker("Feed", selection: $selectedTab) {
            ForEach(ProfileFeedTab.allCases, id: \.self) { tab in
                Text(tab.rawValue)
                    .tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, ProfileGeometry.margin)
        // A part spacing below the wallpaper's edge
        .padding(.top, ProfileGeometry.part)
        // The first post's avatar starts a part spacing below the track, and 8pt inside its card
        .padding(.bottom, ProfileGeometry.part + Self.segmentedTrackOverhang - CardLayoutConstants.topPadding)
    }
}

// MARK: - Geometry

/// The profile's measurements, shared by the header and the card height worked out before the sheet opens.
private enum ProfileGeometry {
    /// The side inset, as in posts: 10pt list inset plus 10pt card padding
    static let margin: CGFloat = CardLayoutConstants.horizontalPadding * 2
    /// The space between the profile's parts, measured where they visibly end and start
    static let part: CGFloat = 20
    /// The name and the handle belong together: 12pt from the name's baseline to the handle's capitals
    static let nameToHandle: CGFloat = 12
    /// Twice the feed's 56pt avatar, as the name beside it is twice the feed's 17pt
    static let avatarSize: CGFloat = 2 * CardLayoutConstants.avatarSize
    /// At full height the close button is 44pt tall and 16pt below the sheet's top edge (iOS 27.2), and the avatar
    /// below it on the left starts a part spacing lower. The card keeps the same top, so the avatar, name and handle
    /// don't move as the sheet expands
    static let avatarTop: CGFloat = 16 + 44 + part
    /// The space between the avatar and the name beside it, as in the feed
    static let avatarToName: CGFloat = CardLayoutConstants.avatarSpacing
    /// The hero's height when the avatar is taller than the name and handle beside it: down to a part spacing below
    /// the avatar
    static let heroHeight: CGFloat = avatarTop + avatarSize + part
    /// Follow and Message on the card: 20pt in from the sheet's sides and bottom, capsules this tall are concentric
    /// with its 54pt corners (iPhone 18 Pro)
    static let cardActionHeight: CGFloat = 68
    /// At full height, twice the 32pt track of the segmented control below them (measured on iOS 27.2)
    static let fullHeightActionHeight: CGFloat = 64
    /// The page under the wallpaper rounds its top corners concentric with the segmented control's ends: their 16pt
    /// radius (half its 32pt track) and the part spacing it sits from the page's top and sides
    static let pageCornerRadius: CGFloat = 32 / 2 + part
    /// How far the wallpaper runs on under the page. A continuous corner's curve carries on down the side past its
    /// radius, so the wallpaper reaching only the radius ended in a flat cut inside the curve; twice the radius covers
    /// it
    static let wallpaperReach: CGFloat = pageCornerRadius * 2
}

/// The avatar's edge lit like a macOS 27 app icon's, so it reads on any wallpaper: a highlight inside the top edge
/// and its corners, a fainter one inside the bottom, none along the sides. Measured on the Messages icon rendered at
/// 1024px (an 824px tile): white at the top edge fading into the fill over 1.2% of the side, half as bright and half
/// as deep at the bottom.
private struct ProfileAvatarRim: View {
    /// How far the top highlight reaches in, 1.2% of the side: the inner half of a stroke this wide, softened by a
    /// third of it, stays white at the edge and is gone by this depth
    private static let depth = ProfileGeometry.avatarSize * 0.012
    
    var body: some View {
        // The corners stay lit down to where they meet the sides
        let corner = AvatarShape.cornerRatio
        // Stroked on the edge and clipped to the avatar, so only its inner half shows
        AvatarShape()
            .stroke(
                LinearGradient(
                    stops: [
                        .init(color: .white, location: 0),
                        .init(color: .white.opacity(0), location: corner),
                        .init(color: .white.opacity(0), location: 1 - corner),
                        .init(color: .white.opacity(0.5), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: Self.depth
            )
            .blur(radius: Self.depth / 3)
            .clipShape(AvatarShape())
            .allowsHitTesting(false)
    }
}

/// The soft shadow a macOS 27 app icon casts, scaled from the 824px tile measured at 1024px to the avatar: it reaches
/// about 3% of the side above, 4% to the sides and 5% below, 10% dark at the sides.
private struct ProfileAvatarShadow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(
                color: .black.opacity(0.25),
                radius: ProfileGeometry.avatarSize * 0.02,
                y: ProfileGeometry.avatarSize * 0.011
            )
    }
}

// MARK: - Action Buttons

/// Follow and Message in Liquid Glass, rendered like the toolbar's buttons: glass in the tint (white on the
/// wallpaper, ink on the page) for an action, plain glass once it is done (Following).
private struct ProfileActionGlass: ViewModifier {
    let isProminent: Bool

    func body(content: Content) -> some View {
        if isProminent {
            content
                .buttonStyle(.glassProminent)
        } else {
            content
                .buttonStyle(.glass)
        }
    }
}

/// A symbol and a title, as tall as the button. The symbol dims while the action is in flight.
private struct ProfileActionLabel: View {
    let symbol: String
    let title: String
    let isLoading: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .opacity(isLoading ? 0.5 : 1)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        // As tall as the row, which shortens as the sheet opens
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Profile Text

/// The avatar on the left and the name and handle beside it, centered on the avatar by where they visibly start and
/// end (the name's capitals and the handle's baseline). A view of its own so the card's height can be worked out
/// with the same layout before the sheet opens.
private struct ProfileIdentityRow<Avatar: View>: View {
    let user: User
    @ViewBuilder let avatar: Avatar
    
    var body: some View {
        HStack(spacing: ProfileGeometry.avatarToName) {
            avatar
                .frame(width: ProfileGeometry.avatarSize, height: ProfileGeometry.avatarSize)
            
            ProfileNameBlock(user: user)
                .alignmentGuide(VerticalAlignment.center) { ($0[.visibleTop] + $0[.visibleBottom]) / 2 }
        }
        // It visibly spans the avatar, which is taller than the lines beside it; the text inside doesn't change that
        .alignmentGuide(.visibleTop) { $0[.top] }
        .alignmentGuide(.visibleBottom) { $0[.bottom] }
    }
}

/// The name, and the handle line under it, beside the avatar: a post header's two lines. White, on the wallpaper.
private struct ProfileNameBlock: View {
    let user: User
    
    var body: some View {
        BaselineSpacedVStack(spacing: ProfileGeometry.nameToHandle) {
            Text(user.displayName ?? "Display Name")
                .font(.largeTitle)
                .fontWeight(.bold)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .visibleTopAtCapHeight(of: .largeTitle)
                .accessibilityAddTraits(.isHeader)
            
            ProfileHandleLine(user: user)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(.white)
    }
}

/// The handle and location, as one line under the name: a post's second line, in callout.
private struct ProfileHandleLine: View {
    let user: User
    
    private var handleAndLocation: String {
        let handle = "@\(user.username ?? "username")"
        guard let location = user.location, !location.isEmpty else { return handle }
        return "\(handle) \u{00B7} \(location)"
    }
    
    var body: some View {
        Text(handleAndLocation)
            .font(.callout)
            .foregroundStyle(.white.opacity(0.85))
            .lineLimit(1)
            .visibleTopAtCapHeight(of: .callout)
            .accessibilityLabel(handleAndLocation.replacingOccurrences(of: " \u{00B7} ", with: ", "))
    }
}

/// The verified seal, when there is one, and the year someone joined, each in black on a white squircle with the
/// avatar's corners, a quarter of a plate apart.
private struct ProfileBadges: View {
    let user: User
    let side: CGFloat
    
    private var joinedYear: Int {
        Calendar(identifier: .gregorian).component(.year, from: user.createdAt)
    }
    
    var body: some View {
        HStack(spacing: side / 4) {
            if let badgeType = user.badgeType {
                AvatarShape()
                    .fill(.white)
                    .frame(width: side, height: side)
                    .overlay {
                        // Fits the middle four sevenths of the plate, as the year's digits and the AI mark's symbol
                        // do, centered by its drawn bounds. The check shows the plate's white
                        Image(systemName: badgeType.iconName)
                            .resizable()
                            .scaledToFit()
                            .padding(side * 3 / 14)
                            .foregroundStyle(.black)
                    }
            }
            
            ProfileYearPlate(year: joinedYear, side: side)
        }
        // One element that reads the badges in words
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }
    
    private var accessibilityText: String {
        var parts: [String] = []
        switch user.badgeType {
        case .verified: parts.append("Verified")
        case .premium: parts.append("Premium")
        case nil: break
        }
        parts.append("Joined \(joinedYear)")
        return parts.joined(separator: ", ")
    }
}

/// The year someone joined in black on a white squircle with the avatar's 2/7 corners, two digits over two.
private struct ProfileYearPlate: View {
    let year: Int
    let side: CGFloat
    
    /// Two lines of capitals with a quarter of a capital between them fill the middle four sevenths of the plate, as
    /// the avatar's photo fills a tile
    private var capHeight: CGFloat { side * 4 / 7 / 2.25 }
    /// A heavy rounded face with tabular digits and those capitals, drawn and measured as the same font
    private var digitFont: UIFont {
        let probe = UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .heavy)
        let rounded = probe.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: 10) } ?? probe
        return rounded.withSize(10 * capHeight / rounded.capHeight)
    }
    
    private var lines: [String] {
        let digits = String(year)
        return [String(digits.prefix(2)), String(digits.suffix(2))]
    }
    
    var body: some View {
        let font = digitFont
        AvatarShape()
            .fill(.white)
            .frame(width: side, height: side)
            .overlay {
                BaselineSpacedVStack(spacing: capHeight / 4) {
                    // By position: a year like 2020 repeats its halves
                    ForEach(lines.indices, id: \.self) { index in
                        Text(lines[index])
                            .font(Font(font))
                            .visibleTopAtCapHeight(of: font)
                    }
                }
                .fixedSize()
                .offset(x: inkCentering(font))
                .foregroundStyle(.black)
            }
    }
    
    /// How far to move the digits so their ink, rather than their advances, is centered on the plate. Tabular digits
    /// leave more room after the last digit than before the first, which set "20 / 23" 0.5pt left of center.
    private func inkCentering(_ font: UIFont) -> CGFloat {
        var inkMinX = CGFloat.infinity
        var inkMaxX = -CGFloat.infinity
        var width: CGFloat = 0
        for text in lines {
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: font]))
            let ink = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
            inkMinX = min(inkMinX, ink.minX)
            inkMaxX = max(inkMaxX, ink.maxX)
            width = max(width, CTLineGetTypographicBounds(line, nil, nil, nil))
        }
        return width / 2 - (inkMinX + inkMaxX) / 2
    }
}

/// The bio, and the counts with the badges at the other end of their row. A view of its own so the card's height can
/// be worked out with the same layout before the sheet opens.
private struct ProfileDetails: View {
    let user: User
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var body: some View {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize))
        let countsCapHeight = UIFont.preferredFont(forTextStyle: .subheadline, compatibleWith: traits).capHeight
        // The badge plates are as tall as the name's capitals
        let plate = UIFont.preferredFont(forTextStyle: .largeTitle, compatibleWith: traits).capHeight
        BaselineSpacedVStack(spacing: ProfileGeometry.part) {
            if let bio = user.bio, !bio.isEmpty {
                Text(bio)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .visibleTopAtCapHeight(of: .callout)
            }
            
            HStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    count(user.followerCount, followersWord)
                    count(user.followingCount, "following")
                }
                // Read as one phrase rather than four words
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(user.followerCount) \(followersWord), \(user.followingCount) following")
                .font(.subheadline)
                // Its capitals centered on the plates
                .alignmentGuide(VerticalAlignment.center) { $0[.firstTextBaseline] - countsCapHeight / 2 }
                
                Spacer(minLength: ProfileGeometry.part)
                
                ProfileBadges(user: user, side: plate)
            }
            // The row visibly spans the plates, which reach past the counts' capitals and baseline
            .alignmentGuide(.visibleTop) { $0[VerticalAlignment.center] - plate / 2 }
            .alignmentGuide(.visibleBottom) { $0[VerticalAlignment.center] + plate / 2 }
        }
    }
    
    private var followersWord: String {
        user.followerCount == 1 ? "follower" : "followers"
    }
    
    /// The number in the type's color, the word quieter
    private func count(_ value: Int, _ label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("\(value)")
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            Text(label)
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}

// MARK: - Page

/// The page behind the tabs and the feed. Always opaque, so the sheet's glass never shows below the buttons as the
/// sheet opens, and its top corners round in from square on the card to the page corner radius at full height, in
/// step with the tabs fading in. Reads the live height, so per-frame updates stop here.
private struct ProfilePageBackground: View {
    let metrics: ProfileSheetMetrics
    let minimumHeight: CGFloat
    let isFullyExpanded: Bool
    
    var body: some View {
        let progress = metrics.expansionProgress(minimumHeight: minimumHeight, isFullyExpanded: isFullyExpanded)
        let radius = ProfileGeometry.pageCornerRadius * progress
        UnevenRoundedRectangle(topLeadingRadius: radius, topTrailingRadius: radius, style: .continuous)
            .fill(Color(.systemBackground))
    }
}

// MARK: - Wallpaper

/// The wallpaper behind the header, darkened a little toward its foot so white type stays legible. It is laid out at
/// the card's height, plus the reach it runs on under the page, in every detent, so it never re-crops as the sheet
/// opens. With no wallpaper, the dark gray it shows while loading stands in.
private struct ProfileBackdrop: View {
    let bannerURL: String?
    /// The card's header height, or 0 before it is measured, when the wallpaper fills the header
    let cardHeight: CGFloat
    let heroHeight: CGFloat
    
    var body: some View {
        Color.clear
            .overlay(alignment: .top) {
                wallpaper
                    .frame(height: cardHeight > 0 ? cardHeight + ProfileGeometry.wallpaperReach : nil)
            }
            .clipped()
            // The wallpaper always renders dark, like a contact poster
            .environment(\.colorScheme, .dark)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
    
    private var wallpaper: some View {
        Color(.systemGray5)
            .overlay {
                if let bannerURL, let url = URL(string: bannerURL) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.clear
                    }
                }
            }
            .overlay {
                ProfileWallpaperShade(heroHeight: heroHeight)
            }
    }
}

/// Darkens the wallpaper toward its foot just enough for white type: not at all above the avatar, so the photo there
/// stays as it is, then easing in beside the avatar, under the name and handle, to its strongest where the bio starts
/// (the hero's foot), and holding there behind the bio, the counts and the buttons. Eased rather than linear, so no
/// edge shows where it begins.
private struct ProfileWallpaperShade: View {
    let heroHeight: CGFloat
    
    /// The darkest it gets, behind the smaller type
    private static let strongest = 0.45
    
    var body: some View {
        GeometryReader { proxy in
            let height = max(proxy.size.height, 1)
            let start = ProfileGeometry.avatarTop
            let end = max(heroHeight, start + 1)
            // A smoothstep from clear to the strongest, in eight steps
            let stops = (0...8).map { step in
                let t = CGFloat(step) / 8
                let eased = t * t * (3 - 2 * t)
                return Gradient.Stop(
                    color: .black.opacity(Self.strongest * eased),
                    location: min((start + (end - start) * t) / height, 1)
                )
            }
            LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
        }
    }
}

// MARK: - Collapsed Height

/// The width and text settings profile sheets are laid out with, taken from the app's root view.
struct ProfileLayoutContext: Equatable {
    var width: CGFloat
    /// The root's height between its safe areas, which is the profile's height at the large detent
    var height: CGFloat
    /// The sheet's bottom safe area, which a height detent doesn't include
    var bottomInset: CGFloat
    var dynamicTypeSize: DynamicTypeSize
    var legibilityWeight: LegibilityWeight?
    var displayScale: CGFloat
}

/// A profile to open with its collapsed card height already worked out.
struct ProfilePreview {
    let user: User
    let collapsedHeight: CGFloat
}

extension ProfileView {
    /// A profile's collapsed card height (the detent), worked out before the sheet is presented. Lays out the
    /// same identity row and details the card shows; the avatar and the buttons stand in as fixed sizes. Must match
    /// `profileHeader`: the live header measurement corrects any difference, but only after the sheet has opened,
    /// as a visible jump.
    static func collapsedCardHeight(for user: User, in context: ProfileLayoutContext) -> CGFloat {
        let contentWidth = context.width - ProfileGeometry.margin * 2
        let header = BaselineSpacedVStack(spacing: ProfileGeometry.part) {
            ProfileIdentityRow(user: user) {
                Color.clear
            }
            ProfileDetails(user: user)
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
        
        // The avatar's distance from the top, and the bottom padding that matches the side inset
        return ProfileGeometry.avatarTop + headerHeight + ProfileGeometry.part - context.bottomInset
    }
}

// MARK: - Feed

/// The posts, photos or likes under the header. Reading the view model here rather than in ProfileView keeps
/// feed loads and like changes from re-rendering the banner and header.
private struct ProfileFeedSection: View {
    let viewModel: ProfileFeedViewModel
    let selectedTab: ProfileFeedTab
    
    @AppStorage("showLayoutDebugOverlays") private var showLayoutDebugOverlays = false
    
    var body: some View {
        switch selectedTab {
        case .posts:
            feed(loops: viewModel.posts, isLoading: viewModel.isLoadingPosts)
        case .media:
            feed(loops: viewModel.mediaPosts, isLoading: viewModel.isLoadingPosts)
        case .likes:
            feed(loops: viewModel.likedPosts, isLoading: viewModel.isLoadingLikes)
        }
    }
    
    private var emptySymbol: String {
        switch selectedTab {
        case .posts: "square.and.pencil"
        case .media: "photo"
        case .likes: "heart"
        }
    }
    
    private var emptyTitle: String {
        switch selectedTab {
        case .posts: "No posts yet"
        case .media: "No media yet"
        case .likes: "No likes yet"
        }
    }
    
    private func feed(loops: [Loop], isLoading: Bool) -> some View {
        Group {
            if isLoading && loops.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .padding(.top, 50)
            } else if loops.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: emptySymbol)
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text(emptyTitle)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .padding(.top, 50)
            } else {
                let firstLoopId = loops.first?.id
                let lastLoopId = loops.last?.id
                
                LazyVStack(spacing: 0) {
                    ForEach(loops) { loop in
                        let isFirst = loop.id == firstLoopId
                        let isLast = loop.id == lastLoopId
                        
                        // Spaced like the home feed: the divider and the next avatar a part spacing apart
                        BaselineSpacedVStack(spacing: CardLayoutConstants.partSpacing) {
                            PostCard(
                                loop: loop,
                                isLiked: viewModel.isLikedByCurrentUser(loop),
                                onLike: {
                                    Task {
                                        await viewModel.toggleLike(for: loop)
                                    }
                                },
                                onComment: {
                                    // Handle comment tap
                                },
                                onDelete: viewModel.canDeleteLoop(loop) ? {
                                    Task {
                                        await viewModel.deleteLoop(loop)
                                    }
                                } : nil,
                                onAvatarTap: nil,
                                showDebugOverlays: showLayoutDebugOverlays
                            )
                            .padding(.horizontal, 10)
                            .padding(.top, isFirst ? 0 : CardLayoutConstants.partSpacing - CardLayoutConstants.topPadding)
                            
                            if !isLast {
                                PostDivider()
                            }
                        }
                        // Like bursts fly out of the post and land on its divider
                        .likeBurstLayer()
                    }
                }
            }
        }
    }
}

// MARK: - Sheet Expansion

/// The live height of the profile's content area. It changes on every frame of a sheet drag, so only
/// the SheetExpansion modifiers read it, and the rest of the profile doesn't re-render while the sheet moves.
@Observable
private final class ProfileSheetMetrics {
    var height: CGFloat = 0
    /// The sheet's height at the large detent, once it has been there. The tallest height seen, so dragging
    /// down from full height still fades.
    private(set) var fullHeight: CGFloat?
    /// The large detent's height from the app's root, for the first expansion
    var expectedFullHeight: CGFloat?
    
    func recordFullHeight() {
        fullHeight = max(fullHeight ?? 0, height)
    }
    
    /// How far the sheet has opened: 0 up to halfway between the minimum detent and full height, 1 from 80%.
    /// Before the first measurement it falls back to the detent state.
    func expansionProgress(minimumHeight: CGFloat, isFullyExpanded: Bool) -> CGFloat {
        guard height > 0 else { return isFullyExpanded ? 1 : 0 }
        guard height > minimumHeight else { return 0 }
        // Until the sheet has been fully expanded, the root's height, or an estimate without one. With the estimate
        // (900pt against 778 on iPhone 18 Pro) a finger held at the top left everything that follows this progress
        // short of its full-height state until release
        let maxHeight = fullHeight ?? expectedFullHeight ?? 900
        let range = maxHeight - minimumHeight
        guard range > 0 else { return 1 }
        let progress = min(max((height - minimumHeight) / range, 0), 1)
        return max(0, min(1, (progress - 0.5) / 0.3))
    }
}

/// Fades the tabs and feed in as the sheet opens, taking touches once mostly visible. The live height is read
/// here, so per-frame updates during a drag stop at this modifier instead of re-running ProfileView's body.
private struct SheetExpansionFade: ViewModifier {
    let metrics: ProfileSheetMetrics
    let minimumHeight: CGFloat
    let isFullyExpanded: Bool
    
    func body(content: Content) -> some View {
        let progress = metrics.expansionProgress(minimumHeight: minimumHeight, isFullyExpanded: isFullyExpanded)
        
        content
            .opacity(progress)
            .animation(.easeInOut(duration: 0.2), value: progress)
            .allowsHitTesting(progress > 0.5)
    }
}

/// Sizes a view between its card and full-height heights as the sheet opens or closes, in step with the tabs
/// fading in, so it follows the finger and is exactly one or the other whenever the sheet rests. Like
/// `SheetExpansionFade`, it reads the live height so per-frame updates stop here. It has no animation of its own:
/// the transaction that changes the height animates it together with the layout around it.
private struct SheetExpansionHeight: ViewModifier {
    let metrics: ProfileSheetMetrics
    let minimumHeight: CGFloat
    let isFullyExpanded: Bool
    let collapsed: CGFloat
    let expanded: CGFloat
    
    func body(content: Content) -> some View {
        let progress = metrics.expansionProgress(minimumHeight: minimumHeight, isFullyExpanded: isFullyExpanded)
        
        content
            .frame(height: collapsed + (expanded - collapsed) * progress)
    }
}

// MARK: - View Modifiers to reduce type-checking complexity

private struct ProfileNavigationModifiers: ViewModifier {
    let isSheetFullyExpanded: Bool
    let dismissAction: () -> Void
    
    func body(content: Content) -> some View {
        content
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isSheetFullyExpanded {
                        Button(action: dismissAction) {
                            Image(systemName: "xmark")
                                .font(.body.weight(.medium))
                        }
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
            .navigationDestination(for: ChatsRoute.self) { route in
                switch route {
                case .conversation(let chat):
                    ConversationView(chat: chat)
                }
            }
    }
}

#Preview {
    ProfileView()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
}
