import SwiftUI

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

        var id: String {
            switch self {
            case .profile(let userId, _): "profile-\(userId ?? "me")"
            case .thread(let loop, _): "thread-\(loop.id)"
            }
        }
    }

    var sheet: Sheet?
    /// How profile sheets will be laid out, kept current by the root view
    var profileLayout: ProfileLayoutContext?

    /// Shows a profile. If it is already cached (feed authors and chat participants are), its collapsed card
    /// height is worked out now, so the sheet opens at that height rather than moving after it appears.
    func showProfile(userId: String?) {
        var preview: ProfilePreview?
        if let userId, let profileLayout, let user = FirebaseService.shared.cachedUser(withId: userId) {
            preview = ProfilePreview(user: user, collapsedHeight: ProfileView.collapsedCardHeight(for: user, in: profileLayout))
        }
        sheet = .profile(userId: userId, preview: preview)
    }

    func showThread(_ loop: Loop, onRepliesChanged: (() -> Void)? = nil) {
        sheet = .thread(loop, onRepliesChanged: onRepliesChanged)
    }

    /// Whether the sheet showing is this user's profile
    func isShowingProfile(userId: String) -> Bool {
        if case .profile(let shownId, _) = sheet {
            return shownId == userId
        }
        return false
    }
}
