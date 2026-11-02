import SwiftUI

/// The story a topic post links to, set in ink: the story's photo inside an ink frame, with the headline in a tab of
/// the frame cut from the photo's bottom leading corner. A big story's photo is 4:3 and any other's 5:2; a story
/// without a photo is all ink. The whole card opens the story.
struct NewsLinkCard: View {
    let link: LoopLink

    @Environment(\.openURL) private var openURL

    private var imageURL: URL? {
        link.imageURL.flatMap { URL(string: $0) }
    }

    /// A big story without a photo is set like any other story without one
    private var style: NewsCardLayout.Style {
        guard imageURL != nil else { return .plain }
        return link.isLead ? .lead : .compact
    }

    var body: some View {
        Button {
            if let url = URL(string: link.url) {
                openURL(url)
            }
        } label: {
            NewsCardLayout(style: style) {
                if let imageURL {
                    photo(imageURL)
                    CutoutTab()
                        .fill(Color.primary)
                }
                headline
            }
            .background(Color.primary)
            .clipShape(RoundedRectangle(cornerRadius: NewsCardMetrics.cornerRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: NewsCardMetrics.cornerRadius, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.98))
        // A card visibly starts and ends at its own edges, not at the text inside it
        .alignmentGuide(.visibleTop) { $0[.top] }
        .alignmentGuide(.visibleBottom) { $0[.bottom] }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(link.title), \(link.source)")
        .accessibilityAddTraits(.isLink)
    }

    // MARK: - Parts

    /// The publisher's headline, reversed out of the ink
    private var headline: some View {
        let isLead = style == .lead
        return Text(link.title)
            .font(isLead ? .title3.weight(.bold) : .headline)
            .foregroundStyle(Color(.systemBackground))
            .multilineTextAlignment(.leading)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
            .visibleTopAtCapHeight(of: isLead ? .title3 : .headline)
    }

    /// The story's photo filling its place in the frame, its corners concentric with the card's
    private func photo(_ url: URL) -> some View {
        Color(.systemGray5)
            .overlay {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.clear
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: NewsCardMetrics.photoRadius, style: .continuous))
    }
}

// MARK: - Metrics

/// Every measurement follows from the card's corner and the frame: the photo's corners are concentric with the card's,
/// and the tab's padding, the tab's corner and the photo's corners where it meets the tab all match them
private enum NewsCardMetrics {
    static let cornerRadius: CGFloat = 20
    /// How far the photo sits inside the card
    static let frame: CGFloat = 8
    static let photoRadius: CGFloat = cornerRadius - frame
    /// The tab's room above the headline's capitals and past its longest line. It is also the tab's corner, so the
    /// corner's arc is centered on the corner of the headline's block
    static let tabPadding: CGFloat = photoRadius
    /// How far a continuous corner runs along each edge, in radii (measured on the simulator: 30.33pt for 20)
    static let cornerRun: CGFloat = 1.52
    /// The tab is never shorter than the two corners on its trailing side, its own and the photo's past it: 37pt
    static let minTabHeight: CGFloat = (cornerRun * (tabPadding + photoRadius)).rounded(.up)
    /// How far the tab's ink runs past its top and trailing edges, room for the photo's corners where it meets them
    static let tabReach: CGFloat = 2 * photoRadius
    /// A card without a photo pads its headline by the card's corner, from its capitals and its last baseline, so the
    /// headline's block has its corners on the centers of the card's. The frame plus the tab's padding comes to the same
    static let plainPadding: CGFloat = cornerRadius
}

// MARK: - Layout

/// Places a news card's parts in one pass, so the tab is drawn where the headline lands. With a photo the subviews are
/// [photo, tab, headline]: the photo sits in the frame at its style's shape, the headline's leading edge sits on the
/// photo's and its last baseline on the photo's bottom edge, and the tab runs from the card's leading and bottom edges
/// to its padding above the headline's capitals and past its longest line. Without a photo the one subview is the
/// headline, padded from every edge.
private struct NewsCardLayout: Layout {
    enum Style {
        /// A big story: the photo at 4:3, the headline in title 3
        case lead
        /// Any other story with a photo: the photo at 5:2
        case compact
        /// A story without a photo
        case plain
    }

    let style: Style

    /// Each subview's origin in the card and the size it is offered, in subview order, and the card's height
    private struct Placement {
        var height: CGFloat
        var subviews: [(origin: CGPoint, proposal: ProposedViewSize)]
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.replacingUnspecifiedDimensions().width
        return CGSize(width: width, height: placement(width: width, subviews: subviews).height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let placement = placement(width: bounds.width, subviews: subviews)
        for (subview, place) in zip(subviews, placement.subviews) {
            subview.place(
                at: CGPoint(x: bounds.minX + place.origin.x, y: bounds.minY + place.origin.y),
                proposal: place.proposal
            )
        }
    }

