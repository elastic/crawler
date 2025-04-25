# Advanced Crawler Details

- [Crawl Lifecycle](#crawl-lifecycle)
  - [The Primary crawl](#the-primary-crawl)
  - [The Purge crawl](#the-purge-crawl)
- [Document Schema](#document-schema)

## Crawl Lifecycle

Crawler runs crawl jobs based on configuration files you reference when running crawler.
As Crawler runs, each URL endpoint found during the crawl will be handed to a different thread to be visited, resulting in one document per page being indexed into Elasticsearch.

Crawls are performed in two stages: a primary crawl and a purge crawl.

### The Primary crawl

Beginning with URLs included as `seed_urls`, the Crawler begins crawling web content.
While crawling, each link it encounters will be added to the crawl queue, unless the link should be ignored due to [crawl rules](./docs/features/CRAWL_RULES.md) or [crawler directives](./docs/features/CRAWLER_DIRECTIVES.md).

The crawl results from visiting these webpages are added to a pool of results.
These are indexed into Elasticsearch using the `_bulk` API once the pool reaches the configured threshold.

### The Purge crawl

After a primary crawl is completed, Crawler will then fetch every doc from the associated index that was not encountered during the primary crawl.
It does this through comparing the `last_crawled_at` date on the doc to the primary crawl's start time.
If `last_crawled_at` is earlier than the start time, that means the webpage was not updated during the primary crawl and should be added to the purge crawl.

Crawler then re-crawls all of these webpages.
If a webpage is still accessible, Crawler will update its Elasticsearch doc.
A webpage can be inaccessible due to any of the following reasons:

- Updated [crawl rules](./docs/features/CRAWL_RULES.md) in the configuration file that now exclude the URL
- Updated [crawler directives](./docs/features/CRAWLER_DIRECTIVES.md) on the server or webpage that now exclude the URL
- Non-`200` response from the webserver

At the end of the purge crawl, all docs in the index that were not updated during either the primary crawl or the purge crawl are deleted.

## Document Schema

Crawler generates Elasticsearch documents from crawl results.
These documents have a predefined list of fields that are always included.

Crawler does not impose any mappings onto indices that it ingests docs into.
This means you are free to create whatever mappings you like for an index, so long as you create the mappings _before_ indexing any documents.

If any [content extraction rules](./features/EXTRACTION_RULES.md) have been configured, you can add more fields to the Elasticsearch documents.
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
