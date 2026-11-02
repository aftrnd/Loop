import SwiftUI

/// The story a topic post links to, set in ink: the story's photo inside an ink frame, with the headline and the
/// story's domain in a tab of the frame cut from the photo's bottom leading corner. A big story's photo is 4:3 and any
/// other's 5:2; a story without a photo is all ink. The ink is black in both appearances, so in dark mode, on a black
/// page, the card keeps its edge with a hairline. The whole card opens the story.
struct NewsLinkCard: View {
    let link: LoopLink

    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale

    /// The card and the tab, with the text reversed out of them
    private static let ink = Color.black
    private static let paper = Color.white

    private var imageURL: URL? {
        link.imageURL.flatMap { URL(string: $0) }
    }

    /// The story's site, as the line under the headline shows it: the link's host without a leading "www."
    private var domain: String? {
        guard let host = URL(string: link.url)?.host(), !host.isEmpty else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    /// A big story without a photo is set like any other story without one
    private var style: NewsCardLayout.Style {
        guard imageURL != nil else { return .plain }
        return link.isLead ? .lead : .compact
    }

    var body: some View {
        let card = RoundedRectangle(cornerRadius: NewsCardMetrics.cornerRadius, style: .continuous)
        Button {
            if let url = URL(string: link.url) {
                openURL(url)
            }
        } label: {
            NewsCardLayout(style: style) {
                if let imageURL {
                    photo(imageURL)
                    CutoutTab()
                        .fill(Self.ink)
                }
                headline
                if let domain {
                    domainLine(domain)
                }
            }
            .background(Self.ink)
            .clipShape(card)
            .overlay {
                // The system's color for thin borders, the feed's divider color, a pixel wide inside the card's edge
                if colorScheme == .dark {
                    card.strokeBorder(Color(.separator), lineWidth: 1 / displayScale)
                }
            }
            .contentShape(card)
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.98))
        // A card visibly starts and ends at its own edges, not at the text inside it
        .alignmentGuide(.visibleTop) { $0[.top] }
        .alignmentGuide(.visibleBottom) { $0[.bottom] }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(link.title), \(domain ?? link.source)")
        .accessibilityAddTraits(.isLink)
    }

    // MARK: - Parts

    /// The publisher's headline, reversed out of the ink
    private var headline: some View {
        let isLead = style == .lead
        return Text(link.title)
            .font(isLead ? .title3.weight(.bold) : .headline)
            .foregroundStyle(Self.paper)
            .multilineTextAlignment(.leading)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
            .visibleTopAtCapHeight(of: isLead ? .title3 : .headline)
    }

    /// The story's site under the headline, quieter than it, with an arrow for a link that leaves the app. A long domain
    /// gives up its middle, so the site's name and the arrow stay
    private func domainLine(_ domain: String) -> some View {
        Text("\(domain)  \(Image(systemName: "arrow.up.right"))")
            .font(.footnote.weight(.medium))
            .foregroundStyle(Self.paper.opacity(0.6))
            .lineLimit(1)
            .truncationMode(.middle)
            .visibleTopAtCapHeight(of: .footnote)
    }

