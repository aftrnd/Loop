import SwiftUI
import PhotosUI
import UIKit
import FirebaseAuth
import os

/// A compact composer that is exactly as tall as what is being written. It opens on the keyboard, grows a line at a
/// time and by a row of photos, and has no full-height state. Its round controls sit on the sheet's corner arcs.
struct ComposeLoopView: View {
    /// Creates the loop. A thrown error keeps the composer open with the draft and is shown here; success closes it.
    let onPost: (LoopDraft) async throws -> Void

    init(draft: LoopDraft = LoopDraft(), onPost: @escaping (LoopDraft) async throws -> Void) {
        _draft = State(initialValue: draft)
        self.onPost = onPost
    }

    // MARK: - Layout

    private enum Layout {
        /// The floating sheet's corner radius on iPhone 18 Pro, the number the profile card's 68pt capsules use
        static let cornerRadius: CGFloat = 54
        /// From the sheet's sides and bottom, and between its parts, measured where each part visibly ends
        static let inset: CGFloat = 20
        /// Round controls are centered this far in from the sheet's sides, on the corner arcs' centers
        static let axis: CGFloat = cornerRadius
        /// The photo button and Post: concentric with the bottom corners at the 20pt inset (20 + 34 = 54)
        static let controlHeight: CGFloat = (cornerRadius - inset) * 2
        /// Close is the toolbar's 44pt glass button, centered on the top corner's arc (32 + 22 = 54)
        static let closeSize: CGFloat = 44
        static let closeInset: CGFloat = cornerRadius - closeSize / 2
        /// Holds a three-character count inside its stroke; centered on the other top corner's arc
        static let ringSize: CGFloat = 28
        static let avatarSize: CGFloat = CardLayoutConstants.avatarSize
        /// 20pt past the column of round controls (20 + 68 + 20)
        static let textLeading: CGFloat = inset + controlHeight + inset
        static let maxLines = 8
        static let maxPhotos = 4
        static let photoSpacing: CGFloat = CardLayoutConstants.photoCarouselSpacing
        /// A photo's remove button sits 4pt in from its corner, concentric with it (4 + 12 = 16)
        static let photoCornerRadius: CGFloat = 16
        static let removeSize: CGFloat = 24
        /// Follow and Message's spacing; Post takes the right half of the row, like Message on a profile card
        static let actionSpacing: CGFloat = 12
    }

    // MARK: - State

    @State private var draft: LoopDraft
    /// The signed-in user, whose avatar sits beside the text
    @State private var user: User?
    @State private var selectedPhotos: [PhotosPickerItem] = []
    /// Photos picked and still uploading, shown as placeholders after the uploaded ones
    @State private var pendingUploads = 0
    @State private var isPosting = false
    @State private var alert: ComposeAlert?
    @State private var showingLibrary = false
    @State private var showingCamera = false
    @FocusState private var isTextFocused: Bool
    /// The header, text and photos, from their latest layout; with the bottom row they set the sheet's height
    @State private var blockSize: CGSize = .zero
    /// The space the sheet gives the composer
    @State private var containerSize: CGSize = .zero
    @ScaledMetric(relativeTo: .body) private var lineHeight: CGFloat = 22

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private static let logger = Logger(subsystem: "com.nejack.Loop", category: "ComposeLoopView")
    /// How the sheet follows its content as lines and photos come and go
    private static let resizeAnimation = Animation.smooth(duration: 0.3)

    // MARK: - Derived State

    private var title: String {
        draft.isReply ? "Reply" : "New loop"
    }

    private var placeholder: String {
        draft.isReply ? "Post your reply" : "What's happening in your loop?"
    }

    /// Text or a photo, counting one still uploading, which a swipe down would leave behind
    private var hasContent: Bool {
        !draft.content.isEmpty || !draft.media.isEmpty || isUploading
    }

    private var isUploading: Bool {
        pendingUploads > 0
    }

    private var canPost: Bool {
        draft.isValid && draft.isWithinCharacterLimit && !isUploading && !isPosting
    }

    /// Post turns ink once the loop can go, and stays ink while it posts
    private var isPostProminent: Bool {
        canPost || isPosting
    }

    private var isOverLimit: Bool {
        !draft.isWithinCharacterLimit
    }

