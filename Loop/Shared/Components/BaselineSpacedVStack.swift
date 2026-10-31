import SwiftUI
import UIKit

// MARK: - Visible Edges

extension VerticalAlignment {
    /// Where a view visibly starts. Defaults to its top; text marks the cap height of its first line with
    /// `visibleTopAtCapHeight(of:)`.
    static let visibleTop = VerticalAlignment(VisibleTop.self)
    /// Where a view visibly ends. Defaults to its last text baseline, which is its bottom when it has no text.
    static let visibleBottom = VerticalAlignment(VisibleBottom.self)

    private enum VisibleTop: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context[.top]
        }
    }

    private enum VisibleBottom: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context[.lastTextBaseline]
        }
    }
}

extension View {
    /// Marks the cap height of this text's first line as where it visibly starts.
    func visibleTopAtCapHeight(of textStyle: UIFont.TextStyle) -> some View {
        modifier(CapHeightVisibleTop(textStyle: textStyle))
    }
}

private struct CapHeightVisibleTop: ViewModifier {
    let textStyle: UIFont.TextStyle

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize))
        let capHeight = UIFont.preferredFont(forTextStyle: textStyle, compatibleWith: traits).capHeight
        content.alignmentGuide(.visibleTop) { $0[.firstTextBaseline] - capHeight }
    }
}

// MARK: - Baseline Spacing

/// A leading-aligned vertical stack that spaces its views by what the eye sees: each gap runs from where the view
/// above visibly ends (its last text baseline, or its bottom) to where the next one visibly starts (its top, or the
/// cap height of its first line when marked). It reports its first view's visible top and its last view's visible
/// bottom as its own, so stacks nest.
struct BaselineSpacedVStack: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let frames = frames(width: proposal.width, subviews: subviews)
        let width = proposal.width ?? frames.map(\.maxX).max() ?? 0
        return CGSize(width: width, height: frames.last?.maxY ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (subview, frame) in zip(subviews, frames(width: bounds.width, subviews: subviews)) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    func explicitAlignment(
        of guide: VerticalAlignment,
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGFloat? {
        let frames = frames(width: bounds.width, subviews: subviews)
        if guide == .visibleTop, let first = subviews.first, let frame = frames.first {
            return bounds.minY + frame.minY + first.dimensions(in: ProposedViewSize(frame.size))[.visibleTop]
        }
        if guide == .visibleBottom, let last = subviews.last, let frame = frames.last {
            return bounds.minY + frame.minY + last.dimensions(in: ProposedViewSize(frame.size))[.visibleBottom]
        }
        return nil
    }

    private func frames(width: CGFloat?, subviews: Subviews) -> [CGRect] {
        var frames: [CGRect] = []
        var visibleBottomAbove: CGFloat?
        for subview in subviews {
            let dimensions = subview.dimensions(in: ProposedViewSize(width: width, height: nil))
            let top = visibleBottomAbove.map { $0 + spacing - dimensions[.visibleTop] } ?? 0
            frames.append(CGRect(x: 0, y: top, width: dimensions.width, height: dimensions.height))
            visibleBottomAbove = top + dimensions[.visibleBottom]
        }
        return frames
    }
}
