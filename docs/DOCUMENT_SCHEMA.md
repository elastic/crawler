# Document Schema

Crawler generates Elasticsearch documents from crawl results.
These documents have a predefined list of fields that are always included.

Crawler does not impose any mappings onto indices that it ingests docs into.
This means you are free to create whatever mappings you like for an index, so long as you create the mappings _before_ indexing any documents.

If any [content extraction rules](./features/EXTRACTION_RULES) have been configured, you can add more fields to the Elasticsearch documents.
However, the predefined fields can never be changed or overwritten by content extraction rules.
If you are ingesting onto an index that has custom mappings, be sure that the mappings don't conflict with these predefined fields.

| Field              | Type     |
|--------------------|----------|
| `id`               | text     |
| `body`             | text     |
| `domains`          | text     |
| `headings`         | text     |
| `last_crawled_at`  | datetime |
| `links`            | test     |
| `meta_description` | text     |
| `title`            | text     |
| `url`              | text     |
| `url_host`         | text     |
| `url_path`         | text     |
| `url_path_dir1`    | text     |
| `url_path_dir2`    | text     |
| `url_path_dir3`    | text     |
| `url_port`         | long     |
| `url_scheme`       | text     |
