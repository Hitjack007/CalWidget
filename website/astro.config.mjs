import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';

export default defineConfig({
  site: 'https://gcalwidget.marksstuff.com',
  trailingSlash: 'never',
  build: { format: 'file' },
  integrations: [sitemap()],
});
