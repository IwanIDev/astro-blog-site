import rss from '@astrojs/rss';
import { getCollection, render } from 'astro:content';
import sanitizeHtml from 'sanitize-html';
import { experimental_AstroContainer as AstroContainer } from 'astro/container';
import { loadRenderers } from 'astro:container';
import { getContainerRenderer as getMDXRenderer } from '@astrojs/mdx';

export async function GET(context) {
  const posts = (await getCollection('blog')).sort(
    // Sort posts by publication date, newest first
    (a, b) => new Date(b.data.publishDate) - new Date(a.data.publishDate)
  );

  const container = await AstroContainer.create({
    renderers: await loadRenderers([getMDXRenderer()]),
  });

  const rssItems = await Promise.all(
    posts.map(async (post) => {
      // Render the post content to HTML
      const { Content } = await render(post);
      const htmlContent = await container.renderToString(Content);

      // Sanitise the HTML to be safe in RSS feeds
      const sanitisedContent = sanitizeHtml(htmlContent, {
        allowedTags: sanitizeHtml.defaults.allowedTags.concat(['img']),
      });

      return {
        title: post.data.title,
        pubDate: post.data.pubDate,
        link: `${context.site}posts/${post.slug}`,
        description: post.data.description,
        customData: `<content:encoded><![CDATA[${sanitisedContent}]]></content:encoded>`,
      };
    })
  );

  return rss({
    title: 'Iwan Ingman',
    description: 'Iwan Ingman\'s personal blog',
    site: context.site,
    xmlns: {
      content: 'http://purl.org/rss/1.0/modules/content/',
    },
    customData: `<language>en-gb</language>`,
    items: rssItems,
  });
}
