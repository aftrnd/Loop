import SwiftUI

/// The shape of every avatar: a square with continuous corners that scale with its side, so avatars of every size
/// share one silhouette. 16pt on the feed's 56pt avatar.
struct AvatarShape: Shape {
    /// The corner radius as a share of the side
    static let cornerRatio: CGFloat = 2 / 7

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        return RoundedRectangle(cornerRadius: side * Self.cornerRatio, style: .continuous).path(in: rect)
    }
}
