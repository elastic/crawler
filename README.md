# Elastic Open Web Crawler

Elastic Open Crawler is a lightweight, open code web crawler designed for discovering, extracting, and indexing web content directly into Elasticsearch.

This CLI-driven tool streamlines web content ingestion into Elasticsearch, enabling easy searchability through on-demand or scheduled crawls defined by configuration files. 

> [!NOTE] 
> This repository contains code and documentation for the Elastic Open Web Crawler.
Docker images are available for the crawler at [the Elastic Docker registry](https://www.docker.elastic.co/r/integrations/crawler).

> [!IMPORTANT]
> _The Open Crawler is currently in **beta**_.
Beta features are subject to change and are not covered by the support SLA of generally available (GA) features.
Elastic plans to promote this feature to GA in a future release.

### Version compatibility

| Elasticsearch | Open Crawler       | Operating System |
|---------------|--------------------|------------------|
| `8.x`         | `v0.2.x`           | Linux, OSX       |
| `9.x`         | `v0.2.1` and above | Linux, OSX       |

## Quick links

- [Quickstart](#quickstart): Use this hands-on guide to crawl a website's content into Elasticsearch using a simple configuration to get started.
- [Learn more](#learn-more): Learn how to configure advanced features and understand detailed options.
- [Developer guide](#for-developers): Learn how to build and run Open Crawler from source, for developers who want to modify or extend the code.

### Quickstart 

Get from zero to crawling your website into Elasticsearch in just a few steps.

#### Prerequisites

- You'll need [Docker Desktop](https://docs.docker.com/desktop/) installed and running
- You'll need a running Elasticsearch instance
    - Start a free [Elastic Cloud Hosted or Serverless trial](https://www.elastic.co/cloud/cloud-trial-overview)
    - [Get started locally](https://www.elastic.co/docs/solutions/search/run-elasticsearch-locally)

#### Step 1: Verify Docker setup and run a test crawl

First, let's test that the crawler works on your system by crawling a simple website and printing the results to your terminal. We'll create a basic config file and run the crawler against `https://example.com`.

Run the following in your terminal:

```bash
cat > crawl-config.yml << EOF
output_sink: console
domains:
  - url: https://example.com
EOF

docker run \
  -v "$(pwd)":/config \
  -it docker.elastic.co/integrations/crawler:latest jruby \
  bin/crawler crawl /config/crawl-config.yml
```

✅ **Success check**: You should see HTML content from `example.com` printed to your console, ending with `[primary] Finished a crawl. Result: success;`


> [!TIP]
> `output_sink: console` means results will be printed to your terminal instead of being indexed into Elasticsearch.
> In the next steps, we'll configure the crawler to index content into Elasticsearch instead:
> ```yaml
> output_sink: elasticsearch
> output_index: web-crawl-test
> ```

#### Step 2: Get your Elasticsearch details

> [!TIP]
> If you haven't used Elasticsearch before, check out the [Elasticsearch basics quickstart](https://www.elastic.co/docs/solutions/search/elasticsearch-basics-quickstart) for a hands-on introduction to fundamental concepts.

Before proceeding with Step 2, make sure you have a running Elasticsearch instance. See [prequisites](#prerequisites).

For this step you'll need:

- Your Elasticsearch endpoint URL
- An API key

For step-by-step guidance on finding endpoint URLs and creating API keys in the UI, see [connection details](https://www.elastic.co/docs/solutions/search/search-connection-details).

If you'd prefer to create an API key in the [Dev Tools Console](https://www.elastic.co/docs/explore-analyze/query-filter/tools/console) use the following command: 

<details> <summary>Create API key via Dev Tools Console</summary>

Run the following in Dev Tools Console:

```json
POST /_security/api_key
{
  "name": "crawler-key",
  "role_descriptors": { 
    "crawler-role": {
      "cluster": ["monitor"],
      "indices": [
        {
          "names": ["web-crawl-*"],
          "privileges": ["write", "create_index", "monitor"]
        }
      ]
    }
  }
}
```

Save the `encoded` value from the response - this is your API key.

</details>

#### Step 3: Set environment variables (optional)

> [!TIP]
> If you prefer not to use environment variables (or are on a system where they don't work as expected), you can skip this step and manually edit the configuration file in Step 4.

Set your connection details and target website as environment variables. Replace the values with your actual values.

```bash
export ES_HOST="https://your-deployment.es.region.aws.elastic.cloud"
export ES_PORT="443"
export ES_API_KEY="your_encoded_api_key_here"
export TARGET_WEBSITE="https://your-website.com"
```

- `ES_HOST`: Your Elasticsearch endpoint URL
	- Cloud Hosted/Serverless: `https://your-deployment.es.region.aws.elastic.cloud`
	- Localhost: `http://localhost`
- `ES_PORT`: Your Elasticsearch port
	- Cloud Hosted/Serverless: `443`
	- Localhost: `9200`
- `ES_API_KEY`: The encoded API key from Step 2
- `TARGET_WEBSITE`: The website you want to crawl

#### Step 4: Update crawler configuration for Elasticsearch

Create your crawler config file by running the following command. This will use the environment variables you set in Step 3 to populate the configuration file automatically.

```bash
cat > crawl-config.yml << EOF
output_sink: elasticsearch
output_index: web-crawl-test

elasticsearch:
  host: $ES_HOST
  port: $ES_PORT
  api_key: $ES_API_KEY
  pipeline_enabled: false

domains:
  - url: $TARGET_WEBSITE
EOF
```

If you skipped Step 3 or the environment variables aren't working on your computer, create the config file and replace the placeholders manually.

<details><summary>Manual configuration</summary>

```bash
cat > crawl-config.yml << 'EOF'
output_sink: elasticsearch
output_index: web-crawl-test

elasticsearch:
  host: https://your-deployment.es.region.aws.elastic.cloud  # Your ES_HOST
  port: 443                                                   # Your ES_PORT (443 for cloud, 9200 for localhost)  
  api_key: your_encoded_api_key_here                          # Your ES_API_KEY from Step 2
  pipeline_enabled: false

domains:
  - url: https://your-website.com                             # Your target website
EOF
```
</details>

> [!TIP]
> We disable the [ingest pipeline](https://www.elastic.co/docs/manage-data/ingest/transform-enrich/ingest-pipelines) option initially to avoid setup complexity. You can enable it later for advanced content processing.

#### Step 6: Crawl and ingest into Elasticsearch

Now you can ingest your target website content into Elasticsearch:

```bash
docker run \
  -v "$(pwd)":/config \
  -it docker.elastic.co/integrations/crawler:latest jruby \
  bin/crawler crawl /config/crawl-config.yml
```

✅ **Success check**: You should see messages like:

- `Connected to ES at https://your-endpoint - version: 8.x.x`
- `Index [web-crawl-test] was found!`
- `Elasticsearch sink initialized`

#### Step 7: View your data

Check that your crawled data made it into Elasticsearch:

1. Go to Kibana/Serverless UI
2. Find your `web-crawl-test` index by [searching in the global header](https://www.elastic.co/docs/explore-analyze/find-and-organize/find-apps-and-objects)

Alternatively, run the following API call in Dev Tools Console:

```shell
GET /web-crawl-test/_search
```

✅ **Success**: You should see Elasticsearch documents containing the crawled content. Documents will include fields such as `url`, `title`, `content`, per the [schema](docs/ADVANCED.md#document-schema).

---

## 📖 Learn more

### 🚀 Essential guides and concepts

- [CLI reference](docs/CLI.md) - Commands for running crawls, validation, and management
- [Configuration files](docs/CONFIG.md) - Understand how to configure crawlers with `crawler.yml` and `elasticsearch.yml` files
- [Crawl rules](docs/features/CRAWL_RULES.md) - Control which URLs the crawler visits
- [Crawl lifecycle](docs/ADVANCED.md#crawl-lifecycle) - Understand how the crawler discovers, queues, and indexes content across two stages: the primary crawl and the purge crawl
- [Document schema](docs/ADVANCED.md#document-schema) - Review the standard fields used in Elasticsearch documents, and how to extend the current schema and mappings with custom extraction rules

### ⚙️ Advanced features
- [Extraction rules](docs/features/EXTRACTION_RULES.md) - Define how crawler extracts content from HTML
- [Binary content extraction](docs/features/BINARY_CONTENT_EXTRACTION.md) - Extract text from PDFs, DOCX files
- [Crawler directives](docs/features/CRAWLER_DIRECTIVES.md) - Use robots.txt, meta tags, or embedded data attributes to guide discovery and content extraction
- [Scheduling](docs/features/SCHEDULING.md) - Automate crawls with cron scheduling
- [Ingest pipelines](docs/features/INGEST_PIPELINES.md) - Elasticsearch ingest pipeline integration
- [Logging](docs/features/LOGGING.md) - Monitor and troubleshoot crawler activity

---

### ⚖️ Elastic Crawler comparison

- [Feature comparison](docs/FEATURE_COMPARISON.md) - See how Open Crawler compares to Elastic Crawler, including feature support and deployment differences

---

### 👩‍💻 For developers
- [Build from source](docs/DEVELOPER_GUIDE.md) - Local development setup and environment requirements
- [Contributing](docs/CONTRIBUTING.md) - Bug reports, code contributions, documentation improvements, PR guidelines, and coding standards

---

### 💬 Support

- [Get support](docs/SUPPORT.md) — Learn how to get help, report issues, and find community resources