import SwiftUI

/// The story a topic post is about. A big story is a tall photo with the headline over its darkened bottom; any
/// other is a compact card with the photo at its leading edge beside the headline. Both open the story.
struct NewsLinkCard: View {
    let link: LoopLink

    @Environment(\.openURL) private var openURL

    /// The magazine card's photo height
    private static let leadHeight: CGFloat = 280
    /// The compact card's photo width, and its least height
    private static let thumbnailSide: CGFloat = 96
    private static let cornerRadius = CardLayoutConstants.mediaCornerRadius

    private var imageURL: URL? {
        link.imageURL.flatMap { URL(string: $0) }
    }

    var body: some View {
        Button {
            if let url = URL(string: link.url) {
                openURL(url)
            }
        } label: {
            Group {
                if link.isLead, imageURL != nil {
                    leadCard
                } else {
                    compactCard
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.97))
        // A card visibly starts and ends at its own edges, not at the text inside it
        .alignmentGuide(.visibleTop) { $0[.top] }
        .alignmentGuide(.visibleBottom) { $0[.bottom] }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(link.title), \(link.source)")
        .accessibilityAddTraits(.isLink)
    }

    // MARK: - Lead

    private var leadCard: some View {
        photo(width: nil, height: Self.leadHeight)
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(link.source.uppercased())
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text(link.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
                )
            }
    }

    // MARK: - Compact

    private var compactCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(link.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            Text(link.source)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: imageURL == nil ? nil : Self.thumbnailSide, alignment: .leading)
        // The photo runs the card's full height at its leading edge, so its corners are the card's own
        .padding(.leading, imageURL == nil ? 0 : Self.thumbnailSide)
        .background(alignment: .leading) {
            if imageURL != nil {
                photo(width: Self.thumbnailSide, height: nil)
            }
        }
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Photo

    /// The story's photo filling a frame of the given size; nil takes the space the parent offers
    private func photo(width: CGFloat?, height: CGFloat?) -> some View {
        Color(.systemGray5)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, maxHeight: height == nil ? .infinity : nil)
            .overlay {
                CachedAsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.clear
                }
            }
            .clipped()
    }
}

#Preview {
    VStack(spacing: 20) {
        NewsLinkCard(link: LoopLink(
            url: "https://example.com/lead",
            title: "Steelers hold off the Ravens behind a late defensive stand",
            source: "ESPN",
            imageURL: "https://picsum.photos/seed/loop-lead/1200/800",
            isLead: true
        ))
        NewsLinkCard(link: LoopLink(
            url: "https://example.com/compact",
            title: "Senate passes the transit bill with votes from both parties",
            source: "NPR",
            imageURL: "https://picsum.photos/seed/loop-compact/600/600",
            isLead: false
        ))
    }
    .padding(20)
}
