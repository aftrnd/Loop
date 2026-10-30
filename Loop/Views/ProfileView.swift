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
    
    // Debug settings
    @AppStorage("showLayoutDebugOverlays") private var showLayoutDebugOverlays = false
    
    // Follow system
    @State private var isFollowLoading = false
    /// Set to a new value to play the follow sparkle once.
    @State private var sparkleBurstID: UUID?
    /// A failed follow or message action, shown in an alert.
    @State private var actionError: String?
    
    // Message system
    @State private var isMessageLoading = false
    
    // Dynamic sheet height
    @State private var currentDetent: PresentationDetent = .height(366)
    @State private var sheetMetrics = ProfileSheetMetrics()
    @State private var containerMetrics = ContainerMetrics()
    @State private var otherProfileHeaderHeight: CGFloat = 0
    @State private var ownershipHintOpacity: Double = 0
    @State private var ownershipHintMeasuredHeight: CGFloat = 0
    
    // Profile feed
    @State private var feedViewModel: ProfileFeedViewModel
    @State private var selectedTab: ProfileFeedTab = .posts
    
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
    
    /// Fades a part of the profile with the sheet's expansion without making this body depend on the live height.
    private func expansionFade(_ style: SheetExpansionFade.Style) -> SheetExpansionFade {
        SheetExpansionFade(
            metrics: sheetMetrics,
            minimumHeight: expansionBaselineHeight,
            isFullyExpanded: isSheetFullyExpanded,
            style: style
        )
    }
    
    /// Size and top safe area of the frame the profile content fills.
    private nonisolated struct ContainerMetrics: Equatable {
        var width: CGFloat = 0
        var topSafeAreaInset: CGFloat = 0
    }
    
    // Layout constants
    private let avatarImageSize: CGFloat = 100
    private let avatarSpacing: CGFloat = 6 // Spacing around avatar for mask (reduced from 8pt for tighter mask)
    private var avatarMaskSize: CGFloat { avatarImageSize + (avatarSpacing * 2) } // 112pt: avatar + 6pt spacing on each side
    // Match post card padding: 10pt list inset + 10pt card padding = 20pt total
    private let profileContentPadding: CGFloat = CardLayoutConstants.horizontalPadding + 10 // 20pt total (matches posts)
    private var avatarOverlapOffset: CGFloat { -(avatarMaskSize / 2) } // -56pt: half of mask size to center overlap
    private var profileCardBottomPadding: CGFloat { CardLayoutConstants.bottomPadding }
    private var actionButtonCornerRadius: CGFloat { 26 } // Half the button height (52/2) for perfect capsule shape with circular ends
    private var ownershipHintHeight: CGFloat {
        if ownershipHintMeasuredHeight > 0 {
            return ownershipHintMeasuredHeight
        }
        return CardLayoutConstants.topPadding + profileCardBottomPadding + 24
    }
    private var tabTopPadding: CGFloat {
        !isOwnProfile ? CardLayoutConstants.headerBottomSpacing : 0
    }
    
    private var tabBottomPadding: CGFloat {
        // Add bottom padding for ALL profiles (both own and others)
        CardLayoutConstants.headerBottomSpacing
    }
    private var shouldShowOwnershipHint: Bool {
        isOwnProfile && !isSheetFullyExpanded
    }
    
    /// Read from the profile's followers list, so the button and the follower count always agree.
    private var isFollowing: Bool {
        guard let currentUserId else { return false }
        return currentUser?.followers.contains(currentUserId) ?? false
    }
    
    // Date formatter for joined date (Month Year format), built once rather than on every render
    private static let joinedDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter
    }()
    
    // Calculate baseline minimum height needed for profile content
    private var baseProfileHeight: CGFloat {
        let bannerHeight: CGFloat = 180
        let avatarSection: CGFloat = 30 // Avatar overlap area (reduced)
        let nameHeight: CGFloat = 28 // Display name
        let usernameHeight: CGFloat = 18 // Username/location line
        let followersHeight: CGFloat = 18 // Followers/following line
        let bioMinHeight: CGFloat = 44 // Minimum 2 lines for bio
        let actionButtonsHeight: CGFloat = 50 // Follow/Message buttons (only for other users' profiles)
        let spacing: CGFloat = 8 * 3 // 3 gaps of 8px each
        let spacingAfterBio: CGFloat = 12 // Spacing after bio before action buttons
        let padding: CGFloat = 24 // Reduced bottom padding
        
        // Include action buttons height when viewing someone else's profile
        // Use isOwnProfile (which works with userId) to avoid sheet resizing when currentUser loads
        let buttonsHeight = !isOwnProfile ? actionButtonsHeight + spacingAfterBio : 0
        
        return bannerHeight + avatarSection + nameHeight + usernameHeight + followersHeight + bioMinHeight + buttonsHeight + spacing + padding
    }
    
    /// The collapsed detent. On your own profile it always leaves room for the ownership hint, even while
    /// fully expanded, so collapsing settles once instead of stopping short and then growing as the hint appears.
    private var minimumProfileHeight: CGFloat {
        if isOwnProfile {
            return baseProfileHeight + ownershipHintHeight
        }
        
        if otherProfileHeaderHeight > 0 {
            return otherProfileHeaderHeight
        }
        
        return baseProfileHeight
    }
    
    /// Where the tabs and feed start fading in. While your own profile is fully expanded this leaves out the
    /// hidden ownership hint, as it always has, so the fade timing doesn't depend on the detent fix above.
    private var expansionBaselineHeight: CGFloat {
        if isOwnProfile && !shouldShowOwnershipHint {
            return baseProfileHeight
        }
        return minimumProfileHeight
    }
    
    init(userId: String? = nil) {
        self.userId = userId
        let currentUserId = Auth.auth().currentUser?.uid
        self.currentUserId = currentUserId
        self.isOwnProfile = currentUserId != nil && (userId == nil || userId == currentUserId)
        // Start in loading state if we need to fetch a user
        if userId != nil {
            _isLoading = State(initialValue: true)
        }
        // Initialize feed view model with the target user ID or current user
        let targetUserId = userId ?? currentUserId ?? ""
        _feedViewModel = State(initialValue: ProfileFeedViewModel(userId: targetUserId))
    }
    
    @ViewBuilder
    private var profileContent: some View {
        let bannerHeight: CGFloat = 180
        
        // Unified view structure - always the same, components fade in/out
        if currentUser != nil {
            profileMainContent(bannerHeight: bannerHeight)
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
    
    @ViewBuilder
    private func profileMainContent(bannerHeight: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                // Profile header - always rendered with same structure
                if let user = currentUser {
                    profileHeaderCompact(for: user, bannerHeight: bannerHeight, showProfileInfo: true)
                }
                
                // Tabs and feed - always rendered, fade in during swipe
                profileTabs
                    .modifier(expansionFade(.reveal))
                
                // Tab content - fade in as sheet expands. Its own view, so feed updates don't re-render the header
                ProfileFeedSection(viewModel: feedViewModel, selectedTab: selectedTab)
                    .modifier(expansionFade(.reveal))
            }
        }
        .scrollIndicators(.hidden)
        .background(isSheetFullyExpanded ? Color(.systemBackground) : Color.clear)
        .ignoresSafeArea(edges: .top)
        .onPreferenceChange(ProfileHeaderHeightKey.self) { height in
            guard !isOwnProfile else { return }
            let clampedHeight = max(height, 1)
            guard clampedHeight > 1 else { return }
            
            let delta = abs(otherProfileHeaderHeight - clampedHeight)
            guard delta > 0.5 else { return }
            
            otherProfileHeaderHeight = clampedHeight
            
            if !isSheetFullyExpanded {
                currentDetent = .height(clampedHeight)
            }
        }
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
                    isOwnProfile: isOwnProfile,
                    isSheetFullyExpanded: isSheetFullyExpanded,
                    showEditProfile: $showEditProfile,
                    currentUser: currentUser,
                    dismissAction: { dismiss() },
                    editProfileDismissed: { profileRevision += 1 }
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
    }
    
    private var profileGeometryContent: some View {
        profileContent
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            // Width and safe area rarely change, so this re-renders the profile only when they do
            .onGeometryChange(for: ContainerMetrics.self) { proxy in
                ContainerMetrics(width: proxy.size.width, topSafeAreaInset: proxy.safeAreaInsets.top)
            } action: { metrics in
                containerMetrics = metrics
            }
            // The height changes on every frame of a sheet drag; only SheetExpansionFade reads it
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { height in
                sheetMetrics.height = height
            }
            // Loads each tab the first time it is shown; cancelled when the profile is dismissed
            .task(id: selectedTab) {
                await feedViewModel.load(selectedTab)
            }
    }
    
    // MARK: - Banner
    
    private var bannerContent: some View {
        GeometryReader { bannerGeometry in
            // Calculate avatar image center position based on actual layout
            // Avatar image is left-aligned within its frame, with left edge at content padding (20pt)
            // Avatar image left edge = profileContentPadding (20pt) from screen left
            // Avatar image center X = profileContentPadding + (avatarImageSize / 2) = 20pt + 50pt = 70pt
            // Avatar overlaps banner, mask must be centered on avatar (not aligned at top)
            // If mask top = avatar top, mask center is 6pt too low (mask is 112pt, avatar is 100pt, difference is 12pt/2 = 6pt)
            // Banner GeometryReader coordinate space matches screen width, so we can use the same calculation
            let avatarCenterX = profileContentPadding + (avatarImageSize / 2)
            let avatarCenterY = bannerGeometry.size.height - 6
            
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let bannerURL = currentUser?.bannerURL, let url = URL(string: bannerURL) {
                        // Load from Firebase Storage URL with caching
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: bannerGeometry.size.width, height: bannerGeometry.size.height)
                                .clipped()
                        } placeholder: {
                            ZStack {
                                Color(.systemGray5)
                                    .frame(width: bannerGeometry.size.width, height: bannerGeometry.size.height)
                                
                                ProgressView()
                            }
                        }
                    } else {
                        // Default gray background
                        Color(.systemGray5)
                            .frame(width: bannerGeometry.size.width, height: bannerGeometry.size.height)
                    }
                }
                .mask {
                    ZStack {
                        Rectangle()
                        // Position mask circle center at exact avatar image center using bannerGeometry coordinates
                        // Avatar image left edge: profileContentPadding (20pt) - aligns with content padding
                        // Avatar image center X: profileContentPadding + (avatarImageSize / 2) = 20pt + 50pt = 70pt
                        // Avatar center Y: adjusted to center mask on avatar (mask is 112pt, avatar is 100pt)
                        // The mask circle is avatarMaskSize (112pt) to create even spacing around the 100pt avatar image
                        Circle()
                            .frame(width: avatarMaskSize, height: avatarMaskSize)
                            .position(
                                x: avatarCenterX, // Avatar image center X: profileContentPadding + avatarImageSize/2 = 70pt
                                y: avatarCenterY // Avatar center Y: at bottom of banner
                            )
                            .blendMode(.destinationOut)
                    }
                }
            }
        }
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
                        .frame(width: avatarImageSize, height: avatarImageSize)
                        .clipShape(Circle())
                } placeholder: {
                    ZStack {
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: avatarImageSize, height: avatarImageSize)
                        
                        ProgressView()
                    }
                }
            } else {
                // Default initials view
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: avatarImageSize, height: avatarImageSize)
                
                Color.clear
                    .frame(width: avatarImageSize, height: avatarImageSize)
                    .glassEffect(.regular, in: Circle())
                
                Text(userInitials)
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundColor(.primary)
            }
        }
        .frame(width: avatarImageSize, height: avatarImageSize)
    }
    
    // MARK: - User Info
    
    private var displayNameView: some View {
        HStack(spacing: 6) {
            Text(currentUser?.displayName ?? "Display Name")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
            
            // Badge inline with name
            if let badgeType = currentUser?.badgeType {
                Image(systemName: badgeType.iconName)
                    .foregroundStyle(badgeType.color)
                    .font(.title3)
            }
            
            Spacer()
        }
    }
    
    private var usernameView: some View {
        HStack(spacing: 8) {
            // Username
            HStack(spacing: 4) {
                Image(systemName: "at")
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Text(currentUser?.username ?? "username")
                    .font(.callout)
                    .fontWeight(.regular)
                    .foregroundStyle(.secondary)
            }
            
            // Location - only show if exists, with consistent styling
            if let location = currentUser?.location, !location.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "location")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    Text(location)
                        .font(.callout)
                        .fontWeight(.regular)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Joined date - with calendar icon, styled exactly like username and location
            if let user = currentUser {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    Text(Self.joinedDateFormatter.string(from: user.createdAt))
                        .font(.callout)
                        .fontWeight(.regular)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var bioView: some View {
        // Always show bio area, even if empty
        Text(currentUser?.bio ?? "")
            .font(.callout)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .topLeading)
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
    
    // MARK: - Expanded Profile Views
    
    // MARK: - Debug Overlay Helpers
    
    @ViewBuilder
    private func profileInfoContent(for user: User) -> some View {
        profileCardContainer {
            VStack(alignment: .leading, spacing: CardLayoutConstants.headerBottomSpacing) {
                VStack(alignment: .leading, spacing: CardLayoutConstants.headerBottomSpacing) {
                    displayNameView
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(debugSectionBackground(.content))
                        .overlay(debugStrokeOverlay())
                    
                    usernameView
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(debugSectionBackground(.content))
                        .overlay(debugStrokeOverlay())
                    
                    followerCountsView(for: user)
                    
                    bioView
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: 44)
                        .fixedSize(horizontal: false, vertical: true)
                        .background(debugSectionBackground(.content))
                        .overlay(debugStrokeOverlay())
                    
                    if !isOwnProfile {
                        actionButtons
                            .drawingGroup()
                            .background(debugSectionBackground(.actions))
                            .overlay(debugStrokeOverlay())
                    }
                }
                
                if shouldShowOwnershipHint {
                    ownershipHintLabel()
                        .modifier(expansionFade(.conceal(baseOpacity: ownershipHintOpacity)))
                        .transition(.opacity)
                        .onAppear {
                            ownershipHintOpacity = 0
                            withAnimation(.easeInOut(duration: 0.35)) {
                                ownershipHintOpacity = 1
                            }
                        }
                        // Settle to a quieter opacity after a second; cancelled if the hint goes away first
                        .task {
                            try? await Task.sleep(for: .seconds(1))
                            guard !Task.isCancelled else { return }
                            withAnimation(.easeInOut(duration: 0.5)) {
                                ownershipHintOpacity = 0.65
                            }
                        }
                        .onDisappear {
                            ownershipHintOpacity = 0
                        }
                        .allowsHitTesting(false)
                }
            }
        }
    }
    
    @ViewBuilder
    private func followerCountsView(for user: User) -> some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                Text("\(user.followerCount)")
                    .font(.callout)
                    .fontWeight(.heavy)
                    .foregroundColor(.primary)
                Text("Followers")
                    .font(.callout)
                    .fontWeight(.regular)
                    .foregroundStyle(.secondary)
            }
            
            HStack(spacing: 4) {
                Text("\(user.followingCount)")
                    .font(.callout)
                    .fontWeight(.heavy)
                    .foregroundColor(.primary)
                Text("Following")
                    .font(.callout)
                    .fontWeight(.regular)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .background(debugSectionBackground(.content))
        .overlay(debugStrokeOverlay())
    }
    
    private enum ProfileDebugSection {
        case content
        case actions
    }
    
    @ViewBuilder
    private func debugStrokeOverlay() -> some View {
        if showLayoutDebugOverlays {
            Rectangle()
                .stroke(Color.red, lineWidth: 1)
        }
    }
    
    @ViewBuilder
    private func debugSectionBackground(_ section: ProfileDebugSection = .content) -> some View {
        if showLayoutDebugOverlays {
            switch section {
            case .content:
                Color.green.opacity(0.1)
            case .actions:
                Color.orange.opacity(0.1)
            }
        } else {
            Color.clear
        }
    }
    
    @ViewBuilder
    private func debugCardOutline(
        horizontalInset: CGFloat = CardLayoutConstants.horizontalPadding,
        verticalInset: CGFloat = 0
    ) -> some View {
        if showLayoutDebugOverlays {
            RoundedRectangle(cornerRadius: CardLayoutConstants.cornerRadius)
                .stroke(Color.red, lineWidth: 2)
                .padding(.horizontal, horizontalInset)
                .padding(.vertical, verticalInset)
                .allowsHitTesting(false)
        }
    }
    
    @ViewBuilder
    private func debugPaddingLine() -> some View {
        if showLayoutDebugOverlays {
            VStack {
                Rectangle()
                    .fill(Color.yellow)
                    .frame(width: 1)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, profileContentPadding)
        }
    }
    
    @ViewBuilder
    private func profileCardContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let base = content()
            .padding(.horizontal, profileContentPadding)
            .background(showLayoutDebugOverlays ? Color.yellow.opacity(0.05) : Color.clear)
            .overlay(debugPaddingLine())
            .padding(.top, CardLayoutConstants.topPadding)
            .background(showLayoutDebugOverlays ? Color.pink.opacity(0.05) : Color.clear)
            .padding(.bottom, profileCardBottomPadding)
            .background(showLayoutDebugOverlays ? Color.cyan.opacity(0.05) : Color.clear)
        
        Group {
            if isSheetFullyExpanded {
                base
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: CardLayoutConstants.cornerRadius))
            } else {
                base
                    .clipShape(RoundedRectangle(cornerRadius: CardLayoutConstants.cornerRadius))
            }
        }
        .overlay(debugCardOutline())
    }
    
    @ViewBuilder
    private func ownershipHintLabel() -> some View {
        Text("This is your profile")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 6)
            .background(debugSectionBackground(.content))
            .overlay(debugStrokeOverlay())
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: OwnershipHintHeightKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(OwnershipHintHeightKey.self) { height in
            guard height > 0 else { return }
            let delta = abs(ownershipHintMeasuredHeight - height)
            if delta > 0.5 {
                ownershipHintMeasuredHeight = height
            }
        }
    }
    
    @ViewBuilder
    private func profileHeaderCompact(for user: User, bannerHeight: CGFloat, showProfileInfo: Bool = true) -> some View {
        VStack(spacing: 0) {
            // Banner - fixed height (same as half-opened state, doesn't expand)
            // Extends all the way to top edge with no white space (use same banner instance to prevent flashing)
            bannerContent
                .id("profile-banner") // Consistent ID across all states
                .frame(
                    width: containerMetrics.width,
                    height: bannerHeight + containerMetrics.topSafeAreaInset,
                    alignment: .center
                )
                .offset(y: -containerMetrics.topSafeAreaInset)
                .padding(.bottom, -containerMetrics.topSafeAreaInset)
                .clipped()
                .ignoresSafeArea(edges: .top) // Extend to very top edge
            
            // Avatar and profile info - moves up to overlap banner
            // Only show when expanded to prevent text duplication
            if showProfileInfo {
                VStack(alignment: .leading, spacing: 0) {
                    // Avatar - left edge aligns with content padding
                    avatarView
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, profileContentPadding)
                    
                    // Profile info - consistent spacing throughout
                    profileInfoContent(for: user)
                }
                .offset(y: avatarOverlapOffset)
                .padding(.bottom, avatarOverlapOffset)
            }
        }
        .background(isSheetFullyExpanded ? Color(.systemBackground) : Color.clear)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: ProfileHeaderHeightKey.self, value: proxy.size.height)
            }
        )
    }
    
    private var actionButtons: some View {
        // Buttons container - no padding here, padding is applied by parent VStack
        HStack(spacing: 12) {
            // Follow button - perfectly centered, equal width
            Button(action: {
                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                Task {
                    await toggleFollow()
                }
            }) {
                HStack(spacing: 6) {
                    if isFollowLoading {
                        // Use a simple opacity approach instead of ProgressView to avoid icon issues
                        Image(systemName: isFollowing ? "checkmark" : "plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(isFollowing ? Color.primary : Color(.systemBackground))
                            .opacity(0.5)
                    } else {
                        Image(systemName: isFollowing ? "checkmark" : "plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(isFollowing ? Color.primary : Color(.systemBackground))
                    }
                    
                    Text(isFollowing ? "Following" : "Follow")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(isFollowing ? Color.primary : Color(.systemBackground))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .padding(.horizontal, 4)
                .background {
                    RoundedRectangle(cornerRadius: actionButtonCornerRadius, style: .continuous)
                        .fill(isFollowing ? Color.clear : Color.primary)
                }
                .overlay {
                    if isFollowing {
                        RoundedRectangle(cornerRadius: actionButtonCornerRadius, style: .continuous)
                            .strokeBorder(Color.primary, lineWidth: 1.5)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.plain) // Prevent automatic disabled styling
            .disabled(isFollowLoading)
            .saturation(isFollowLoading ? 0.4 : 1.0) // Use saturation for loading state instead of opacity
            .opacity(1.0) // Force full opacity regardless of sheet state
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
            
            // Message button - perfectly centered, equal width
            Button(action: {
                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                Task {
                    await startMessage()
                }
            }) {
                HStack(spacing: 6) {
                    if isMessageLoading {
                        // Use a simple opacity approach instead of ProgressView to avoid icon issues
                        Image(systemName: "message.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(.systemBackground))
                            .opacity(0.5)
                    } else {
                        Image(systemName: "message.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(.systemBackground))
                    }
                    
                    Text("Message")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(.systemBackground))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .padding(.horizontal, 4)
                .background {
                    // Black background (opposite for dark mode)
                    RoundedRectangle(cornerRadius: actionButtonCornerRadius, style: .continuous)
                        .fill(Color.primary)
                }
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.plain) // Prevent automatic disabled styling
            .disabled(isMessageLoading) // Disable while loading
            .saturation(isMessageLoading ? 0.4 : 1.0) // Use saturation for loading state
            .opacity(1.0) // Force full opacity regardless of sheet state
        }
        .background(debugSectionBackground(.actions))
        .overlay(debugStrokeOverlay())
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
    
    private var profileTabs: some View {
        VStack(spacing: 0) {
            // Top padding - only for other users' profiles
            if tabTopPadding > 0 {
                Color.clear
                    .frame(height: tabTopPadding)
                    .background(showLayoutDebugOverlays ? Color.purple.opacity(0.3) : Color.clear)
            }
            
            tabButtonsContainer
            tabIndicatorArea
            
            // Bottom padding - for all profiles (both own and others)
            if tabBottomPadding > 0 {
                Color.clear
                    .frame(height: tabBottomPadding)
                    .background(showLayoutDebugOverlays ? Color.purple.opacity(0.3) : Color.clear)
            }
        }
        .allowsHitTesting(true)
        .background(Color(.systemBackground).opacity(0.01)) // Minimal background for hit testing
        .overlay(tabDebugOverlay)
    }
    
    private var tabButtonsContainer: some View {
        HStack(spacing: 0) {
            ForEach(ProfileFeedTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 8) {
                        Text(tab.rawValue)
                            .font(.system(.body, design: .default))
                            .fontWeight(.semibold)
                            .foregroundColor(selectedTab == tab ? .primary : .secondary)
                        
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: CardLayoutConstants.dividerHeight)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, profileContentPadding) // Only side padding
        .background(showLayoutDebugOverlays ? Color.pink.opacity(0.05) : Color(.systemBackground))
        .overlay(debugPaddingLine())
        .overlay(tabButtonsDebugStroke)
    }
    
    @ViewBuilder
    private var tabButtonsDebugStroke: some View {
        if showLayoutDebugOverlays {
            Rectangle()
                .stroke(Color.red, lineWidth: 1)
        }
    }
    
    private var tabIndicatorArea: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                fullWidthDivider
                selectedTabIndicator
            }
            .frame(height: CardLayoutConstants.dividerHeight)
            .background(Color(.systemBackground))
            
        }
    }
    
    private var fullWidthDivider: some View {
        HStack(spacing: 0) {
            Spacer()
                .frame(width: profileContentPadding)
            
            Rectangle()
                .fill(CardLayoutConstants.dividerColor)
                .frame(maxWidth: .infinity)
                .frame(height: CardLayoutConstants.dividerHeight)
            
            Spacer()
                .frame(width: profileContentPadding)
        }
        .frame(height: CardLayoutConstants.dividerHeight)
    }
    
    private var selectedTabIndicator: some View {
        HStack(spacing: 0) {
            Spacer()
                .frame(width: profileContentPadding)
            
            HStack(spacing: 0) {
                if selectedTab == .posts {
                    Rectangle()
                        .fill(Color.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: CardLayoutConstants.dividerHeight)
                    Rectangle()
                        .fill(Color.clear)
                        .frame(maxWidth: .infinity)
                        .frame(height: CardLayoutConstants.dividerHeight)
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(maxWidth: .infinity)
                        .frame(height: CardLayoutConstants.dividerHeight)
                    Rectangle()
                        .fill(Color.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: CardLayoutConstants.dividerHeight)
                }
            }
            
            Spacer()
                .frame(width: profileContentPadding)
        }
        .frame(height: CardLayoutConstants.dividerHeight)
    }
    
    @ViewBuilder
    private var tabDebugOverlay: some View {
        if showLayoutDebugOverlays {
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.red, lineWidth: 2)
        }
    }
}

// MARK: - Feed

/// The posts or likes list under the header. Reading the view model here rather than in ProfileView keeps
/// feed loads and like changes from re-rendering the banner and header.
private struct ProfileFeedSection: View {
    let viewModel: ProfileFeedViewModel
    let selectedTab: ProfileFeedTab
    
    @AppStorage("showLayoutDebugOverlays") private var showLayoutDebugOverlays = false
    
    var body: some View {
        if selectedTab == .posts {
            feed(loops: viewModel.posts, isLoading: viewModel.isLoadingPosts)
        } else {
            feed(loops: viewModel.likedPosts, isLoading: viewModel.isLoadingLikes)
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
                    Image(systemName: selectedTab == .posts ? "square.and.pencil" : "heart")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text(selectedTab == .posts ? "No posts yet" : "No likes yet")
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
                        
                        VStack(spacing: 0) {
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
                            .padding(.top, isFirst ? 0 : 5)
                            .padding(.bottom, isLast ? 0 : 5)
                            
                            if !isLast {
                                PostDivider()
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Sheet Expansion

/// The live height of the profile's content area. It changes on every frame of a sheet drag, so only
/// `SheetExpansionFade` reads it and the rest of the profile doesn't re-render while the sheet moves.
@Observable
private final class ProfileSheetMetrics {
    var height: CGFloat = 0
    
    /// How far the sheet has opened: 0 up to halfway between the minimum detent and full height, 1 from 80%.
    /// Before the first measurement it falls back to the detent state.
    func expansionProgress(minimumHeight: CGFloat, isFullyExpanded: Bool) -> CGFloat {
        guard height > 0 else { return isFullyExpanded ? 1 : 0 }
        guard height > minimumHeight else { return 0 }
        // Use a reasonable estimate for max height (90% of typical screen)
        let maxHeight: CGFloat = 900 // Approximate max sheet height
        let range = maxHeight - minimumHeight
        guard range > 0 else { return 1 }
        let progress = min(max((height - minimumHeight) / range, 0), 1)
        return max(0, min(1, (progress - 0.5) / 0.3))
    }
}

/// Fades part of the profile as the sheet opens or closes. The live height is read here, so per-frame
/// updates during a drag stop at this modifier instead of re-running ProfileView's body.
private struct SheetExpansionFade: ViewModifier {
    enum Style {
        /// Tabs and feed: fade in as the sheet opens, taking touches once mostly visible.
        case reveal
        /// Ownership hint: fade out as the sheet opens, scaled by the hint's own opacity.
        case conceal(baseOpacity: Double)
    }
    
    let metrics: ProfileSheetMetrics
    let minimumHeight: CGFloat
    let isFullyExpanded: Bool
    let style: Style
    
    @ViewBuilder
    func body(content: Content) -> some View {
        let progress = metrics.expansionProgress(minimumHeight: minimumHeight, isFullyExpanded: isFullyExpanded)
        
        switch style {
        case .reveal:
            content
                .opacity(progress)
                .animation(.easeInOut(duration: 0.2), value: progress)
                .allowsHitTesting(progress > 0.5)
        case .conceal(let baseOpacity):
            content
                .opacity(baseOpacity * max(0, 1 - progress))
                .animation(.easeInOut(duration: 0.25), value: progress)
        }
    }
}

// MARK: - Preference Keys

private struct ProfileHeaderHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct OwnershipHintHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - View Modifiers to reduce type-checking complexity

private struct ProfileNavigationModifiers: ViewModifier {
    let isOwnProfile: Bool
    let isSheetFullyExpanded: Bool
    @Binding var showEditProfile: Bool
    let currentUser: User?
    let dismissAction: () -> Void
    let editProfileDismissed: () -> Void
    
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
                
                ToolbarItem(placement: .topBarTrailing) {
                    if isOwnProfile && isSheetFullyExpanded {
                        Button {
                            showEditProfile = true
                        } label: {
                            Image(systemName: "gear")
                                .font(.body.weight(.medium))
                        }
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
            .sheet(isPresented: $showEditProfile, onDismiss: editProfileDismissed) {
                EditProfileView(user: currentUser)
            }
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
