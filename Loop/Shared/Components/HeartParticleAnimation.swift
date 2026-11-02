import SwiftUI

// MARK: - Particle

/// One small heart in a like burst. It pops out of the like button's heart, arcs over and lands upright on the
/// shelf below (the divider under the post), hops once and sits there until the burst fades. Its motion is a
/// closed-form function of time, so nothing is stored per frame.
struct HeartParticle {
    /// Where it comes to rest, across from the heart's center
    let landingOffset: CGFloat
    /// How far its arc rises above the heart's center
    let apexHeight: CGFloat
    let scale: CGFloat
    /// Its tilt as it leaves the heart. It turns at a steady rate and lands upright
    let launchTilt: Angle

    /// Points per second squared: a heart takes about half a second to arc over and come down onto the divider
    static let gravity: CGFloat = 1100
    /// The share of its landing speed a heart keeps for its one hop
    static let restitution: CGFloat = 0.3

    struct Pose {
        var position: CGPoint
        var tilt: Angle
        var opacity: Double
    }

    /// Its pose `time` seconds into a burst from `origin`. With a shelf, it lands with the bottom of its ink on the
    /// shelf's top edge; `inkBelowCenter` is how far the heart's ink reaches below its center at full size. With
    /// no shelf it fades out on the way down, gone by the time it is back at the heart's height.
    func pose(at time: Double, from origin: CGPoint, shelf: CGRect?, inkBelowCenter: CGFloat, halfWidth: CGFloat) -> Pose {
        let g = Self.gravity
        let t = CGFloat(time)

        // Where it lands, kept on the shelf's length
        var landingX = origin.x + landingOffset
        if let shelf {
            landingX = min(max(landingX, shelf.minX + halfWidth * scale), shelf.maxX - halfWidth * scale)
        }
        // How far below the heart's center its own center comes to rest
        let rest = shelf.map { $0.minY - inkBelowCenter * scale - origin.y } ?? 0

        let rise = sqrt(2 * apexHeight / g)
        let fall = sqrt(2 * (apexHeight + rest) / g)
        let landing = rise + fall

        if t < landing {
            let progress = t / landing
            return Pose(
                position: CGPoint(x: origin.x + (landingX - origin.x) * progress, y: origin.y - g * rise * t + g * t * t / 2),
                tilt: launchTilt * Double(1 - progress),
                opacity: shelf == nil ? Double(min(1, (landing - t) / (landing - rise))) : LikeBurst.opacity(at: time)
            )
        }

        guard shelf != nil else {
            return Pose(position: CGPoint(x: landingX, y: origin.y), tilt: .zero, opacity: 0)
        }

        // One hop straight up, then still
        let hopSpeed = Self.restitution * g * fall
        let hop = max(0, t - landing)
        let lift = hop < 2 * hopSpeed / g ? hopSpeed * hop - g * hop * hop / 2 : 0
        return Pose(
            position: CGPoint(x: landingX, y: origin.y + rest - lift),
            tilt: .zero,
            opacity: LikeBurst.opacity(at: time)
        )
    }
}

// MARK: - Burst

/// The hearts one tap on a like button sends out, and when
struct LikeBurst: Identifiable {
    let id = UUID()
    let startDate: Date
    let particles: [HeartParticle]

    /// The hearts rest on the shelf until this many seconds into the burst, then fade together
    static let fadeStart: Double = 1.0
    static let fadeDuration: Double = 0.3
    static var duration: Double { fadeStart + fadeDuration }

    static func opacity(at time: Double) -> Double {
        min(1, max(0, (duration - time) / fadeDuration))
    }

    /// Seven hearts landing evenly from just left of the heart to past the comment button, the side the post's
    /// actions and the divider extend to, each with a little random variation. Their arcs top out 10 to 16pt above
    /// the heart's center, so even a full-size heart (its ink 4.15pt above its center) stays clear of the descenders
    /// of the post's last line, which end 22pt above the heart's center.
    static func make(at startDate: Date = .now) -> LikeBurst {
        let count = 7
        let particles = (0..<count).map { index in
            HeartParticle(
                landingOffset: -6 + 84 * CGFloat(index) / CGFloat(count - 1) + .random(in: -3...3),
                apexHeight: .random(in: 10...16),
                scale: .random(in: 0.7...1.0),
                launchTilt: .degrees(.random(in: -40...40))
            )
        }
        return LikeBurst(startDate: startDate, particles: particles)
    }
}

// MARK: - Layer

/// The like buttons inside a view, with the bursts each is playing, and the shelves their hearts can land on
private struct LikeBurstLayout {
    struct Heart {
        let bounds: Anchor<CGRect>
        let bursts: [LikeBurst]
    }

    var hearts: [Heart] = []
    var shelves: [Anchor<CGRect>] = []
}