    private func placement(width: CGFloat, subviews: Subviews) -> Placement {
        let photoHeightRatio: CGFloat
        switch style {
        case .lead: photoHeightRatio = 3.0 / 4.0
        case .compact: photoHeightRatio = 2.0 / 5.0
        case .plain: return plainPlacement(width: width, subviews: subviews)
        }
        guard subviews.count == 3 else { return Placement(height: 0, subviews: []) }

        let frame = NewsCardMetrics.frame
        let photoWidth = max(0, width - 2 * frame)
        // Whole points, so the card ends on a pixel
        let photo = CGRect(x: frame, y: frame, width: photoWidth, height: (photoWidth * photoHeightRatio).rounded())
        // The header's text column: the card's width less the avatar's
        let measure = ProposedViewSize(width: max(0, width - CardLayoutConstants.contentShift), height: nil)
        let headline = subviews[2].dimensions(in: measure)
        let headlineTop = photo.maxY - headline[.lastTextBaseline]
        let tabTop = min(headlineTop + headline[.visibleTop] - NewsCardMetrics.tabPadding, photo.maxY - NewsCardMetrics.minTabHeight)
        let tabTrailing = photo.minX + headline.width + NewsCardMetrics.tabPadding
        let height = photo.height + 2 * frame
        let reach = NewsCardMetrics.tabReach
        return Placement(height: height, subviews: [
            (photo.origin, ProposedViewSize(photo.size)),
            (CGPoint(x: 0, y: tabTop - reach), ProposedViewSize(width: tabTrailing + reach, height: height - tabTop + reach)),
            (CGPoint(x: photo.minX, y: headlineTop), measure)
        ])
    }

    private func plainPlacement(width: CGFloat, subviews: Subviews) -> Placement {
        guard let headline = subviews.first else { return Placement(height: 0, subviews: []) }
        let padding = NewsCardMetrics.plainPadding
        let measure = ProposedViewSize(width: max(0, width - 2 * padding), height: nil)
        let dimensions = headline.dimensions(in: measure)
        return Placement(
            height: padding + dimensions[.visibleBottom] - dimensions[.visibleTop] + padding,
            subviews: [(CGPoint(x: padding, y: padding - dimensions[.visibleTop]), measure)]
        )
    }
}

// MARK: - Tab

/// The ink the headline sits on, drawn over the photo in a rect from the card's leading and bottom edges to
/// `NewsCardMetrics.tabReach` past the tab's top and trailing edges. The tab is square where it meets the frame and
/// rounded where it turns into the photo, and the ink fills in outside the photo's own corners where the photo meets
/// the tab. Every curve is a continuous corner
private struct CutoutTab: Shape {
    func path(in rect: CGRect) -> Path {
        let reach = NewsCardMetrics.tabReach
        let tabTrailing = rect.maxX - reach
        let tabTop = rect.minY + reach
        let photoLeading = rect.minX + NewsCardMetrics.frame
        let photoBottom = rect.maxY - NewsCardMetrics.frame
        let tab = UnevenRoundedRectangle(topTrailingRadius: NewsCardMetrics.tabPadding, style: .continuous)
            .path(in: CGRect(x: rect.minX, y: tabTop, width: tabTrailing - rect.minX, height: rect.maxY - tabTop))
            .cgPath
        // Each fill is a square as long as the photo's corner runs, less the corner. It reaches 1pt into the tab, so no
        // seam shows, and never as far as the tab's own corner
        let run = (NewsCardMetrics.photoRadius * NewsCardMetrics.cornerRun).rounded(.up)
        // Where the photo's leading edge meets the tab's top
        let above = CGPath(rect: CGRect(x: photoLeading, y: tabTop - run, width: run, height: run + 1), transform: nil)
            .subtracting(photoCorner(bottomLeading: CGPoint(x: photoLeading, y: tabTop)))
        // Where the photo's bottom edge meets the tab's trailing side
        let past = CGPath(
            rect: CGRect(x: tabTrailing - 1, y: photoBottom - run, width: run + 1, height: run + NewsCardMetrics.frame),
            transform: nil
        )
        .subtracting(photoCorner(bottomLeading: CGPoint(x: tabTrailing, y: photoBottom)))
        return Path(tab.union(above).union(past))
    }

    /// The photo with one rounded corner, its bottom leading one at `point`, in a square well past the corner's run
    private func photoCorner(bottomLeading point: CGPoint) -> CGPath {
        let side = 2 * NewsCardMetrics.tabReach
        return UnevenRoundedRectangle(bottomLeadingRadius: NewsCardMetrics.photoRadius, style: .continuous)
            .path(in: CGRect(x: point.x, y: point.y - side, width: side, height: side))
            .cgPath
    }
}

#Preview {
    VStack(spacing: 20) {
        NewsLinkCard(link: LoopLink(
            url: "https://example.com/lead",
            title: "Steelers hold off the Ravens behind a late defensive stand",
            source: "Yahoo Sports",
            imageURL: "https://picsum.photos/seed/harbor/1200/800",
            isLead: true
        ))
        NewsLinkCard(link: LoopLink(
            url: "https://example.com/compact",
            title: "This little camera wants to be the one you take on every trip",
            source: "The Verge",
            imageURL: "https://picsum.photos/seed/geneva/1200/800",
            isLead: false
        ))
        NewsLinkCard(link: LoopLink(
            url: "https://example.com/plain",
            title: "Five teams that should be buyers before the trade deadline",
            source: "ProFootballTalk",
            imageURL: nil,
            isLead: false
        ))
    }
    .padding(20)
}
