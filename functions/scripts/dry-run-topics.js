// Dry run of the topic job: fetches every feed, claims stories in memory and prints the posts it would make, without
// writing anything. With ANTHROPIC_API_KEY set, Claude writes the posts; without it, each post is the headline.
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
    save: async () => {},
  };
  const writer = process.env.ANTHROPIC_API_KEY
    ? internals.claudeWriter(new Anthropic())
    : async (topic, story) => ({ text: story.title, significance: 3 });
  const log = { info: console.log, warn: console.warn, error: console.error };
  const posts = await internals.runTopics({ store, writer, log, topics });
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
