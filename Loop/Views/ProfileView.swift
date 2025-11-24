import SwiftUI
import FirebaseAuth
import PhotosUI

struct ProfileView: View {
    // Optional userId - if nil, shows current user's profile (editable)
    // If provided, shows that user's profile (read-only)
    let userId: String?
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var currentUser: User?
    @State private var isLoading = false
    @State private var showSettings = false
    @State private var isEditing = false
    @State private var loadError: String?
    
    // Editable fields
    @State private var editDisplayName: String = ""
    @State private var editUsername: String = ""
    @State private var editBio: String = ""
    @State private var editLocation: String = ""
    
    // Save state
    @State private var isSaving = false
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""
    
    // Logout
    @State private var showLogoutConfirmation = false
    @Environment(\.dismiss) private var dismiss
    
    // Debug settings
    @AppStorage("showLayoutDebugOverlays") private var showLayoutDebugOverlays = false
    
    // Avatar editing with native PhotosPicker
    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var bannerPickerItem: PhotosPickerItem?
    @State private var selectedBanner: UIImage?
    @State private var showAvatarPicker = false
    @State private var showBannerPicker = false
    
    // Follow system
    @State private var isFollowing = false
    @State private var isFollowLoading = false
    @State private var triggerSparkles = false
    
    // Message system
    @State private var isMessageLoading = false
    
    // Dynamic sheet height
    @State private var contentHeight: CGFloat = 0
    @State private var currentDetent: PresentationDetent = .height(366)
    @State private var actualSheetHeight: CGFloat = 0
    
    // Profile feed
    @StateObject private var feedViewModel: ProfileFeedViewModel
    @State private var selectedTab: ProfileTab = .posts
    
    // Navigation for messages
    @State private var navigationPath = NavigationPath()
    
    // Computed property to check if sheet is fully expanded
    private var isSheetFullyExpanded: Bool {
        currentDetent == .large
    }
    
