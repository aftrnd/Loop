import SwiftUI

/// The light behind a profile's header: the person's own wallpaper and avatar, blurred where they sit, spilling down
/// from the wallpaper's bottom edge and fading into the page's pure white or black where the header ends. The app
/// stays black and white; the profile takes its color only from these two photos, and its text never changes color.
struct ProfileHeaderLight: View {
    let bannerURL: URL?
    let avatarURL: URL?
    /// Where the wallpaper ends and the light starts, from the header's top
    let bannerHeight: CGFloat
    /// The avatar's center, from the header's top leading corner
    let avatarCenter: CGPoint
    let avatarSize: CGFloat
    /// The ring around the avatar, kept clear of light so it shows the page all the way round
    let ringSize: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    /// Samples of the falloff curve. Straight between them, the gradient stays within one 8-bit step of the curve,
    /// so it never shows bands
    private static let falloffSteps = 32

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            if size.width > 0, size.height > bannerHeight {
                field(size: size)
                    .mask(alignment: .topLeading) {
                        mask(size: size)
                    }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The most light primary text can sit on and keep 4.5:1 whatever the photo (WCAG luminance, sRGB blending): a
    /// black photo under black text up to 54% over white, a white photo under white text up to 46% over black
    private var limit: Double {
        colorScheme == .dark ? 0.46 : 0.54
    }

    // MARK: - Mask

    private func mask(size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(stops: falloff(height: size.height), startPoint: .top, endPoint: .bottom)
            Circle()
                .frame(width: ringSize, height: ringSize)
                .position(avatarCenter)
                .blendMode(.destinationOut)
        }
        .frame(width: size.width, height: size.height)
        .compositingGroup()
    }

    /// Nothing under the wallpaper, then from the legible limit at its edge to nothing at the header's end, as the
    /// square of the distance left: strongest where it leaves the photo and meeting the page with zero slope, so the
    /// header has no bottom edge. The step sits 1 pt above the edge, under the photo, so a fractional offset can't
    /// open a hairline between the photo and its light. With no wallpaper the light also fills the wallpaper's frame.
    private func falloff(height: CGFloat) -> [Gradient.Stop] {
        let edge = bannerHeight / height
        let step = (bannerHeight - 1) / height
        let top = bannerURL == nil ? limit : 0
        var stops = [
            Gradient.Stop(color: .black.opacity(top), location: 0),
            Gradient.Stop(color: .black.opacity(top), location: step),
            Gradient.Stop(color: .black.opacity(limit), location: step)
        ]
        for index in 0...Self.falloffSteps {
            let t = Double(index) / Double(Self.falloffSteps)
            let opacity = limit * (1 - t) * (1 - t)
            stops.append(Gradient.Stop(color: .black.opacity(opacity), location: edge + (1 - edge) * CGFloat(t)))
        }
        return stops
    }

    // MARK: - Field

    /// The pictures where they sit, blurred into light. Below the wallpaper it repeats down the header with every
    /// other copy mirrored, so the light under the edge continues the colors at the edge (the way SwiftUI's
    /// background extension effect extends a view), and the avatar is drawn in place so its colors spill around it
    @ViewBuilder
    private func field(size: CGSize) -> some View {
        if let bannerURL {
            CachedAsyncImage(url: bannerURL) { banner in
                ZStack(alignment: .topLeading) {
                    VStack(spacing: 0) {
                        ForEach(0..<tileCount(height: size.height), id: \.self) { index in
                            // Cropped exactly like the wallpaper, so the first copy lines up with the photo
                            banner
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: size.width, height: bannerHeight)
                                .clipped()
                                .scaleEffect(x: 1, y: index.isMultiple(of: 2) ? 1 : -1)
                        }
                    }
                    if let avatarURL {
                        CachedAsyncImage(url: avatarURL) { avatar in
                            avatar
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.clear
                        }
                        .frame(width: avatarSize, height: avatarSize)
                        .clipShape(Circle())
                        .position(avatarCenter)
                    }
                }
                .frame(width: size.width, height: size.height, alignment: .topLeading)
                .clipped()
                // The avatar's radius: color regions the avatar's size survive, while faces, horizons and text in
                // the photo dissolve. Opaque, so the sheet's edges don't pull the light toward transparent
                .blur(radius: avatarSize / 2, opaque: true)
            } placeholder: {
                Color.clear
            }
        } else if let avatarURL {
            // No wallpaper: the portrait, filling the header, is the light. Magnified about 4.5 times, it needs the
            // avatar's full diameter of blur before only its palette is left
            CachedAsyncImage(url: avatarURL) { avatar in
                avatar
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .blur(radius: avatarSize, opaque: true)
            } placeholder: {
                Color.clear
            }
        }
    }

    /// Enough wallpaper-height copies to reach the header's end
    private func tileCount(height: CGFloat) -> Int {
        max(1, Int((height / bannerHeight).rounded(.up)))
    }
}