    /// The story's photo filling its place in the frame, its corners concentric with the card's, gray while it loads.
    /// Left under the photo, the gray would show through the clip's antialiased corners as a light or dark fringe
    private func photo(_ url: URL) -> some View {
        Color.clear
            .overlay {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color(.systemGray5)
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
    /// The tab's room around its text on every side: from the photo's leading and bottom edges, above the headline's
    /// capitals and past the longest line. It is also the tab's corner, so the corner's arc is centered on the corner of
    /// the text's block
    static let tabPadding: CGFloat = photoRadius
    /// In both cards the text's leading edge and its last baseline sit this far in from the card's leading and bottom
    /// edges: the frame plus the tab's padding, the card's corner, so the text's block has its corners on the centers of
    /// the card's. A card without a photo pads the headline's capitals and its trailing side by the same
    static let textInset: CGFloat = frame + tabPadding
    /// The domain's capitals sit the frame's width under the headline's last baseline
    static let domainGap: CGFloat = frame
    /// How far a continuous corner runs along each edge, in radii (measured on the simulator: 30.33pt for 20)
    static let cornerRun: CGFloat = 1.52
    /// The tab is never shorter than the two corners on its trailing side, its own and the photo's past it: 37pt
    static let minTabHeight: CGFloat = (cornerRun * (tabPadding + photoRadius)).rounded(.up)
    /// The photo's bottom edge past the tab is never shorter than its two corners, the one where it meets the tab and its
    /// own: 37pt. It sets how far the text can run
    static let minPhotoEdge: CGFloat = (cornerRun * 2 * photoRadius).rounded(.up)
    /// How far the tab's ink runs past its top and trailing edges, room for the photo's corners where it meets them
    static let tabReach: CGFloat = 2 * photoRadius
}

// MARK: - Layout

/// Places a news card's parts in one pass, so the tab is drawn where the text lands. The text is the headline and, when
/// the story has one, the domain under it. With a photo the subviews are [photo, tab, headline, domain]: the photo sits
/// in the frame at its style's shape, the text's leading edge and last baseline sit the tab's padding inside the photo's
/// leading and bottom edges, and the tab runs from the card's leading and bottom edges to its padding above the
/// headline's capitals and past the longest line. Without a photo the subviews are [headline, domain], padded from
/// every edge.
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

    /// The text's lines stacked from the headline's capitals at 0: each one's top, the last baseline and the longest
    /// line's width
    private struct TextStack {
        var tops: [CGFloat] = []
        var lastBaseline: CGFloat = 0
        var width: CGFloat = 0
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
        guard subviews.count > 2 else { return Placement(height: 0, subviews: []) }

        let frame = NewsCardMetrics.frame
        let padding = NewsCardMetrics.tabPadding
        let photoWidth = max(0, width - 2 * frame)
        // Whole points, so the card ends on a pixel
        let photo = CGRect(x: frame, y: frame, width: photoWidth, height: (photoWidth * photoHeightRatio).rounded())
        let textLeading = NewsCardMetrics.textInset
        // The text runs as far as the tab can reach and still leave the photo's bottom edge its two corners
        let measure = ProposedViewSize(
            width: max(0, photo.maxX - NewsCardMetrics.minPhotoEdge - padding - textLeading),
            height: nil
        )
        // Copied out, as slicing the subviews by a range traps in SwiftUI (iOS 27.2 simulator)
        let text = stack(Array(subviews).dropFirst(2), measure: measure)
        let capTop = photo.maxY - padding - text.lastBaseline
        let tabTop = min(capTop - padding, photo.maxY - NewsCardMetrics.minTabHeight)
        let tabTrailing = textLeading + text.width + padding
        let height = photo.height + 2 * frame
        let reach = NewsCardMetrics.tabReach
        return Placement(
            height: height,
            subviews: [
                (photo.origin, ProposedViewSize(photo.size)),
                (CGPoint(x: 0, y: tabTop - reach), ProposedViewSize(width: tabTrailing + reach, height: height - tabTop + reach))
            ] + text.tops.map { (CGPoint(x: textLeading, y: capTop + $0), measure) }
        )
    }

    private func plainPlacement(width: CGFloat, subviews: Subviews) -> Placement {
        guard !subviews.isEmpty else { return Placement(height: 0, subviews: []) }
        let inset = NewsCardMetrics.textInset
        let measure = ProposedViewSize(width: max(0, width - 2 * inset), height: nil)
        let text = stack(subviews, measure: measure)
        // Whole points, so the card ends on a pixel and its last baseline lands where a photo card's does. The
        // rounding goes above the capitals
        let block = text.lastBaseline.rounded(.up)
        return Placement(
            height: inset + block + inset,
            subviews: text.tops.map { (CGPoint(x: inset, y: inset + block - text.lastBaseline + $0), measure) }
        )
    }

    /// Stacks the text from where each line visibly starts and ends: the domain's capitals `domainGap` under the
    /// headline's last baseline
    private func stack(_ text: some Sequence<LayoutSubview>, measure: ProposedViewSize) -> TextStack {
        var stack = TextStack()
        for (index, subview) in text.enumerated() {
            let dimensions = subview.dimensions(in: measure)
            let capTop = index == 0 ? 0 : stack.lastBaseline + NewsCardMetrics.domainGap
            let top = capTop - dimensions[.visibleTop]
            stack.tops.append(top)
            stack.lastBaseline = top + dimensions[.lastTextBaseline]
            stack.width = max(stack.width, dimensions.width)
        }
        return stack
    }
}

// MARK: - Tab

/// The ink the text sits on, drawn over the photo in a rect from the card's leading and bottom edges to
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
            url: "https://sports.yahoo.com/nfl/article/steelers-ravens",
            title: "Steelers hold off the Ravens behind a late defensive stand",
            source: "Yahoo Sports",
            imageURL: "https://picsum.photos/seed/harbor/1200/800",
            isLead: true
        ))
        NewsLinkCard(link: LoopLink(
            url: "https://www.theverge.com/cameras/pocket-camera",
            title: "This little camera wants to be the one you take on every trip",
            source: "The Verge",
            imageURL: "https://picsum.photos/seed/geneva/1200/800",
            isLead: false
        ))
        NewsLinkCard(link: LoopLink(
            url: "https://profootballtalk.nbcsports.com/trade-deadline",
            title: "Five teams that should be buyers before the trade deadline",
            source: "ProFootballTalk",
            imageURL: nil,
            isLead: false
        ))
    }
    .padding(20)
}