    // Calculate expansion progress (0.0 to 1.0) for fade-in animations
    // Use actual height if available, otherwise base on detent state
    private var expansionProgress: CGFloat {
        // If we have actual height, use it for smooth animation
        if actualSheetHeight > 0 {
            guard actualSheetHeight > minimumProfileHeight else { return 0 }
            // Use a reasonable estimate for max height (90% of typical screen)
            let maxHeight: CGFloat = 900 // Approximate max sheet height
            let range = maxHeight - minimumProfileHeight
            guard range > 0 else { return 1 }
            let progress = min(max((actualSheetHeight - minimumProfileHeight) / range, 0), 1)
            // Start fading in at 50% expansion, fully visible at 80% - earlier fade for better UX
            return max(0, min(1, (progress - 0.5) / 0.3))
        }
        // Fallback: use detent state (discrete but works)
        return isSheetFullyExpanded ? 1.0 : 0.0
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
    
    // Computed property to determine if viewing own profile
    private var isOwnProfile: Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return false }
        return userId == nil || userId == currentUserId
    }
    
    // Date formatter for joined date (Month Year format)
    private var joinedDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter
    }
    
    // Calculate minimum height needed for profile content
    private var minimumProfileHeight: CGFloat {
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
    private func profileContent(geometry: GeometryProxy) -> some View {
        let bannerHeight: CGFloat = 180
        
        // Track actual sheet height for expansion progress
        Color.clear
            .frame(width: geometry.size.width, height: geometry.size.height)
            .preference(key: SheetHeightKey.self, value: geometry.size.height)
        
        // Unified view structure - always the same, components fade in/out
        if currentUser != nil {
            profileMainContent(bannerHeight: bannerHeight, geometry: geometry)
        } else if isLoading {
            loadingView
        } else if loadError != nil {
            errorView
        }
    }
    
    @ViewBuilder
    private func profileMainContent(bannerHeight: CGFloat, geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Profile header - always rendered with same structure
            if let user = currentUser {
                profileHeaderCompact(for: user, bannerHeight: bannerHeight, geometry: geometry, showProfileInfo: true)
            }
            
            // Tabs and feed - always rendered, fade in during swipe
            if !isEditing {
                profileTabs
                    .opacity(expansionProgress)
                    .animation(.easeInOut(duration: 0.2), value: expansionProgress)
                    .allowsHitTesting(expansionProgress > 0.5)
                
                // Tab content - fade in as sheet expands
                Group {
                    if selectedTab == .posts {
                        profilePostsTab
                    } else {
                        profileLikesTab
                    }
                }
                .opacity(expansionProgress)
                .animation(.easeInOut(duration: 0.2), value: expansionProgress)
                .allowsHitTesting(expansionProgress > 0.5)
            }
        }
        .background(isSheetFullyExpanded ? Color(.systemBackground) : Color.clear)
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
                loadCurrentUser()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 400)
        .padding(.top, 100)
    }
    
    var body: some View {
        return NavigationStack(path: $navigationPath) {
            GeometryReader { geometry in
                profileContent(geometry: geometry)
            }
            .onPreferenceChange(SheetHeightKey.self) { height in
                actualSheetHeight = height
            }
            .onChange(of: selectedTab) { _, newTab in
                // Load data when tab changes (always, not just when expanded)
                Task {
                    if newTab == .posts {
                        await feedViewModel.loadUserPosts()
                    } else {
                        await feedViewModel.loadUserLikedPosts()
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isEditing {
                        Button("Cancel") {
                            cancelEditing()
                        }
                        .fontWeight(.medium)
                    } else {
                        // Only show close button when fully expanded
                        if isSheetFullyExpanded {
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark")
                                    .font(.body.weight(.medium))
                            }
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if isOwnProfile {
                        if isEditing {
                            Button {
                                if isSaving { return }
                                saveProfile()
                            } label: {
                                if isSaving {
                                    ProgressView()
                                } else {
                                    Text("Done")
                                        .fontWeight(.medium)
                                }
                            }
                            .disabled(isSaving)
                        } else {
                            // Only show gear button when fully expanded
                            if isSheetFullyExpanded {
                                Button {
                                    startEditing()
                                } label: {
                                    Image(systemName: "gear")
                                        .font(.body.weight(.medium))
                                }
                            }
                        }
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
            .task(id: userId) {
                // Load profile immediately when view appears or userId changes
                // Using task ensures it's properly cancelled/restarted
                print("📋 .task(id: \(userId ?? "nil")) triggered")
                await loadCurrentUserAsync()
                
                // Load feed data immediately when profile loads (don't wait for expansion)
                if currentUser != nil {
                    Task {
                        if selectedTab == .posts {
                            await feedViewModel.loadUserPosts()
                        } else {
                            await feedViewModel.loadUserLikedPosts()
                        }
                    }
                }
            }
            .onAppear {
                print("👀 ProfileView.onAppear - userId: \(userId ?? "nil"), currentUser: \(currentUser?.displayName ?? "nil"), isLoading: \(isLoading)")
            }
            .navigationDestination(isPresented: $showSettings) {
                SettingsView()
            }
            .navigationDestination(for: ChatsRoute.self) { route in
                switch route {
                case .conversation(let chat):
                    ConversationView(chat: chat)
                }
            }
            .onChange(of: avatarPickerItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImage = image
                        // Upload to Firebase Storage
                        do {
                            _ = try await FirebaseService.shared.uploadAvatarImage(image)
                            // Reload user to get updated avatar URL
                            if let firebaseUser = Auth.auth().currentUser {
                                currentUser = try await FirebaseService.shared.getUser(withId: firebaseUser.uid)
                            }
                        } catch {
                            print("Error uploading avatar: \(error.localizedDescription)")
                        }
                    }
                }
            }
            .onChange(of: bannerPickerItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedBanner = image
                        // Upload to Firebase Storage
                        do {
                            _ = try await FirebaseService.shared.uploadBannerImage(image)
                            // Reload user to get updated banner URL
                            if let firebaseUser = Auth.auth().currentUser {
                                currentUser = try await FirebaseService.shared.getUser(withId: firebaseUser.uid)
                            }
                        } catch {
                            print("Error uploading banner: \(error.localizedDescription)")
                        }
                    }
                }
            }
            .photosPicker(
                isPresented: $showAvatarPicker,
                selection: $avatarPickerItem,
                matching: .images
            )
            .photosPicker(
                isPresented: $showBannerPicker,
                selection: $bannerPickerItem,
                matching: .images
            )
            .alert("Log Out", isPresented: $showLogoutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Log Out", role: .destructive) {
                    logout()
                }
            } message: {
                Text("Are you sure you want to log out?")
            }
            .alert("Error Saving Profile", isPresented: $showSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(saveErrorMessage)
            }
            .presentationDetents([.height(minimumProfileHeight), .large], selection: $currentDetent)
            .presentationDragIndicator(.visible)
            // iOS 26 automatically applies liquid glass effect when sheet is half-opened
            // No presentationBackground needed - system handles it automatically
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
                    if let banner = selectedBanner {
                        // Show locally selected image (while uploading or editing)
                        Image(uiImage: banner)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: bannerGeometry.size.width, height: bannerGeometry.size.height)
                            .clipped()
                    } else if let bannerURL = currentUser?.bannerURL, let url = URL(string: bannerURL) {
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
                
                if isEditing && isOwnProfile {
                    Button {
                        Task {
                            // iOS 18+ best practice: request access first
                            let hasAccess = await PhotoLibraryManager.shared.requestPhotoLibraryAccess()
                            if hasAccess {
                                showBannerPicker = true
                                // Prompt for full access if limited
                                if PhotoLibraryManager.shared.hasLimitedAccess {
                                    PhotoLibraryManager.shared.promptForFullAccessIfLimited()
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "camera.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(8)
                            .background {
                                Color.clear
                                    .glassEffect(.regular, in: Circle())
                            }
                    }
                    .padding(12)
                }
            }
        }
    }
    
    // MARK: - Avatar
    
    private var avatarView: some View {
        ZStack {
            if let image = selectedImage {
                // Show locally selected image (while uploading or editing)
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: avatarImageSize, height: avatarImageSize)
                    .clipShape(Circle())
            } else if let avatarURL = currentUser?.avatarURL, let url = URL(string: avatarURL) {
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
            
            if isEditing && isOwnProfile {
                Button {
                    Task {
                        // iOS 18+ best practice: request access first
                        let hasAccess = await PhotoLibraryManager.shared.requestPhotoLibraryAccess()
                        if hasAccess {
                            showAvatarPicker = true
                            // Prompt for full access if limited
                            if PhotoLibraryManager.shared.hasLimitedAccess {
                                PhotoLibraryManager.shared.promptForFullAccessIfLimited()
                            }
                        }
                    }
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(8)
                        .background {
                            Color.clear
                                .glassEffect(.regular, in: Circle())
                        }
                }
                .offset(x: avatarImageSize / 2 - 8, y: avatarImageSize / 2 - 8)
            }
        }
        .frame(width: avatarImageSize, height: avatarImageSize)
    }
    
    // MARK: - User Info
    
    private var displayNameView: some View {
        Group {
            if isEditing && isOwnProfile {
                TextField("Display Name", text: $editDisplayName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(height: 40)
                    .background {
                        Color.clear
                            .glassEffect(.regular, in: .rect(cornerRadius: 12))
                    }
            } else {
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
        }
    }
    
    private var usernameView: some View {
        HStack(spacing: 8) {
            if isEditing && isOwnProfile {
                HStack(spacing: 4) {
                    Text("@")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    TextField("username", text: $editUsername)
                        .font(.callout)
                        .textFieldStyle(.plain)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: editUsername) { oldValue, newValue in
                            editUsername = sanitizeUsername(newValue)
                        }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, maxHeight: 36)
                .background {
                    Color.clear
                        .glassEffect(.regular, in: .rect(cornerRadius: 12))
                }
            } else {
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
                        
                        Text(joinedDateFormatter.string(from: user.createdAt))
                            .font(.callout)
                            .fontWeight(.regular)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    
    private var locationView: some View {
        HStack(spacing: 4) {
            Image(systemName: "location")
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            TextField("Add location...", text: $editLocation)
                .font(.callout)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: 36)
        .background {
            Color.clear
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
        }
    }
    
    private var bioView: some View {
        Group {
            if isEditing && isOwnProfile {
                TextField("Add a bio...", text: $editBio, axis: .vertical)
                    .font(.callout)
                    .lineLimit(2...4)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
                    .background {
                        Color.clear
                            .glassEffect(.regular, in: .rect(cornerRadius: 12))
                    }
            } else {
                // Always show bio area, even if empty
                Text(currentUser?.bio ?? "")
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }
    
    // MARK: - Profile Content
    
    @ViewBuilder
    private func profileContent(for user: User, bannerHeight: CGFloat, geometry: GeometryProxy) -> some View {
        // Banner - extends to top edge (use same banner instance to prevent flashing)
        bannerContent
            .id("profile-banner") // Consistent ID across all states
            .frame(height: bannerHeight + geometry.safeAreaInsets.top)
            .offset(y: -geometry.safeAreaInsets.top)
            .padding(.bottom, -geometry.safeAreaInsets.top)
        
        // Avatar and profile info - moves up to overlap banner
        VStack(alignment: .leading, spacing: 0) {
            // Avatar - left edge aligns with content padding
            avatarView
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, profileContentPadding)
                .background(showLayoutDebugOverlays ? Color.yellow.opacity(0.1) : Color.clear)
                .overlay(
                    Group {
                        if showLayoutDebugOverlays {
                            Rectangle()
                                .stroke(Color.red, lineWidth: 1)
                        }
                    }
                )
            
            // Profile info
            VStack(alignment: .leading, spacing: 8) {
                displayNameView
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if isEditing && isOwnProfile {
                    // Username and Location on same line when editing
                    HStack(spacing: 8) {
                        usernameView
                        locationView
                    }
                } else {
                    // Username and location with consistent spacing
                    usernameView
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Follower counts (inline format)
                if !isEditing {
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
                }
                
                // Bio - always visible with minimum two-line height
                bioView
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 44) // Minimum height for two lines
                    .fixedSize(horizontal: false, vertical: true) // Allow vertical expansion
            }
            .padding(.horizontal, profileContentPadding) // Match post content padding (20pt total)
            .padding(.top, CardLayoutConstants.topPadding)
            .padding(.bottom, CardLayoutConstants.bottomPadding)
        }
        .offset(y: avatarOverlapOffset)
        .padding(.bottom, avatarOverlapOffset)
        
        // Settings section with fade effect (only for own profile)
        if !isEditing && isOwnProfile {
            GeometryReader { settingsGeo in
                let minY = settingsGeo.frame(in: .global).minY
                let screenHeight = UIScreen.main.bounds.height
                let fadeStart = screenHeight * 0.7
                let fadeEnd = screenHeight * 0.5
                let opacity = min(max((fadeStart - minY) / (fadeStart - fadeEnd), 0), 1)
                
                settingsSection
                    .opacity(opacity)
            }
        }
        
        Spacer(minLength: 20) // Minimal bottom space
    }
    
    // MARK: - Settings
    
    private var settingsSection: some View {
        List {
            // Phone Number Section
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "phone.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Phone Number")
                            .font(.body)
                        
                        Text(formattedPhoneNumber)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Verified badge
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                }
                .padding(.vertical, 4)
                .listRowBackground(colorScheme == .dark ? Color.black : Color(.systemGray6))
            } footer: {
                Text("Not public and only visible to you")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Settings & Actions Section
            Section {
                Button {
                    showSettings = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "gear")
                            .foregroundColor(.gray)
                            .font(.title3)
                            .frame(width: 30)
                        
                        Text("Settings")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .listRowBackground(colorScheme == .dark ? Color.black : Color(.systemGray6))
                
                Button {
                    showLogoutConfirmation = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle")
                            .foregroundColor(.red)
                            .font(.title3)
                            .frame(width: 30)
                        
                        Text("Log Out")
                            .foregroundColor(.red)
                        
                        Spacer()
                    }
                }
                .listRowBackground(colorScheme == .dark ? Color.black : Color(.systemGray6))
            }
        }
        .listStyle(.insetGrouped)
        .scrollDisabled(true)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 0, for: .scrollContent)
        .frame(height: 250)
    }
    
    // MARK: - Follow Button
    
    private var compactFollowButton: some View {
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
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(.white)
                } else {
                    Image(systemName: isFollowing ? "checkmark" : "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Text(isFollowing ? "Following" : "Follow")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 18)
                    .fill(isFollowing ? Color.gray : Color.blue)
            }
            .scaleEffect(isFollowLoading ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isFollowLoading)
        }
        .disabled(isFollowLoading)
        .overlay {
            SparkleAnimation()
                .opacity(triggerSparkles ? 1 : 0)
                .allowsHitTesting(false)
                .onChange(of: triggerSparkles) { _, newValue in
                    if newValue {
                        // Reset trigger after animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            triggerSparkles = false
                        }
                    }
                }
        }
    }
    
    // MARK: - Helper Properties
    
    private var userInitials: String {
        let displayName = isEditing ? editDisplayName : (currentUser?.displayName ?? "")
        
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
    
    private var formattedPhoneNumber: String {
        guard let phoneNumber = currentUser?.phoneNumber else {
            return "No phone number"
        }
        
        // Format phone number for display (assuming US format)
        let digits = phoneNumber.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        guard digits.count == 11 && digits.hasPrefix("1") else {
            return phoneNumber // Return as-is if not in expected format
        }
        
        let areaCode = String(digits.dropFirst(1).prefix(3))
        let firstPart = String(digits.dropFirst(4).prefix(3))
        let lastPart = String(digits.dropFirst(7))
        
        return "(\(areaCode)) \(firstPart)-\(lastPart)"
    }
    
    // MARK: - Helper Methods
    
    private func sanitizeUsername(_ username: String) -> String {
        // Convert to lowercase
        let lowercased = username.lowercased()
        
        // Only allow alphanumeric, hyphen, and underscore
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let filtered = lowercased.unicodeScalars.filter { allowedCharacters.contains($0) }
        
        return String(String.UnicodeScalarView(filtered))
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
    
    private func refreshProfile() async {
        // Reuse the same loading logic
        await loadCurrentUserAsync()
    }
    
    private func startEditing() {
        editDisplayName = currentUser?.displayName ?? ""
        editUsername = currentUser?.username ?? ""
        editBio = currentUser?.bio ?? ""
        editLocation = currentUser?.location ?? ""
        
        withAnimation(.easeInOut(duration: 0.25)) {
            isEditing = true
        }
    }
    
    private func cancelEditing() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isEditing = false
        }
        
        editDisplayName = ""
        editUsername = ""
        editBio = ""
        editLocation = ""
    }
    
    private func saveProfile() {
        isSaving = true
        
        Task {
            do {
                // Sanitize username: lowercase, alphanumeric + hyphen + underscore only
                let cleanUsername = sanitizeUsername(editUsername.trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "@", with: ""))
                
                try await FirebaseService.shared.updateUserProfile(
                    displayName: editDisplayName.isEmpty ? nil : editDisplayName,
                    username: cleanUsername.isEmpty ? nil : cleanUsername,
                    bio: editBio.isEmpty ? nil : editBio,
                    location: editLocation.isEmpty ? nil : editLocation
                )
                
                if let firebaseUser = Auth.auth().currentUser {
                    currentUser = try await FirebaseService.shared.getUser(withId: firebaseUser.uid)
                }
                
                await MainActor.run {
                    isSaving = false
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isEditing = false
                    }
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    saveErrorMessage = error.localizedDescription
                    showSaveError = true
                }
            }
        }
    }
    
    private func logout() {
        do {
            try Auth.auth().signOut()
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Expanded Profile Views
    
    // MARK: - Debug Overlay Helpers
    
    @ViewBuilder
    private func profileInfoContent(for user: User) -> some View {
        let content = VStack(alignment: .leading, spacing: CardLayoutConstants.headerBottomSpacing) { // Match PostCard internal spacing: 12pt between components (header->content->actions)
            displayNameView
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(debugBackground(color: .green))
                .overlay(debugStrokeOverlay())
            
            usernameView
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(debugBackground(color: .blue))
                .overlay(debugStrokeOverlay())
            
            // Follower counts - hide when editing
            if !isEditing {
                followerCountsView(for: user)
            }
            
            // Bio
            bioView
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 44) // Same as original
                .fixedSize(horizontal: false, vertical: true)
                .background(debugBackground(color: .orange))
                .overlay(debugStrokeOverlay())
            
            // Action buttons (Follow and Message) - below bio, above tabs
            // Always visible in preview (not just when fully expanded)
            if !isOwnProfile && !isEditing {
                actionButtons
                    .drawingGroup() // Isolate rendering to prevent automatic styling from sheet state
                    .background(debugBackground(color: .cyan))
                    .overlay(debugStrokeOverlay())
            }
            
            // Settings section when editing (only for own profile)
            if isEditing && isOwnProfile {
                settingsSection
                    .frame(height: 250)
                    .background(debugBackground(color: .yellow))
                    .overlay(debugStrokeOverlay())
            }
        }
        .padding(.horizontal, profileContentPadding) // Match post content padding (20pt total)
        .background(showLayoutDebugOverlays ? Color.pink.opacity(0.05) : Color.clear)
        .overlay(debugPaddingLine())
        .padding(.top, CardLayoutConstants.topPadding) // Match PostCard top padding: 8pt
        .background(showLayoutDebugOverlays ? Color.purple.opacity(0.05) : Color.clear)
        .padding(.bottom, CardLayoutConstants.bottomPadding) // Match PostCard bottom padding: 8pt (consistent top/bottom)
        .background(showLayoutDebugOverlays ? Color.cyan.opacity(0.05) : Color.clear)
        
        // Apply background only when fully expanded - let iOS 26 handle liquid glass when half-opened
        Group {
            if isSheetFullyExpanded {
                content
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: CardLayoutConstants.cornerRadius))
            } else {
                // No background modifier at all when half-opened - let sheet's native liquid glass show through
                content
                    .clipShape(RoundedRectangle(cornerRadius: CardLayoutConstants.cornerRadius))
            }
        }
        .overlay {
            if showLayoutDebugOverlays {
                RoundedRectangle(cornerRadius: CardLayoutConstants.cornerRadius)
                    .stroke(Color.red, lineWidth: 2)
            }
        }
    }
    
    @ViewBuilder
    private var profileInfoBackground: some View {
        // Use solid background when fully expanded, clear when half-opened to let sheet's native liquid glass show through
        if isSheetFullyExpanded {
            Color(.systemBackground)
        } else {
            // No background - let iOS 26 sheet automatically apply liquid glass effect
            Color.clear
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
        .background(debugBackground(color: .purple))
        .overlay(debugStrokeOverlay())
    }
    
    @ViewBuilder
    private func debugStrokeOverlay() -> some View {
        if showLayoutDebugOverlays {
            Rectangle()
                .stroke(Color.red, lineWidth: 1)
        }
    }
    
    @ViewBuilder
    private func debugBackground(color: Color) -> some View {
        if showLayoutDebugOverlays {
            color.opacity(0.1)
        } else {
            Color.clear
        }
    }
    
    @ViewBuilder
    private func debugPaddingLine() -> some View {
        if showLayoutDebugOverlays {
            VStack {
                Rectangle()
                    .fill(Color.green)
                    .frame(width: 1)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, profileContentPadding)
        }
    }
    
    @ViewBuilder
    private func profileHeaderCompact(for user: User, bannerHeight: CGFloat, geometry: GeometryProxy, showProfileInfo: Bool = true) -> some View {
        VStack(spacing: 0) {
            // Banner - fixed height (same as half-opened state, doesn't expand)
            // Extends all the way to top edge with no white space (use same banner instance to prevent flashing)
            bannerContent
                .id("profile-banner") // Consistent ID across all states
                .frame(
                    width: geometry.size.width,
                    height: bannerHeight + geometry.safeAreaInsets.top,
                    alignment: .top
                )
                .offset(y: -geometry.safeAreaInsets.top)
                .padding(.bottom, -geometry.safeAreaInsets.top)
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
        .overlay(
            Group {
                if showLayoutDebugOverlays {
                    Rectangle()
                        .stroke(Color.blue, lineWidth: 2)
                }
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
                .padding(.vertical, 12)
                .background {
                    if isFollowing {
                        // When following: white background with black outline (opposite for dark mode)
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color(.systemBackground))
                    } else {
                        // When not following: black background
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.primary)
                    }
                }
                .overlay {
                    if isFollowing {
                        // Stroke overlay outside the background to prevent clipping
                        RoundedRectangle(cornerRadius: 18)
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
                .padding(.vertical, 12)
                .background {
                    // Black background (opposite for dark mode)
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.primary)
                }
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.plain) // Prevent automatic disabled styling
            .disabled(isMessageLoading) // Disable while loading
            .saturation(isMessageLoading ? 0.4 : 1.0) // Use saturation for loading state
            .opacity(1.0) // Force full opacity regardless of sheet state
        }
        .background(debugBackground(color: .cyan))
        .overlay(debugStrokeOverlay())
    }
    
    private func startMessage() async {
        guard let targetUserId = userId else {
            print("⚠️ startMessage: No target user ID provided")
            return
        }
        
        guard let currentUserId = Auth.auth().currentUser?.uid else {
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
            // Top padding - only when viewing someone else's profile (when buttons are shown)
            if !isOwnProfile && !isEditing {
                Color.clear
                    .frame(height: CardLayoutConstants.bottomPadding)
                    .background(showLayoutDebugOverlays ? Color.purple.opacity(0.3) : Color.clear)
            }
            
            tabButtonsContainer
            tabIndicatorArea
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
                            .font(.headline)
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
            
            // Bottom padding with purple background for visibility
            Color.clear
                .frame(height: CardLayoutConstants.bottomPadding)
                .background(showLayoutDebugOverlays ? Color.purple.opacity(0.3) : Color.clear)
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
    
    private var profilePostsTab: some View {
        profileFeedView(loops: feedViewModel.posts, isLoading: feedViewModel.isLoadingPosts, onRefresh: {
            await feedViewModel.refreshPosts()
        })
    }
    
    private var profileLikesTab: some View {
        profileFeedView(loops: feedViewModel.likedPosts, isLoading: feedViewModel.isLoadingLikes, onRefresh: {
            await feedViewModel.refreshLikedPosts()
        })
    }
    
    private func profileFeedView(loops: [Loop], isLoading: Bool, onRefresh: @escaping () async -> Void) -> some View {
        Group {
            if isLoading && loops.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 100)
                .background(Color(.systemBackground))
            } else if loops.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: selectedTab == .posts ? "square.and.pencil" : "heart")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text(selectedTab == .posts ? "No posts yet" : "No likes yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 100)
                .background(Color(.systemBackground))
            } else {
                // Use FeedListView for consistency with HomeView
                // Pass 0 for topContentMargin since we don't have a nav bar - content should start naturally below tabs
                FeedListView(
                    coordinateSpaceName: "profileFeed",
                    onRefresh: onRefresh,
                    scrollOffset: .constant(0),
                    contentHeight: .constant(0),
                    scrollViewHeight: .constant(0),
                    topContentMargin: 0
                ) {
                    // Posts section with dividers (exact same structure as HomeView)
                    ForEach(Array(loops.enumerated()), id: \.element.id) { index, loop in
                        VStack(spacing: 0) {
                            // PostCard with same padding as HomeView
                            PostCard(
                                loop: loop,
                                isLiked: feedViewModel.isLikedByCurrentUser(loop),
                                onLike: {
                                    Task {
                                        let wasLiked = feedViewModel.isLikedByCurrentUser(loop)
                                        
                                        do {
                                            if wasLiked {
                                                try await FirebaseService.shared.unlikeLoop(loop.id)
                                                // Update local state after successful unlike
                                                feedViewModel.updateLoopLikeState(loopId: loop.id, isLiked: false)
                                            } else {
                                                try await FirebaseService.shared.likeLoop(loop.id)
                                                // Update local state after successful like
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
                            .padding(.top, index == 0 ? 0 : 5)
                            .padding(.bottom, index == loops.count - 1 ? 0 : 5)
                            
                            // Divider between posts (exact same as HomeView)
                            if index < loops.count - 1 {
                                PostDivider()
                            }
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
                    }
                }
                .background(Color(.systemBackground))
            }
        }
    }
}

// Preference key to track sheet height for expansion animations
private struct SheetHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    ProfileView()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
}
