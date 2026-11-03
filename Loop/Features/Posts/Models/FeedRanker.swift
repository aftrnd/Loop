import Foundation

/// Orders the Home feed's newest posts for one visit, so each open leads with what you haven't seen yet rather than
/// the same posts in time order. Pure: the same posts, seen set and seed always give the same order.
///
/// A post's score multiplies:
/// - 10 if you haven't seen it (your own posts count as seen), so new posts come first: an unseen post a day old still
///   outranks a seen one posted a minute ago, unless engagement or follows lift the seen one
/// - its recency, halving every 8 hours
/// - its engagement, 1 + 0.3 ln(1 + likes + 2 replies)
/// - 1.5 if you follow its author, and 1.5 if you follow its topic (when you follow any topics)
/// - a topic post's significance over 3, Claude's 1 to 5 rating of the story, so a routine story sits below a
///   friend's post and major news above it
/// - a jitter of up to 10% either way, fixed for the session, so posts that score alike don't always come in the
///   same order
///
/// Then posts are placed best first, each account's next post counting 0.7 times the one before, and never two from
/// the same account in a row while another is left. Seen posts sink but are never dropped.
nonisolated enum FeedRanker {
    /// A post as the ranker sees it
    nonisolated struct Candidate: Sendable {
        let id: String
        let authorId: String
        /// The topic a topic post comes from
        let topicId: String?
        let createdAt: Date
        let likeCount: Int
        let replyCount: Int
        /// Claude's 1 to 5 rating of a topic post's story
        let significance: Int?
    }

    nonisolated struct Context: Sendable {
        let now: Date
        let currentUserId: String?
        let seenIds: Set<String>
        let followedAuthorIds: Set<String>
        /// Empty when you follow no topics, which ranks every topic alike
        let followedTopicIds: Set<String>
        /// Differs every session
        let seed: UInt64
    }

    static let unseenWeight = 10.0
    static let halfLifeHours = 8.0
    static let engagementWeight = 0.3
    static let followedWeight = 1.5
    /// A significance this high counts as much as a person's post
    static let typicalSignificance = 3.0
    static let repeatDecay = 0.7
    static let jitter = 0.1

    /// The candidates' ids, best first.
    static func rank(_ candidates: [Candidate], context: Context) -> [String] {
        var remaining = candidates.map { (candidate: $0, score: score($0, context: context)) }
        var placedFromSource: [String: Int] = [:]
        var lastSource: String?
        var order: [String] = []
        order.reserveCapacity(candidates.count)

        while !remaining.isEmpty {
            var best: (index: Int, score: Double)?
            var bestRepeat: (index: Int, score: Double)?
            for (index, entry) in remaining.enumerated() {
                let source = source(of: entry.candidate)
                let score = entry.score * pow(repeatDecay, Double(placedFromSource[source, default: 0]))
                // Ties keep the input's order, newest first
                if source != lastSource {
                    if score > best?.score ?? -.infinity {
                        best = (index, score)
                    }
                } else if score > bestRepeat?.score ?? -.infinity {
                    bestRepeat = (index, score)
                }
            }
            // The same account twice in a row only when nothing else is left
            guard let pick = best ?? bestRepeat else { break }
            let placed = remaining.remove(at: pick.index).candidate
            let source = source(of: placed)
            placedFromSource[source, default: 0] += 1
            lastSource = source
            order.append(placed.id)
        }
        return order
    }

    static func score(_ candidate: Candidate, context: Context) -> Double {
        let isSeen = context.seenIds.contains(candidate.id) || candidate.authorId == context.currentUserId
        let ageHours = max(context.now.timeIntervalSince(candidate.createdAt), 0) / 3600
        let recency = pow(0.5, ageHours / halfLifeHours)
        let engagement = 1 + engagementWeight * log(1 + Double(candidate.likeCount + 2 * candidate.replyCount))

        var affinity = 1.0
        if context.followedAuthorIds.contains(candidate.authorId) {
            affinity *= followedWeight
        }
        if let topicId = candidate.topicId, context.followedTopicIds.contains(topicId) {
            affinity *= followedWeight
        }
        let significance = candidate.significance.map { Double($0) / typicalSignificance } ?? 1

        let unit = unitInterval(for: candidate.id, seed: context.seed)
        let jitterFactor = 1 + jitter * (2 * unit - 1)

        return (isSeen ? 1 : unseenWeight) * recency * engagement * affinity * significance * jitterFactor
    }

    /// The account a post comes from, for spreading them out: its topic, or its author
    private static func source(of candidate: Candidate) -> String {
        candidate.topicId.map { "topic:\($0)" } ?? candidate.authorId
    }

    /// A number in [0, 1) fixed for this post and seed: FNV-1a over the id, mixed with SplitMix64. `hashValue` would
    /// differ between launches even with the same seed.
    private static func unitInterval(for id: String, seed: UInt64) -> Double {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in id.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        var mixed = hash ^ seed
        mixed = (mixed ^ (mixed >> 30)) &* 0xbf58476d1ce4e5b9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94d049bb133111eb
        mixed ^= mixed >> 31
        return Double(mixed >> 11) / Double(UInt64(1) << 53)
    }
}
