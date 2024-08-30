# Open Crawler Changelog

## Legend

- 🚀 Feature
- 🐛 Bugfix
- 🔨 Refactor

## `v0.2.0`

- 🚀 Crawl jobs can now be scheduled using the CLI command `bin/crawler schedule`. See [CLI.md](./CLI.md#crawler-schedule).
- 🚀 Crawler can now extract binary content from files. See [BINARY_CONTENT_EXTRACTION.md](./features/BINARY_CONTENT_EXTRACTION.md).
- 🚀 Crawler will now purge outdated documents from the index at the end of the crawl. This is enabled by default. You can disable this by adding `purge_docs_enabled: false` to the crawler's yaml config file.
- 🚀 Crawl rules can now be configured, allowing specified URLs to be allowed/denied. See [CRAWL_RULES.md](./features/CRAWL_RULES.md).
- 🚀 Extraction rules using CSS, XPath, and URL selectors can now be applied to crawls. See [EXTRACTION_RULES.md](./features/EXTRACTION_RULES.md).
- 🔨 The configuration field `content_extraction_enabled` is now `binary_content_extraction_enabled`.
- 🔨 The configuration field `content_extraction_mime_types` is now `binary_content_extraction_mime_types`.
- 🔨 The Elasticsearch document field `body_content` is now `body`.
- 🔨 The format for config files has changed, so existing crawler configurations will not work. The new format can be referenced in the [crawler.yml.example](../config/crawler.yml.example) file.
