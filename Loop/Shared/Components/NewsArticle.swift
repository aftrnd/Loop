import SwiftUI
import UIKit

/// A news topic's post as a newspaper article: the publisher's headline in serif, the post's text as the standfirst,
/// the story's photo and a credit. The header above it names the topic and the source. The whole article opens the
/// story.
struct NewsArticle: View {
    /// The post's text, written by Loop from the story
    let standfirst: String
    let link: LoopLink

    @Environment(\.openURL) private var openURL

    // The serif is set as a fixed size with `.fontDesign(.serif)`: under the app's rounded design, text styles asked
    // for the serif design render in SF, so these sizes scale with Dynamic Type themselves
    @ScaledMetric(relativeTo: .title2) private var headlineSize: CGFloat = 22
    @ScaledMetric(relativeTo: .body) private var standfirstSize: CGFloat = 17

    private static let photoHeight: CGFloat = 200

    private var imageURL: URL? {
        link.imageURL.flatMap { URL(string: $0) }
    }

    var body: some View {
        Button {
            if let url = URL(string: link.url) {
                openURL(url)
            }
        } label: {
            // The post's part spacing between every part, from where one visibly ends to where the next starts. The
            // article visibly starts at the headline's capitals and ends at the credit's baseline
            BaselineSpacedVStack(spacing: CardLayoutConstants.partSpacing) {
                Text(link.title)
                    .font(.system(size: headlineSize, weight: .bold))
                    .fontDesign(.serif)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .visibleTopAtCapHeight(of: Self.serif(size: headlineSize, weight: .bold))
                Text(standfirst)
                    .font(.system(size: standfirstSize))
                    .fontDesign(.serif)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .visibleTopAtCapHeight(of: Self.serif(size: standfirstSize, weight: .regular))
                if imageURL != nil {
                    photo
                }
                Text("Summarized by Loop")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .visibleTopAtCapHeight(of: .footnote)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.98))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(link.title). \(standfirst) Summarized by Loop")
        .accessibilityAddTraits(.isLink)
    }

    /// The story's photo, gray while it loads. Left under the photo, the gray would show through the clip's
    /// antialiased corners as a fringe
    private var photo: some View {
        Color.clear
            .frame(height: Self.photoHeight)
            .frame(maxWidth: .infinity)
            .overlay {
                CachedAsyncImage(url: imageURL, trimsEdges: true) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color(.systemGray5)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: CardLayoutConstants.mediaCornerRadius, style: .continuous))
    }

    /// New York at a size and weight, the face `.fontDesign(.serif)` sets a sized system font in, for its cap height
    private static func serif(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let font = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = font.fontDescriptor.withDesign(.serif) else { return font }
        return UIFont(descriptor: descriptor, size: size)
    }
}

#Preview {
    NewsArticle(
        standfirst: "The transit bill cleared the Senate with votes from both parties. It now goes to the House.",
        link: LoopLink(
            url: "https://example.com/story",
            title: "Senate passes the transit bill in a 68 to 31 vote",
            source: "NPR",
            imageURL: "https://picsum.photos/seed/loop-capitol/1200/800",
            isLead: false
        )
    )
    .padding(20)
}