    private var canAddPhotos: Bool {
        draft.media.count + pendingUploads < Layout.maxPhotos && !isPosting
    }

    /// The picker never offers more than the four a loop holds
    private var remainingPhotoSlots: Int {
        max(1, Layout.maxPhotos - draft.media.count - pendingUploads)
    }

    private var showsPhotoStrip: Bool {
        !draft.media.isEmpty || isUploading
    }

    /// The sheet's layout width: the window's until the sheet has been laid out for real
    private var contentWidth: CGFloat {
        containerSize.height > 0 ? containerSize.width : Self.windowMetrics.width
    }

    /// The body font the text field uses, in the app's rounded design: where its capitals and baselines fall inside
    /// a line, and how a draft wraps
    private var bodyFont: UIFont {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize))
        let font = UIFont.preferredFont(forTextStyle: .body, compatibleWith: traits)
        return font.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: 0) } ?? font
    }

    /// How far below the avatar's top the text starts, so the first line's capitals are centered on the avatar.
    /// A line's baseline sits its descender above the line's bottom.
    private var textTopInset: CGFloat {
        let font = bodyFont
        let baseline = lineHeight + font.descender
        return max(0, Layout.avatarSize / 2 - (baseline - font.capHeight / 2))
    }

    // MARK: - Body

    var body: some View {
        composer
            .tint(.primary)
            .presentationDetents([.height(detentHeight)])
            .presentationDragIndicator(.hidden)
            .interactiveDismissDisabled(hasContent)
            .sensoryFeedback(.impact(weight: .light), trigger: isOverLimit) { _, isOver in isOver }
            // Opens on the keyboard: tapping + is the decision to write
            .task {
                isTextFocused = true
                await loadCurrentUser()
            }
            .onChange(of: selectedPhotos) { _, newPhotos in
                Task {
                    await processSelectedPhotos(newPhotos)
                }
            }
            .alert(alert?.title ?? "", isPresented: alertBinding, presenting: alert) { _ in
                Button("OK", role: .cancel) { }
            } message: { alert in
                Text(alert.message)
            }
            .photosPicker(
                isPresented: $showingLibrary,
                selection: $selectedPhotos,
                maxSelectionCount: remainingPhotoSlots,
                matching: .images
            )
            .fullScreenCover(isPresented: $showingCamera) {
                ImagePicker(sourceType: .camera) { image in
                    Task {
                        await processCameraImage(image)
                    }
                }
            }
    }

    private var composer: some View {
        VStack(spacing: 0) {
            topBlock
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGSize.self) { proxy in
                    proxy.size
                } action: { size in
                    withAnimation(Self.resizeAnimation) {
                        blockSize = size
                    }
                }

            Spacer(minLength: Layout.inset)

            actionRow
        }
        .padding(.bottom, Layout.inset)
        // If the sheet is ever shorter than its content, the header gives way and Post stays above the keyboard
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { size in
            containerSize = size
        }
        // Runs into the bottom safe area like the profile card; the keyboard still lifts it
        .ignoresSafeArea(.container, edges: [.top, .bottom])
    }

    private var topBlock: some View {
        VStack(alignment: .leading, spacing: Layout.inset) {
            header
            entryRow
            if showsPhotoStrip {
                photoStrip
                    .transition(.opacity)
            }
        }
        .padding(.top, Layout.closeInset)
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 0) {
                closeButton
                Spacer(minLength: 0)
                if !draft.content.isEmpty {
                    ComposeCharacterRing(
                        count: draft.characterCount,
                        limit: LoopDraft.maxCharacterCount,
                        size: Layout.ringSize
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            .padding(.leading, Layout.closeInset)
            .padding(.trailing, Layout.axis - Layout.ringSize / 2)
        }
        .frame(height: Layout.closeSize)
        .animation(.smooth(duration: 0.2), value: draft.content.isEmpty)
    }

    private var closeButton: some View {
        Button(role: .close) {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .frame(width: Layout.closeSize, height: Layout.closeSize)
        .accessibilityLabel("Close")
    }

    // MARK: - Text

    /// The avatar on the round controls' axis and the text in its column. One or two lines sit beside the avatar,
    /// the second line's baseline on the avatar's bottom edge; the sheet grows by a line from the third.
    private var entryRow: some View {
        HStack(alignment: .top, spacing: Layout.textLeading - Layout.axis - Layout.avatarSize / 2) {
            avatar
            textField
        }
        .padding(.leading, Layout.axis - Layout.avatarSize / 2)
        .padding(.trailing, Layout.inset)
        // A tap anywhere beside a short draft starts typing, not only on its one line
        .background {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    isTextFocused = true
                }
        }
    }

    private var avatar: some View {
        Group {
            if let urlString = user?.avatarURL, let url = URL(string: urlString) {
                CachedAsyncImage(url: url, targetSize: CGSize(width: Layout.avatarSize, height: Layout.avatarSize)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Color(.systemGray5)
                }
            } else {
                Color(.systemGray5)
                    .overlay {
                        Text(String((user?.displayName ?? "").prefix(1)).uppercased())
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
            }
        }
        .frame(width: Layout.avatarSize, height: Layout.avatarSize)
        .clipShape(Circle())
        .modifier(PlayfulAvatar())
        .accessibilityHidden(true)
    }

    private var textField: some View {
        TextField(placeholder, text: $draft.content, axis: .vertical)
            .font(.body)
            .foregroundStyle(.primary)
            .lineLimit(1...Layout.maxLines)
            .textInputAutocapitalization(.sentences)
            .focused($isTextFocused)
            .padding(.top, textTopInset)
            // Ends at the last line's baseline, so the next part is spaced from where the text visibly ends
            .padding(.bottom, bodyFont.descender)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Photos

    private var photoStrip: some View {
        let side = photoSide(forWidth: contentWidth)
        return HStack(spacing: Layout.photoSpacing) {
            ForEach(draft.media) { media in
                ComposePhotoThumbnail(
                    media: media,
                    side: side,
                    cornerRadius: Layout.photoCornerRadius,
                    removeSize: Layout.removeSize
                ) {
                    remove(media)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

            ForEach(0..<pendingUploads, id: \.self) { _ in
                ComposeUploadTile(side: side, cornerRadius: Layout.photoCornerRadius)
                    .transition(.opacity)
            }
        }
        .padding(.leading, Layout.textLeading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Four photos fill the text column at the feed's carousel spacing: 61pt squares on iPhone 18 Pro
    private func photoSide(forWidth width: CGFloat) -> CGFloat {
        let column = width - Layout.textLeading - Layout.inset
        let gaps = Layout.photoSpacing * CGFloat(Layout.maxPhotos - 1)
        return max(0, ((column - gaps) / CGFloat(Layout.maxPhotos)).rounded(.down))
    }

    // MARK: - Actions Row

    private var actionRow: some View {
        GlassEffectContainer(spacing: Layout.actionSpacing) {
            HStack(spacing: Layout.actionSpacing) {
                photoMenu
                    .frame(maxWidth: .infinity, alignment: .leading)
                postButton
                    // Two control widths: its end cap stays centered on the corner arc, with half the ink of a full row
                    .frame(width: Layout.controlHeight * 2)
            }
        }
        .frame(height: Layout.controlHeight)
        .padding(.horizontal, Layout.inset)
    }

    private var photoMenu: some View {
        Menu {
            Button("Photo library", systemImage: "photo.on.rectangle") {
                showingLibrary = true
            }
            // The photos picker runs out of process and needs no library access; the camera asks for its own
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Camera", systemImage: "camera") {
                    showingCamera = true
                }
            }
        } label: {
            Image(systemName: "photo.badge.plus")
                .font(.title2.weight(.medium))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .menuStyle(.button)
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .frame(width: Layout.controlHeight, height: Layout.controlHeight)
        .disabled(!canAddPhotos)
        .accessibilityLabel("Add photo")
    }

    private var postButton: some View {
        Button(action: post) {
            ZStack {
                Text("Post")
                    .font(.headline)
                    // Stays in the layout while posting, under the spinner
                    .opacity(isPosting ? 0 : 1)
                if isPosting {
                    ProgressView()
                        .tint(Color(.systemBackground))
                }
            }
            .foregroundStyle(isPostProminent ? Color(.systemBackground) : Color.primary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .modifier(ComposeGlassStyle(isProminent: isPostProminent))
        .buttonBorderShape(.capsule)
        // Not disabled while posting: the ink would dim for the length of the request. post() ignores taps
        .disabled(!canPost && !isPosting)
        .accessibilityLabel(isPosting ? "Posting" : "Post")
        .animation(.smooth(duration: 0.2), value: isPostProminent)
    }

    // MARK: - Sheet Height

    /// The top block's height from a real layout. Presenting a sheet first lays its content out at throwaway sizes
    /// (the profile measured 120pt wide and 0 tall), so only a layout at the sheet's own width counts.
    private var measuredBlockHeight: CGFloat? {
        guard containerSize.height > 0, containerSize.width > 0,
              abs(blockSize.width - containerSize.width) < 0.5 else { return nil }
        return blockSize.height
    }

    /// A height detent sizes the area above the bottom safe area and the composer runs into it, so the sheet ends
    /// 20pt below the action row, as the profile card does
    private var detentHeight: CGFloat {
        let block = measuredBlockHeight ?? estimatedBlockHeight
        return block + Layout.inset + Layout.controlHeight + Layout.inset - Self.windowMetrics.bottomInset
    }

    /// The top block worked out from the draft before the first layout, so the sheet opens at its final height
    /// rather than moving once it has been measured
    private var estimatedBlockHeight: CGFloat {
        let width = Self.windowMetrics.width
        let text = draft.content.isEmpty ? placeholder : draft.content
        let columnWidth = width - Layout.textLeading - Layout.inset
        let lines = min(Self.lineCount(of: text, width: columnWidth, font: bodyFont), Layout.maxLines)
        let textBottom = textTopInset + CGFloat(lines) * lineHeight + bodyFont.descender
        var height = Layout.closeInset + Layout.closeSize + Layout.inset + max(Layout.avatarSize, textBottom)
        if showsPhotoStrip {
            height += Layout.inset + photoSide(forWidth: width)
        }
        return height
    }

    /// The app window's width, which the sheet is laid out at, and its bottom safe area. Falls back to
    /// iPhone 18 Pro's for previews.
    private static var windowMetrics: (width: CGFloat, bottomInset: CGFloat) {
        let window = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first
        return (window?.bounds.width ?? 402, window?.safeAreaInsets.bottom ?? 34)
    }

    /// How many lines the text wraps to in a column of this width
    private static func lineCount(of text: String, width: CGFloat, font: UIFont) -> Int {
        guard width > 0 else { return 1 }
        let size = CGSize(width: width, height: .greatestFiniteMagnitude)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        func height(of string: String) -> CGFloat {
            (string as NSString).boundingRect(
                with: size,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            ).height
        }
        let lineHeight = height(of: "A")
        guard lineHeight > 0 else { return 1 }
        return max(1, Int((height(of: text) / lineHeight).rounded()))
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { alert != nil },
            set: { isPresented in
                if !isPresented {
                    alert = nil
                }
            }
        )
    }

    // MARK: - Actions

    private func post() {
        guard canPost else { return }

        isPosting = true
        Task {
            defer { isPosting = false }
            do {
                try await onPost(draft)
                dismiss()
            } catch {
                Self.logger.error("Post failed: \(error.localizedDescription, privacy: .public)")
                alert = ComposeAlert(
                    title: draft.isReply ? "Couldn't post your reply" : "Couldn't post your loop",
                    message: "Please check your connection and try again."
                )
            }
        }
    }

    private func loadCurrentUser() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        do {
            user = try await FirebaseService.shared.getUser(withId: userId)
        } catch {
            Self.logger.error("Current user load failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func remove(_ media: LoopMedia) {
        withAnimation(Self.resizeAnimation) {
            draft.media.removeAll { $0.id == media.id }
        }
    }

    /// Uploads the picked photos side by side and adds them to the draft in the order they were picked.
    private func processSelectedPhotos(_ photos: [PhotosPickerItem]) async {
        guard !photos.isEmpty else { return }

        // Cleared before uploading: the menu stays enabled meanwhile, and the picker would reopen with these selected
        selectedPhotos = []
        withAnimation(Self.resizeAnimation) {
            pendingUploads += photos.count
        }

        var uploaded = [LoopMedia?](repeating: nil, count: photos.count)
        var failures: [any Error] = []

        await withTaskGroup(of: (Int, Result<LoopMedia, any Error>).self) { group in
            for (index, photo) in photos.enumerated() {
                // Decoding, scaling and the upload itself run off the main actor inside these calls
                group.addTask { @MainActor in
                    do {
                        guard let data = try await photo.loadTransferable(type: Data.self) else {
                            throw ImageUploadEncoder.EncodingError.unreadableImage
                        }
                        return (index, .success(try await FirebaseService.shared.uploadLoopMedia(.data(data))))
                    } catch {
                        return (index, .failure(error))
                    }
                }
            }

            for await (index, result) in group {
                switch result {
                case .success(let media):
                    uploaded[index] = media
                case .failure(let error):
                    failures.append(error)
                }
            }
        }

        withAnimation(Self.resizeAnimation) {
            pendingUploads -= photos.count
            draft.media.append(contentsOf: uploaded.compactMap { $0 })
        }
        if let error = failures.first {
            showPhotoFailure(error, count: failures.count)
        }
    }

    private func processCameraImage(_ image: UIImage) async {
        withAnimation(Self.resizeAnimation) {
            pendingUploads += 1
        }

        do {
            let media = try await FirebaseService.shared.uploadLoopMedia(.image(image))
            withAnimation(Self.resizeAnimation) {
                pendingUploads -= 1
                draft.media.append(media)
            }
        } catch {
            withAnimation(Self.resizeAnimation) {
                pendingUploads -= 1
            }
            showPhotoFailure(error, count: 1)
        }
    }

    private func showPhotoFailure(_ error: any Error, count: Int) {
        Self.logger.error("Photo upload failed: \(error.localizedDescription, privacy: .public)")

        // A photo that can't be decoded won't succeed on retry; anything else is most likely the network
        let message = (error as? ImageUploadEncoder.EncodingError)?.errorDescription
            ?? "Please check your connection and try again."
        alert = ComposeAlert(
            title: count == 1 ? "Couldn't add photo" : "Couldn't add \(count) photos",
            message: message
        )
    }
}

// MARK: - Character Ring

/// How much of the limit is used: a ring that fills in ink, with the count left showing inside it for the last 20
/// characters and the overage in red past the limit.
private struct ComposeCharacterRing: View {
    let count: Int
    let limit: Int
    let size: CGFloat

    private static let lineWidth: CGFloat = 2
    private static let countdown = 20

    private var remaining: Int {
        limit - count
    }

    private var progress: CGFloat {
        min(1, CGFloat(count) / CGFloat(limit))
    }

    private var color: Color {
        remaining < 0 ? .red : .primary
    }

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(.quaternary, lineWidth: Self.lineWidth)
            Circle()
                .inset(by: Self.lineWidth / 2)
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if remaining <= Self.countdown {
                Text("\(remaining)")
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, Self.lineWidth * 2)
                    .contentTransition(.numericText(value: Double(remaining)))
            }
        }
        .frame(width: size, height: size)
        .animation(.smooth(duration: 0.2), value: count)
        .accessibilityElement()
        .accessibilityLabel("Characters remaining")
        .accessibilityValue("\(remaining)")
    }
}

// MARK: - Photo Tiles

/// An attached photo, filled into a square, with a glass remove button concentric with its corner.
private struct ComposePhotoThumbnail: View {
    let media: LoopMedia
    let side: CGFloat
    let cornerRadius: CGFloat
    let removeSize: CGFloat
    let onRemove: () -> Void

    var body: some View {
        CachedAsyncImage(url: URL(string: media.url), targetSize: CGSize(width: side, height: side)) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            Rectangle()
                .fill(.quaternary)
                .overlay {
                    ProgressView()
                        .controlSize(.small)
                }
        }
        .frame(width: side, height: side)
        // Circular corners, so the round remove button is exactly concentric with them
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .circular))
        .overlay(alignment: .topTrailing) {
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.primary)
                    .frame(width: removeSize, height: removeSize)
                    .glassEffect(.regular.interactive(), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(cornerRadius - removeSize / 2)
            .accessibilityLabel("Remove photo")
        }
    }
}

/// A photo still uploading, in the place it will take.
private struct ComposeUploadTile: View {
    let side: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .circular)
            .fill(.quaternary)
            .overlay {
                ProgressView()
                    .controlSize(.small)
            }
            .frame(width: side, height: side)
            .accessibilityLabel("Uploading photo")
    }
}

