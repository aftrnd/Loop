import Foundation

/// A topic in the directory the topic function keeps in `topics/{id}`: its look, what it covers and where its news
/// comes from, for Discover and for opening its page without one of its posts.
struct TopicEntry: Identifiable, Hashable {
    let topic: LoopTopic
    let name: String
    /// What it covers, such as "the Pittsburgh Steelers"
    let about: String?
    /// One sentence on its latest news, written by Claude after a run that posts; nil until the first
    let brief: String?
    /// The publishers its stories come from
    let sources: [String]
    /// Its place in the directory
    let order: Int

    var id: String {
        topic.id
    }

    /// The author id its posts are written under
    var authorId: String {
        "topic_\(topic.id)"
    }
}

/// How a topic's line names the publishers its posts summarize, after the AI mark.
enum TopicSources {
    /// The sources, longest first: up to two by name and how many more, then one by name, then only how many
    static func variants(_ sources: [String]) -> [String] {
        switch sources.count {
        case 0: return ["News summaries"]
        case 1: return [sources[0]]
        case 2: return ["\(sources[0]) and \(sources[1])", "\(sources[0]) and 1 more", "2 sources"]
        default:
            return [
                "\(sources[0]), \(sources[1]) and \(sources.count - 2) more",
                "\(sources[0]) and \(sources.count - 1) more",
                "\(sources.count) sources"
            ]
        }
    }

    static func spokenText(_ sources: [String]) -> String {
        guard !sources.isEmpty else { return "News summaries written by AI" }
        return "Summaries written by AI, from " + ListFormatter.localizedString(byJoining: sources)
    }
}
