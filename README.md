# Elastic Open Web Crawler

Elastic Open Crawler is a lightweight, open code web crawler designed for discovering, extracting, and indexing web content directly into Elasticsearch. This CLI-driven tool streamlines web content ingestion into Elasticsearch, enabling easy searchability through on-demand or scheduled crawls defined by configuration files. 

This repository contains code for the Elastic Open Web Crawler.
Docker images are available for the crawler at [the Elastic Docker registry](https://www.docker.elastic.co/r/integrations/crawler).

> [!IMPORTANT]
> _The Open Crawler is currently in **beta**_.
Beta features are subject to change and are not covered by the support SLA of generally available (GA) features.
Elastic plans to promote this feature to GA in a future release.

## Getting started

This documentation outlines the following ways to run the Elastic Open Web Crawler:
- [Simple Docker quickstart](#simple-docker-quickstart): Run a basic crawl with zero setup. No Elasticsearch instance required.
- [Ingest into Elasticsearch](docs/ELASTICSEARCH.md): Configure the crawler to connect to Elasticsearch and index crawl results.
- [Developer guide](#developer-guide): Build and run Open Crawler from source, for developers who want to modify or extend the code.

## Simple Docker quickstart

Let's scrape our first website using the Open Crawler running on Docker!

The following command will create a simple config file in your local directory, which will then be used by a Dockerized Crawler to run a crawl.
This will output the crawl results to your console, so no Elasticsearch setup is required for this step.

Run the following commands from your terminal:

``` bash
cat > crawl-config.yml << EOF
output_sink: console
domains:
  - url: https://example.com
EOF

docker run \
  -v ./crawl-config.yml:/crawl-config.yml \
  -it docker.elastic.co/integrations/crawler:latest jruby bin/crawler crawl /crawl-config.yml
```

If everything is set up correctly, you should see Crawler start up and begin crawling `example.com`.
It will print the following output to the screen and then return control to the terminal:

``` bash
[primary] Initialized an in-memory URL queue for up to 10000 URLs
[primary] Starting the primary crawl with up to 10 parallel thread(s)...
...
<HTML Content from example.com>
...
[primary] Finished a crawl. Result: success;
```

To run alternative crawls, start by changing the `- url: ...` in the `crawl-config.yml` file.
After each change just run the `docker run...` command again to see the results.

## Ingest into Elasticsearch

Once you're ready to run a more complex crawl, check out [Connecting to Elasticsearch](docs/ELASTICSEARCH.md) to ingest data into your Elasticsearch instance.

## Documentation
### Core concepts

- [Crawl lifecycle](docs/ADVANCED.md#crawl-lifecycle): Learn how the crawler discovers, queues, and indexes content across two stages: the primary crawl and the purge crawl.
- [Document schema](docs/ADVANCED.md#document-schema): Review the standard fields used in Elasticsearch documents, and how to extend them with custom extraction rules.
- [Feature comparison](docs/FEATURE_COMPARISON.md): See how Open Crawler compares to Elastic crawler, including feature support and deployment differences.

### Crawler features

- [Crawl rules](docs/features/CRAWL_RULES.md): Control which URLs the crawler is allowed to visit using.
- [Extraction rules](docs/features/EXTRACTION_RULES.md): Define how and where the crawler extracts content from HTML or URLs.
- [Binary content extraction](docs/features/BINARY_CONTENT_EXTRACTION.md): Extract text from downloadable files like PDFs and DOCX using MIME-type matching and ingest pipelines.
- [Crawler directives](docs/features/CRAWLER_DIRECTIVES.md): Use robots.txt, meta tags, or embedded data attributes to guide discovery and content extraction.
- [Ingest pipelines](docs/features/INGEST_PIPELINES.md): Learn how Open Crawler uses Elasticsearch ingest pipelines.
- [Scheduling](docs/features/SCHEDULING.md): Use cron-based scheduling to automate crawl jobs at fixed intervals.
- [Logging](docs/features/LOGGING.md): Enable system and event logging to help monitor and troubleshoot crawler activity.

### Configuration

- [Configuration files](docs/CONFIG.md): Understand the crawler and Elasticsearch YAML configuration files, how to structure them, and how they interact.

## Developer guide
### Crawler CLI
The crawler includes a CLI for running and managing crawl jobs, validating configs, and more.
See the [CLI reference](docs/CLI.md) for available commands and usage examples.

### Build from source
You can build and run the crawler locally using the provided setup instructions.
Detailed setup steps, including environment requirements, are in the [Developer Guide](docs/DEVELOPER_GUIDE.md).

### Contribute
Want to contribute? We welcome bug reports, code contributions, and documentation improvements.
Read the [Contributing Guide](docs/CONTRIBUTING.md) for contribution types, PR guidelines, and coding standards.


## Version compatibility

| Elasticsearch | Open Crawler       | Operating System |
|---------------|--------------------|------------------|
| `8.x`         | `v0.2.x`           | Linux, OSX       |
| `9.x`         | `v0.2.1` and above | Linux, OSX       |

## Contact

For support and contact options, see the [Getting Support](docs/SUPPORT.md) page.

