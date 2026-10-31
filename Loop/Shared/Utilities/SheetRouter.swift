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
        /// A profile; nil is the signed-in user's own
        case profile(userId: String?)
        /// A post and its replies; `onRepliesChanged` lets the feed refresh its reply preview
        case thread(Loop, onRepliesChanged: (() -> Void)?)

        var id: String {
            switch self {
            case .profile(let userId): "profile-\(userId ?? "me")"
            case .thread(let loop, _): "thread-\(loop.id)"
            }
        }
    }

    var sheet: Sheet?

    func showProfile(userId: String?) {
        sheet = .profile(userId: userId)
    }

    func showThread(_ loop: Loop, onRepliesChanged: (() -> Void)? = nil) {
        sheet = .thread(loop, onRepliesChanged: onRepliesChanged)
    }

    /// Whether the sheet showing is this user's profile
    func isShowingProfile(userId: String) -> Bool {
        if case .profile(let shownId) = sheet {
            return shownId == userId
        }
        return false
    }
}