private struct LikeBurstLayoutKey: PreferenceKey {
    static let defaultValue = LikeBurstLayout()

    static func reduce(value: inout LikeBurstLayout, nextValue: () -> LikeBurstLayout) {
        let next = nextValue()
        value.hearts += next.hearts
        value.shelves += next.shelves
    }
}

extension View {
    /// Reports this heart and the bursts it is playing to the enclosing `likeBurstLayer()`, which draws them from
    /// the heart's center
    func likeBurstSource(_ bursts: [LikeBurst]) -> some View {
        anchorPreference(key: LikeBurstLayoutKey.self, value: .bounds) {
            LikeBurstLayout(hearts: [LikeBurstLayout.Heart(bounds: $0, bursts: bursts)])
        }
    }

    /// Marks this view's top edge as a shelf the hearts of a like burst land on
    func likeBurstShelf() -> some View {
        anchorPreference(key: LikeBurstLayoutKey.self, value: .bounds) { LikeBurstLayout(shelves: [$0]) }
    }

    /// Draws the like bursts started inside this view over it, so the hearts can leave the post that started them
    /// and land on a shelf inside this view. Put it on a feed row: the post and the divider below it.
    func likeBurstLayer() -> some View {
        overlayPreferenceValue(LikeBurstLayoutKey.self) { layout in
            if layout.hearts.contains(where: { !$0.bursts.isEmpty }) {
                LikeBurstCanvas(layout: layout)
            }
        }
        // The bursts are drawn here, not again by a layer further out
        .transformPreference(LikeBurstLayoutKey.self) { $0 = LikeBurstLayout() }
    }
}

private struct LikeBurstCanvas: View {
    let layout: LikeBurstLayout

    private struct Flight {
        let origin: CGPoint
        let shelf: CGRect?
        let bursts: [LikeBurst]
    }

    private let heartSymbolID = 0
    /// SF Symbols carry a margin: heart.fill's ink fills this share of its frame's height, centered in it (16.67 of
    /// 20pt at 18pt, 80.67 of 97pt at 90pt, measured at 3x on the iOS 27 simulator). A landed heart rests its ink,
    /// not its frame, on the shelf.
    private static let heartInkHeight: CGFloat = 0.83

    var body: some View {
        GeometryReader { proxy in
            let flights = flights(in: proxy)
            TimelineView(.animation) { timeline in
                Canvas { context, _ in
                    guard let heart = context.resolveSymbol(id: heartSymbolID) else { return }
                    for flight in flights {
                        for burst in flight.bursts {
                            let time = timeline.date.timeIntervalSince(burst.startDate)
                            guard time >= 0, time < LikeBurst.duration else { continue }

                            for particle in burst.particles {
                                let pose = particle.pose(
                                    at: time,
                                    from: flight.origin,
                                    shelf: flight.shelf,
                                    inkBelowCenter: heart.size.height * Self.heartInkHeight / 2,
                                    halfWidth: heart.size.width / 2
                                )
                                var heartContext = context
                                heartContext.opacity = pose.opacity
                                heartContext.translateBy(x: pose.position.x, y: pose.position.y)
                                heartContext.rotate(by: pose.tilt)
                                heartContext.scaleBy(x: particle.scale, y: particle.scale)
                                heartContext.draw(heart, at: .zero)
                            }
                        }
                    }
                } symbols: {
                    Image(systemName: "heart.fill")
                        .font(.system(size: CardLayoutConstants.actionButtonIconSize / 2))
                        .foregroundStyle(.red)
                        .tag(heartSymbolID)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Each playing heart's center, and the shelf its hearts land on: the first one below it, unless another like
    /// button sits between them. Then the post goes on below the heart (a reply, more of the thread), and its hearts
    /// fade out on the way down rather than fall through it.
    private func flights(in proxy: GeometryProxy) -> [Flight] {
        let hearts = layout.hearts.map { (frame: proxy[$0.bounds], bursts: $0.bursts) }
        let shelves = layout.shelves.map { proxy[$0] }
        return hearts.filter { !$0.bursts.isEmpty }.map { heart in
            let origin = CGPoint(x: heart.frame.midX, y: heart.frame.midY)
            let shelf = shelves.filter { $0.minY > origin.y }.min { $0.minY < $1.minY }
            let isCovered = shelf.map { shelf in
                hearts.contains { $0.frame.midY > origin.y && $0.frame.midY < shelf.minY }
            } ?? false
            return Flight(origin: origin, shelf: isCovered ? nil : shelf, bursts: heart.bursts)
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var likes = 0

    BaselineSpacedVStack(spacing: CardLayoutConstants.partSpacing) {
        PostActions(isLiked: likes > 0, likeCount: likes, onLike: { likes += 1 }, commentCount: 2, onComment: {})
        PostDivider()
    }
    .likeBurstLayer()
    .padding()
}
