import SwiftUI

/// A news topic's post as a newspaper article: a rule, the topic and source as a kicker, the publisher's headline in
/// serif, the post's text as the standfirst, the story's photo and a credit. The whole article opens the story.
struct NewsArticle: View {
    let topicName: String
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
            VStack(alignment: .leading, spacing: 10) {
                Rectangle()
                    .fill(Color.primary)
                    .frame(height: 1)
                Text("\(topicName.uppercased())  ·  \(link.source.uppercased())")
                    .font(.caption.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(link.title)
                    .font(.system(size: headlineSize, weight: .bold))
                    .fontDesign(.serif)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(standfirst)
                    .font(.system(size: standfirstSize))
                    .fontDesign(.serif)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if imageURL != nil {
                    photo
                        .padding(.top, 4)
                }
                Text("Summarized by Loop from \(link.source) reporting")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.98))
        // The article visibly starts at its rule and ends with its credit's line
        .alignmentGuide(.visibleTop) { $0[.top] }
        .alignmentGuide(.visibleBottom) { $0[.bottom] }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(link.title). \(standfirst) Summarized by Loop from \(link.source) reporting")
        .accessibilityAddTraits(.isLink)
    }

    private var photo: some View {
        Color(.systemGray5)
            .frame(height: Self.photoHeight)
            .frame(maxWidth: .infinity)
            .overlay {
                CachedAsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.clear
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: CardLayoutConstants.mediaCornerRadius, style: .continuous))
    }
}

#Preview {
    NewsArticle(
        topicName: "Politics",
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