// MARK: - Playful Avatar

/// Makes the avatar something to play with. It floats a few points on a slow loop that never quite repeats, pops in
/// when the composer opens, follows a finger 1:1 at first and with more give the further it goes, grows and leans
/// while held, and springs back with a bounce when let go. Transforms only, so the text beside it never moves. With
/// Reduce Motion it holds still, fades in and settles back without bouncing.
private struct PlayfulAvatar: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState(resetTransaction: Transaction(animation: PlayfulAvatar.release)) private var translation: CGSize = .zero
    @GestureState(resetTransaction: Transaction(animation: PlayfulAvatar.release)) private var isHeld = false
    @State private var isShown = false

    /// Let go, it springs home with a bounce
    private static let release = Animation.spring(response: 0.45, dampingFraction: 0.5)
    /// Held, it tracks the finger with almost no lag
    private static let tracking = Animation.interactiveSpring(response: 0.12, dampingFraction: 0.86)
    /// The farthest a drag can pull it: the give grows until it never quite gets there
    private static let reach: CGFloat = 64

    func body(content: Content) -> some View {
        let offset = Self.rubberBanded(translation)
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let drift = reduceMotion ? Drift() : Drift(at: timeline.date.timeIntervalSinceReferenceDate)
            content
                .scaleEffect(isHeld ? 1.12 : 1)
                .rotationEffect(.degrees(reduceMotion ? 0 : Double(offset.width) * 0.35 + drift.tilt))
                // The drift is a transform: `.offset` lands on whole pixels, which made this slow motion step a
                // pixel at a time. The drag keeps `.offset`, which the release spring animates
                .transformEffect(CGAffineTransform(translationX: drift.offset.width, y: drift.offset.height))
                .offset(offset)
                .scaleEffect(isShown || reduceMotion ? 1 : 0.3)
                .opacity(isShown ? 1 : 0)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($translation) { value, state, transaction in
                    transaction.animation = Self.tracking
                    state = value.translation
                }
                .updating($isHeld) { _, state, transaction in
                    transaction.animation = Self.tracking
                    state = true
                }
        )
        .sensoryFeedback(trigger: isHeld) { _, held in
            held ? .impact(flexibility: .soft, intensity: 0.6) : nil
        }
        .onAppear {
            // After the sheet has mostly arrived, so the pop reads as the avatar's own
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.5, dampingFraction: 0.55).delay(0.15)) {
                isShown = true
            }
        }
    }

    /// Where the float has the avatar at a moment: two slow sines per axis at unrelated periods, up to about 3.5pt
    /// from rest, and a lean of up to 1.5 degrees
    private struct Drift {
        var offset: CGSize = .zero
        var tilt: Double = 0

        init() {}

        init(at time: TimeInterval) {
            func wave(_ period: Double, _ phase: Double = 0) -> Double {
                sin(2 * .pi * time / period + phase)
            }
            offset = CGSize(
                width: 2.5 * wave(6.1) + wave(2.9, 0.7),
                height: 2.5 * wave(7.3, 1.3) + wave(3.7, 2.1)
            )
            tilt = 1.5 * wave(5.3, 0.4)
        }
    }

    /// iOS's scroll rubber band applied to the drag's length: 1:1 for small moves, never past `reach`
    private static func rubberBanded(_ translation: CGSize) -> CGSize {
        let distance = hypot(translation.width, translation.height)
        guard distance > 0 else { return .zero }
        let banded = (1 - 1 / (distance / reach + 1)) * reach
        let scale = banded / distance
        return CGSize(width: translation.width * scale, height: translation.height * scale)
    }
}

// MARK: - Glass

/// Post in Liquid Glass like Follow on a profile: glass tinted ink once it can post, plain glass until then.
private struct ComposeGlassStyle: ViewModifier {
    let isProminent: Bool

    func body(content: Content) -> some View {
        if isProminent {
            content
                .buttonStyle(.glassProminent)
                .tint(.primary)
        } else {
            content
                .buttonStyle(.glass)
        }
    }
}

/// A failure shown over the composer, which stays open so nothing typed is lost.
private struct ComposeAlert {
    let title: String
    let message: String
}

#Preview {
    @Previewable @State var isPresented = true

    Color.clear
        .sheet(isPresented: $isPresented) {
            ComposeLoopView { _ in }
        }
}
