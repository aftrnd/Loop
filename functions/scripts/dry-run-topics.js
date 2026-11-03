// Dry run of the topic job: fetches every feed, claims stories in memory and prints the posts and directory entries it
// would make, without writing anything. With ANTHROPIC_API_KEY set, Claude writes the posts and briefs; without it,
// each post and brief is a headline.
// usage: npm run dry-run-topics [-- <topicId>]
const Anthropic = require('@anthropic-ai/sdk');
const { internals } = require('../topics');

async function main() {
  const only = process.argv[2];
  const topics = internals.TOPICS.filter((topic) => !only || topic.id === only);
  const claimed = new Set();
  const store = {
    claim: async (storyId) => {
      if (claimed.has(storyId)) return false;
      claimed.add(storyId);
      return true;
    },
    skip: async (storyId, reason) => console.log(`skipped ${storyId}: ${reason}`),
    release: async (storyId) => {
      claimed.delete(storyId);
    },
    save: async () => {},
    describe: async (topicId, fields) => console.log(`topics/${topicId}: ${JSON.stringify(fields)}`),
  };
  const client = process.env.ANTHROPIC_API_KEY ? new Anthropic() : null;
  const writer = client
    ? internals.claudeWriter(client)
    : async (topic, story) => ({ text: story.title, significance: 3 });
  const briefer = client ? internals.claudeBriefer(client) : async (topic, stories) => stories[0].title;
  const log = { info: console.log, warn: console.warn, error: console.error };
  const posts = await internals.runTopics({ store, writer, briefer, log, topics });
  for (const loop of posts) {
    console.log(`\n@${loop.authorUsername}${loop.topic.layout ? ` (${loop.topic.layout})` : ''}: ${loop.content}`);
    console.log(`  ${loop.link.source}: ${loop.link.title}`);
    console.log(`  ${loop.link.url}`);
    console.log(`  image: ${loop.link.imageURL ?? 'none'}  lead: ${loop.link.isLead}  significance: ${loop.significance}`);
  }
  console.log(`\n${posts.length} posts${process.env.ANTHROPIC_API_KEY ? '' : ' (headlines stand in for Claude: no ANTHROPIC_API_KEY)'}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
