#if DEBUG
import SwiftUI

/// Debug overlay for checking alignment: a 4pt grid, stronger lines every 8pt, and the feed's column guides.
/// Toggle it from the debug menu. Compiled out of release builds.
struct LayoutGridOverlay: View {
    private let unit: CGFloat = 4

    /// Leading edge of avatars: list inset plus card padding.
    private var marginGuide: CGFloat { CardLayoutConstants.horizontalPadding * 2 }
    /// Where names and shifted content start.
    private var contentGuide: CGFloat { marginGuide + CardLayoutConstants.contentShift }

    var body: some View {
        Canvas { context, size in
            var minorLines = Path()
            var majorLines = Path()

            for index in 0...Int(size.width / unit) {
                let x = CGFloat(index) * unit
                var line = Path()
                line.move(to: CGPoint(x: x, y: 0))
                line.addLine(to: CGPoint(x: x, y: size.height))
                if index % 2 == 0 { majorLines.addPath(line) } else { minorLines.addPath(line) }
            }
            for index in 0...Int(size.height / unit) {
                let y = CGFloat(index) * unit
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: size.width, y: y))
                if index % 2 == 0 { majorLines.addPath(line) } else { minorLines.addPath(line) }
            }

            let hairline = 1 / max(context.environment.displayScale, 1)
            context.stroke(minorLines, with: .color(.pink.opacity(0.10)), lineWidth: hairline)
            context.stroke(majorLines, with: .color(.pink.opacity(0.22)), lineWidth: hairline)

            var guides = Path()
            for x in [marginGuide, contentGuide, size.width - marginGuide] {
                guides.move(to: CGPoint(x: x, y: 0))
                guides.addLine(to: CGPoint(x: x, y: size.height))
            }
            context.stroke(guides, with: .color(.cyan.opacity(0.8)), lineWidth: hairline * 2)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

#Preview {
    LayoutGridOverlay()
}
#endif
