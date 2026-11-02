import SwiftUI

/// The Loop wordmark: "loop" set in Geist at weight 650 and outlined, so it draws the same at every size.
/// The artwork is a template vector in the asset catalog cropped to the ink, so it follows the foreground style.
struct LoopWordmark: View {
    /// Height of the l's ascender in points; 17 matches the toolbar size on the brand proof.
    var ascender: CGFloat = 17
    /// Each change rolls a glass rod across the wordmark once (`GlassRod.metal`). Home changes it when a pull to
    /// refresh starts. The rod is drawn over the system background, which is what sits behind Home's toolbar.
    var glassSweeps = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // The animator's closure is Sendable, so it gets plain values rather than the view's properties
        let height = ascender * Self.heightPerAscender
        let radius = rodRadius
        let reach = rodReach
        let sweeps = !reduceMotion

        Self.mark(height: height)
            .keyframeAnimator(initialValue: 0.0, trigger: glassSweeps) { wordmark, progress in
                // The rod draws over the wordmark, only while it passes and only where it is. The wordmark itself
                // never goes through the effect: an offscreen layer smooths its curves slightly differently
                wordmark.overlay {
                    if sweeps && progress > 0 && progress < 1 {
                        Self.mark(height: height)
                            // Room for letters the rod pushes past the ends, taken back so the copy lines up
                            .padding(.horizontal, reach)
                            .layerEffect(
                                Self.rod(at: progress, radius: radius),
                                maxSampleOffset: CGSize(width: reach, height: 0)
                            )
                            .padding(.horizontal, -reach)
                            .accessibilityHidden(true)
                    }
                }
            } keyframes: { _ in
                LinearKeyframe(1.0, duration: Self.sweepDuration, timingCurve: Self.sweepCurve)
            }
            .task(id: reduceMotion) {
                // SwiftUI otherwise compiles the shader on its first use, and on a fresh install that stall cost the
                // first pass about half its frames. Once per launch, and not while Reduce Motion keeps the rod
                // from drawing. If this fails, it still compiles on first use
                guard !reduceMotion, !Self.rodCompileStarted else { return }
                Self.rodCompileStarted = true
                try? await Self.rod(at: 0, radius: radius).compile(as: .layerEffect)
            }
            .accessibilityLabel(AppInfo.name)
            .accessibilityAddTraits(.isHeader)
    }

    private nonisolated static func mark(height: CGFloat) -> some View {
        Image("LoopWordmark")
            .resizable()
            .scaledToFit()
            .frame(height: height)
            .foregroundStyle(.primary)
    }

    /// Ink height (ascender 710 plus descender 150, in font units) over the ascender.
    private static let heightPerAscender: CGFloat = 860 / 710

    // MARK: - Glass Sweep

    /// The rod `progress` of the way along its pass, drawn over the system background
    private nonisolated static func rod(at progress: Double, radius: CGFloat) -> Shader {
        ShaderLibrary.glassRod(
            .boundingRect,
            .float(progress),
            .float(radius),
            .float(dispersion),
            .color(Color(.systemBackground))
        )
    }

    /// The rod is as wide as the wordmark is tall, so the band it bends is a square on the letters. That holds about
    /// a letter and a half: a whole o swells under its middle while the rest of the word stands still beside it to
    /// show the bend. The shift peaks at 2.4 points at the toolbar size, about 0.7 of a stem (3.3 points), so
    /// strokes visibly step sideways. A rod two o's wide squeezed the p's stem to a hairline at its rim, which
    /// reads as damage rather than glass.
    private var rodRadius: CGFloat {
        ascender * Self.heightPerAscender / 2
    }

    /// The farthest the rod moves any color: a glass rod's shift peaks at 0.2313 of its radius, and blue bends
    /// further by the dispersion. Rounded up to whole points so the padded layer stays on the pixel grid; 3 at
    /// the toolbar size (2.98 before rounding).
    private var rodReach: CGFloat {
        (rodRadius * 0.2313 * (1 + Self.dispersion)).rounded(.up)
    }

    /// Real glass parts red from blue by about 2 percent of the shift, which no one could see at this size. A
    /// quarter puts them 1.2 points apart where the rod bends most, a third of a stem: wide enough for an eye at
    /// arm's length to see the edge as colored (color vision resolves several times coarser than light and dark),
    /// and still an edge rather than a doubled letter.
    private nonisolated static let dispersion: CGFloat = 0.25

    /// One pass in a second. The rod reaches the l about 0.09 seconds after the pull starts the refresh, and an eye
    /// on the feed takes about a fifth of a second to move up to it, so it arrives with most of the pass still to
    /// come. Each letter is under the glass for about a quarter of a second, long enough for its bend to read as a
    /// shape rather than a flicker, and the rod is off the letters by 0.91 seconds.
    private static let sweepDuration: TimeInterval = 1.0

    /// The rod is already moving when it reaches the l and still moving when it leaves the p: its speed builds and
    /// falls mostly while it is off the letters, and its middle crosses every letter at 80 to 90 points a second, so
    /// no letter gets a longer look than another and nothing slows to a stop in view.
    private static let sweepCurve = UnitCurve.bezier(
        startControlPoint: UnitPoint(x: 0.2, y: 0),
        endControlPoint: UnitPoint(x: 0.8, y: 1)
    )

    /// Set once the background compile has started, so it runs once per launch however often the wordmark appears.
    private static var rodCompileStarted = false
}

// MARK: - Preview

#Preview {
    @Previewable @State var sweeps = 0

    VStack(spacing: 32) {
        LoopWordmark(ascender: 64, glassSweeps: sweeps)
        LoopWordmark(glassSweeps: sweeps)
        Button("Sweep") { sweeps += 1 }
    }
    .padding()
}
