import rss from '@astrojs/rss';
import { getCollection, render } from 'astro:content';
import sanitizeHtml from 'sanitize-html';

export async function GET(context) {
  const posts = await getCollection('blog');
  return rss({
    title: 'Iwan Ingman',
    description: 'Iwan Ingman\'s personal blog',
    site: context.site,
    xmlns: {
      content: 'http://purl.org/rss/1.0/modules/content/',
    },
    customData: `<language>en-gb</language>`,
    items: await Promise.all(posts.map(async (post) => {
      // Render post content to HTML
      const { html } = await render(post);

      // Sanitise the content for RSS
      const sanitisedContent = sanitizeHtml(html, {
        allowedTags: sanitizeHtml.defaults.allowedTags.concat(['img'])
      })

      return {
        title: post.data.title,
        pubDate: post.data.pubDate,
        link: `${context.site}posts/${post.slug}`,
        description: post.data.description,
        content: html,
      };
    })),
  });
}
