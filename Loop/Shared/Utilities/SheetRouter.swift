import SwiftUI
import FirebaseAuth

/// Presents profiles and threads from the root of the app, outside the tab view.
///
/// On iOS 27, a sheet presented from inside a tab stops applying its detent changes once it contains a sheet
/// or full-screen cover of its own (Edit Profile, the photo viewer), so a profile card kept the height it opened
/// at. The same sheet presented from the root sizes correctly. Checked in the iOS 27.0 simulator and seen on an
/// iOS 27.2 device.
@MainActor
@Observable
final class SheetRouter {
    enum Sheet: Identifiable {
        /// A profile; nil is the signed-in user's own. The preview, when there is one, lets it open at its
        /// final height.
        case profile(userId: String?, preview: ProfilePreview?)
        /// A post and its replies; `onRepliesChanged` lets the feed refresh its reply preview
        case thread(Loop, onRepliesChanged: (() -> Void)?)
        /// A new loop or a reply. The composer changes its height as you type and holds a photo picker and a
        /// camera cover, so it presents from here like profiles. `onPost` creates the loop and throws to keep it open
        case compose(LoopDraft, onPost: (LoopDraft) async throws -> Void)

        var id: String {
            switch self {
            case .profile(let userId, _): "profile-\(userId ?? "me")"
            case .thread(let loop, _): "thread-\(loop.id)"
            case .compose: "compose"
            }
        }
    }

    var sheet: Sheet?
    /// How profile sheets will be laid out, kept current by the root view
    var profileLayout: ProfileLayoutContext?

    /// Shows a profile. If it is already cached (feed authors and chat participants are, and your own once it has
    /// been shown), its collapsed card height is worked out now, so the sheet opens at that height rather than
    /// moving after it appears.
    func showProfile(userId: String?) {
        var preview: ProfilePreview?
        let shownUserId = userId ?? Auth.auth().currentUser?.uid
        if let shownUserId, let profileLayout, let user = FirebaseService.shared.cachedUser(withId: shownUserId) {
            preview = ProfilePreview(user: user, collapsedHeight: ProfileView.collapsedCardHeight(for: user, in: profileLayout))
        }
        sheet = .profile(userId: userId, preview: preview)
    }

    func showThread(_ loop: Loop, onRepliesChanged: (() -> Void)? = nil) {
        sheet = .thread(loop, onRepliesChanged: onRepliesChanged)
    }

    func showCompose(_ draft: LoopDraft = LoopDraft(), onPost: @escaping (LoopDraft) async throws -> Void) {
        sheet = .compose(draft, onPost: onPost)
    }

    /// Whether the sheet showing is this user's profile
    func isShowingProfile(userId: String) -> Bool {
        if case .profile(let shownId, _) = sheet {
            return shownId == userId
        }
        return false
    }
}
