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
                LinearKeyframe(1.0, duration: Self.sweepDuration, timingCurve: .easeInOut)
            }
            .task {
                // SwiftUI otherwise compiles the shader on its first use, and on a fresh install that stall cost the
                // first pass about half its frames. If this fails, it still compiles on first use
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

    /// The rod is as wide as an o (534.5 font units), so it bends one letter at a time and an o centered in it
    /// fills it.
    private var rodRadius: CGFloat {
        ascender * 534.5 / 2 / 710
    }

    /// The farthest the rod moves any color: a glass rod's shift peaks at 0.2313 of its radius, and blue bends
    /// further by the dispersion. Rounded up to whole points so the padded layer stays on the pixel grid; 2 at
    /// the toolbar size (1.70 before rounding).
    private var rodReach: CGFloat {
        (rodRadius * 0.2313 * (1 + Self.dispersion)).rounded(.up)
    }

    /// Real glass parts red from blue by about 1 percent of the shift, which no one could see at this size. 15
    /// percent puts them 1.3 pixels apart where the rod bends most (3x): a colored edge, not a doubled one.
    private nonisolated static let dispersion: CGFloat = 0.15

    /// One pass in 0.7 seconds, eased in and out like something rolled by hand. The rod is over the letters for
    /// about half a second of it (its slow ends fall on the margins) and crosses an o in under a tenth of a second
    /// at full speed, so it reads as one quick pass rather than a scan.
    private static let sweepDuration: TimeInterval = 0.7
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
