import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    // Optional userId - if nil, shows current user's profile (editable)
    // If provided, shows that user's profile (read-only)
    let userId: String?
    
    @State private var currentUser: User?
    @State private var isLoading = false
    @State private var showEditProfile = false
    @State private var loadError: String?
    @Environment(\.dismiss) private var dismiss
    
    // Debug settings
    @AppStorage("showLayoutDebugOverlays") private var showLayoutDebugOverlays = false
    
    // Follow system
    @State private var isFollowing = false
    @State private var isFollowLoading = false
    @State private var triggerSparkles = false
    
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
    @StateObject private var feedViewModel: ProfileFeedViewModel
    @State private var selectedTab: ProfileTab = .posts
    
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
            minimumHeight: minimumProfileHeight,
            isFullyExpanded: isSheetFullyExpanded,
            style: style
        )
    }
    
    /// Size and top safe area of the frame the profile content fills.
    private nonisolated struct ContainerMetrics: Equatable {
        var width: CGFloat = 0
        var topSafeAreaInset: CGFloat = 0
    }
    
    enum ProfileTab: String, CaseIterable {
        case posts = "Posts"
        case likes = "Likes"
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
    
    // Computed property to determine if viewing own profile
    private var isOwnProfile: Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return false }
        return userId == nil || userId == currentUserId
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
    
    private var minimumProfileHeight: CGFloat {
        if isOwnProfile {
            return baseProfileHeight + (shouldShowOwnershipHint ? ownershipHintHeight : 0)
        }
        
        if otherProfileHeaderHeight > 0 {
            return otherProfileHeaderHeight
        }
        
        return baseProfileHeight
    }
    
    init(userId: String? = nil) {
        self.userId = userId
        // Start in loading state if we need to fetch a user
        if userId != nil {
            _isLoading = State(initialValue: true)
        }
        // Initialize feed view model with the target user ID or current user
        let targetUserId = userId ?? Auth.auth().currentUser?.uid ?? ""
        _feedViewModel = StateObject(wrappedValue: ProfileFeedViewModel(userId: targetUserId))
        print("🎯 ProfileView.init(userId: \(userId ?? "nil"))")
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
                
                // Tab content - fade in as sheet expands
                Group {
                    if selectedTab == .posts {
                        profilePostsTabUnified
                    } else {
                        profileLikesTabUnified
                    }
                }
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
                loadCurrentUser()
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
        NavigationStack(path: $navigationPath) {
            profileGeometryContent
                .modifier(ProfileNavigationModifiers(
                    isOwnProfile: isOwnProfile,
                    isSheetFullyExpanded: isSheetFullyExpanded,
                    showEditProfile: $showEditProfile,
                    dismissAction: { dismiss() }
                ))
                .modifier(ProfileTaskModifiers(
                    userId: userId,
                    selectedTab: selectedTab,
                    feedViewModel: feedViewModel,
                    loadCurrentUserAsync: loadCurrentUserAsync
                ))
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
            .onChange(of: selectedTab) { _, newTab in
                Task {
                    if newTab == .posts {
                        await feedViewModel.loadUserPosts()
                    } else {
                        await feedViewModel.loadUserLikedPosts()
                    }
                }
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
    
    // MARK: - Follow Methods
    
    private func toggleFollow() async {
        guard let targetUserId = userId else {
            print("⚠️ toggleFollow: No target user ID provided")
            return
        }
        
        await MainActor.run {
            isFollowLoading = true
        }
        
        do {
            if isFollowing {
                print("📤 Unfollowing user: \(targetUserId)")
                try await FirebaseService.shared.unfollowUser(targetUserId)
                await MainActor.run {
                    isFollowing = false
                    print("✅ Successfully unfollowed user")
                }
            } else {
                print("📤 Following user: \(targetUserId)")
                try await FirebaseService.shared.followUser(targetUserId)
                await MainActor.run {
                    isFollowing = true
                    // Trigger sparkle animation on follow
                    triggerSparkles = true
                    print("✅ Successfully followed user")
                }
            }
            
            // Refresh user data to get updated follower counts
            await loadCurrentUserAsync()
            
        } catch {
            print("❌ Error toggling follow for user \(targetUserId): \(error.localizedDescription)")
            print("   Error details: \(error)")
            // Optionally show user-facing error here if needed
        }
        
        await MainActor.run {
            isFollowLoading = false
        }
    }
    
    private func checkFollowStatus() async {
        guard let targetUserId = userId else {
            print("⚠️ checkFollowStatus: No target user ID provided")
            return
        }
        
        do {
            print("🔍 Checking follow status for user: \(targetUserId)")
            let following = try await FirebaseService.shared.isFollowing(targetUserId)
            await MainActor.run {
                isFollowing = following
                print("✅ Follow status: \(following ? "Following" : "Not following")")
            }
        } catch {
            print("❌ Error checking follow status for user \(targetUserId): \(error.localizedDescription)")
            print("   Error details: \(error)")
        }
    }
    
    // MARK: - Methods
    
    private func loadCurrentUserAsync() async {
        await MainActor.run {
            isLoading = true
            loadError = nil
            currentUser = nil // Clear any stale data
        }
        
        do {
            if let targetUserId = userId {
                // Loading another user's profile
                print("🔵 Loading profile for user: \(targetUserId)")
                
                // Try cache first for immediate display
                if let cachedUser = try? await FirebaseService.shared.getUser(withId: targetUserId, forceRefresh: false) {
                    print("⚡️ Loaded from cache: \(cachedUser.displayName ?? "Unknown")")
                    await MainActor.run {
                        self.currentUser = cachedUser
                        self.isLoading = false
                        print("✅ UI updated with cached user: \(cachedUser.displayName ?? "Unknown")")
                    }
                    
                    // Check follow status for other users
                    await checkFollowStatus()
                    
                    // Then fetch fresh data in background
                    if let freshUser = try? await FirebaseService.shared.getUser(withId: targetUserId, forceRefresh: true) {
                        print("🔄 Updated with fresh data: \(freshUser.displayName ?? "Unknown")")
                        await MainActor.run {
                            self.currentUser = freshUser
                            print("✅ UI updated with fresh user: \(freshUser.displayName ?? "Unknown")")
                        }
                    }
                } else if let user = try await FirebaseService.shared.getUser(withId: targetUserId, forceRefresh: true) {
                    print("✅ Profile loaded from server: \(user.displayName ?? "Unknown")")
                    await MainActor.run {
                        self.currentUser = user
                        self.isLoading = false
                    }
                    
                    // Check follow status for other users
                    await checkFollowStatus()
                } else {
                    print("❌ User not found: \(targetUserId)")
                    await MainActor.run {
                        self.loadError = "User not found"
                        self.isLoading = false
                    }
                }
            } else {
                // Loading own profile - can use cache for better performance
                if let firebaseUser = Auth.auth().currentUser {
                    print("🔵 Loading own profile: \(firebaseUser.uid)")
                    if let firestoreUser = try await FirebaseService.shared.getUser(withId: firebaseUser.uid, forceRefresh: false) {
                        print("✅ Own profile loaded successfully")
                        await MainActor.run {
                            self.currentUser = firestoreUser
                            self.isLoading = false
                        }
                    } else {
                        print("⚠️ Creating new user profile")
                        let newUser = try await FirebaseService.shared.createUserIfNotExists(
                            phoneNumber: firebaseUser.phoneNumber ?? "",
                            displayName: firebaseUser.displayName
                        )
                        await MainActor.run {
                            self.currentUser = newUser
                            self.isLoading = false
                        }
                    }
                } else {
                    print("❌ Not authenticated")
                    await MainActor.run {
                        self.loadError = "Not authenticated"
                        self.isLoading = false
                    }
                }
            }
        } catch {
            print("❌ Error loading user: \(error)")
            await MainActor.run {
                self.loadError = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func loadCurrentUser() {
        Task {
            await loadCurrentUserAsync()
        }
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
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                guard shouldShowOwnershipHint else { return }
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    ownershipHintOpacity = 0.65
                                }
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
                SparkleAnimation()
                    .opacity(triggerSparkles ? 1 : 0)
                    .allowsHitTesting(false)
                    .onChange(of: triggerSparkles) { _, newValue in
                        if newValue {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                triggerSparkles = false
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
        guard let targetUserId = userId else {
            print("⚠️ startMessage: No target user ID provided")
            return
        }
        
        guard Auth.auth().currentUser?.uid != nil else {
            print("⚠️ startMessage: User not authenticated")
            await MainActor.run {
                isMessageLoading = false
            }
            return
        }
        
        // Use already-loaded user data (much faster than fetching again!)
        let targetUser = currentUser
        let chatTitle = targetUser?.displayName ?? "User"
        
        print("💬 Starting message with user: \(targetUserId)")
        await MainActor.run {
            isMessageLoading = true
        }
        
        do {
            // Optimize: Use createChat which already checks for existing chats internally
            // This is faster than calling findExistingChat + createChat separately
            print("🔍 Finding or creating chat...")
            var chat = try await FirebaseService.shared.createChat(withUserId: targetUserId, title: chatTitle)
            
            // Populate user data from already-loaded currentUser (no extra fetch needed!)
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
            
            print("✅ Chat ready: \(chat.id.uuidString) with \(chatTitle)")
            
            // Navigate immediately
            await MainActor.run {
                navigationPath.append(ChatsRoute.conversation(chat))
                isMessageLoading = false
            }
        } catch {
            print("❌ Error starting message with user \(targetUserId): \(error.localizedDescription)")
            print("   Error type: \(type(of: error))")
            await MainActor.run {
                isMessageLoading = false
            }
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
            ForEach(ProfileTab.allCases, id: \.self) { tab in
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
    
    private var profilePostsTabUnified: some View {
        profileFeedViewUnified(loops: feedViewModel.posts, isLoading: feedViewModel.isLoadingPosts)
    }
    
    private var profileLikesTabUnified: some View {
        profileFeedViewUnified(loops: feedViewModel.likedPosts, isLoading: feedViewModel.isLoadingLikes)
    }
    
    private func profileFeedViewUnified(loops: [Loop], isLoading: Bool) -> some View {
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
                                isLiked: feedViewModel.isLikedByCurrentUser(loop),
                                onLike: {
                                    Task {
                                        let wasLiked = feedViewModel.isLikedByCurrentUser(loop)
                                        
                                        do {
                                            if wasLiked {
                                                try await FirebaseService.shared.unlikeLoop(loop.id)
                                                feedViewModel.updateLoopLikeState(loopId: loop.id, isLiked: false)
                                            } else {
                                                try await FirebaseService.shared.likeLoop(loop.id)
                                                feedViewModel.updateLoopLikeState(loopId: loop.id, isLiked: true)
                                            }
                                        } catch {
                                            print("❌ Error toggling like: \(error.localizedDescription)")
                                        }
                                    }
                                },
                                onComment: {
                                    // Handle comment tap
                                },
                                onDelete: feedViewModel.canDeleteLoop(loop) ? {
                                    Task {
                                        await feedViewModel.deleteLoop(loop)
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
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
            }
            .navigationDestination(for: ChatsRoute.self) { route in
                switch route {
                case .conversation(let chat):
                    ConversationView(chat: chat)
                }
            }
    }
}

private struct ProfileTaskModifiers: ViewModifier {
    let userId: String?
    let selectedTab: ProfileView.ProfileTab
    let feedViewModel: ProfileFeedViewModel
    let loadCurrentUserAsync: () async -> Void
    
    func body(content: Content) -> some View {
        content
            .task(id: userId) {
                print("📋 .task(id: \(userId ?? "nil")) triggered")
                await loadCurrentUserAsync()
                
                // Load feed data after user loads
                if selectedTab == .posts {
                    await feedViewModel.loadUserPosts()
                } else {
                    await feedViewModel.loadUserLikedPosts()
                }
            }
            .onAppear {
                print("👀 ProfileView.onAppear - userId: \(userId ?? "nil")")
            }
    }
}

#Preview {
    ProfileView()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
}
