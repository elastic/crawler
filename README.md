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


## Getting started

- [Quickstart](#quickstart): Use this hands-on guide to crawl a website's content into Elasticsearch using a simple configuration to get started.
- [Documentation](#documentation): Learn how to configure advanced features and understand detailed options.
- [Developer guide](#developer-guide): Learn how to build and run Open Crawler from source, for developers who want to modify or extend the code.

### Quickstart

Get from zero to crawling your website into Elasticsearch in just a few steps.

#### Prerequisites

- You'll need [Docker Desktop](https://docs.docker.com/desktop/) installed and running
- You'll need a running Elasticsearch instance
    - Start a free [Elastic Cloud Hosted or Serverless trial](https://www.elastic.co/cloud/cloud-trial-overview)
    - [Get started locally](https://www.elastic.co/docs/solutions/search/run-elasticsearch-locally)

> [!TIP]
> If you haven't used Elasticsearch before, check out the [Elasticsearch basics quickstart](https://www.elastic.co/docs/solutions/search/elasticsearch-basics-quickstart) for a hands-on introduction to fundamental concepts.

#### Step 1: Verify Docker setup

First, let's test that the crawler works on your system by crawling a simple website and printing results to your terminal.

Create a basic config file:

```bash
cat > crawl-config.yml << EOF
output_sink: console
domains:
  - url: https://example.com
EOF
```

Run the crawler:

```bash
docker run \
  -v "$(pwd)":/config \
  -it docker.elastic.co/integrations/crawler:latest jruby \
  bin/crawler crawl /config/crawl-config.yml
```

✅ **Success check**: You should see HTML content from example.com printed to your console, ending with `[primary] Finished a crawl. Result: success;`

If this fails, check that Docker is running and you have internet connectivity.

#### Step 2: Get your Elasticsearch details

Get your Elasticsearch endpoint URL and API key. For step-by-step guidance on finding endpoint URLs and creating API keys in the UI, see the [Elastic connection details guide](https://www.elastic.co/docs/solutions/search/search-connection-details).

If you'd prefer to work in the [Dev Tools Console](https://www.elastic.co/docs/explore-analyze/query-filter/tools/console) use the following command: 

<details> <summary>Create API key via Dev Tools Console</summary>

If you prefer using the console, create an API key with the correct permissions by running this in Kibana's Dev Tools console or via curl:

```bash
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

✅ **Save the `encoded` value** from the response - this is your API key.

</details>

#### Step 3: Set environment variables

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

> [!TIP]
> If you prefer not to use environment variables or are on a system where they don't work as expected, you can skip this step and manually edit the configuration file in Step 4.

#### Step 4: Update crawler configuration for Elasticsearch

Create your crawler config file with the environment variables substituted:

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

If you skipped Step 3 or the environment variables aren't working, create the config file and replace the placeholders manually.

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

#### Step 5: Validate your target website

Test that your target website is accessible and crawlable:

```bash
docker run \
  -v "$(pwd)":/config \
  -it docker.elastic.co/integrations/crawler:latest jruby \
  bin/crawler validate /config/crawl-config.yml
```

✅ **Success check**: You should see `Domain https://your-website.com is valid`

This will verify your website can be crawled and warn about any issues like redirects.

#### Step 6: Run full crawl to Elasticsearch

Now run the crawler:

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
2. Navigate to **Discover** or **Index Management**
3. Look for your `web-crawl-test` index
4. You should see documents with crawled content!

Alternatively, run the following API call in Dev Tools Console:

```shell
GET /web-crawl-test/_search
```

✅ **Success**: You should see JSON results with your crawled web pages

You can also view your data in Kibana by navigating to **Discover** and selecting the `web-crawl-test` index.

---

## 📖 Learn more

### 🚀 Essential guides
- [CLI reference](docs/CLI.md) - Commands for running crawls, validation, and management
- [Configuration files](docs/CONFIG.md) - Understand crawler and Elasticsearch configuration options
- [Crawl rules](docs/features/CRAWL_RULES.md) - Control which URLs the crawler visits

---

### ⚙️ Advanced features
- [Extraction rules](docs/features/EXTRACTION_RULES.md) - Define how crawler extracts content from HTML
- [Binary content extraction](docs/features/BINARY_CONTENT_EXTRACTION.md) - Extract text from PDFs, DOCX files
- [Crawler directives](docs/features/CRAWLER_DIRECTIVES.md) - Use robots.txt, meta tags, or embedded data attributes to guide discovery and content extraction
- [Scheduling](docs/features/SCHEDULING.md) - Automate crawls with cron scheduling
- [Ingest pipelines](docs/features/INGEST_PIPELINES.md) - Elasticsearch ingest pipeline integration
- [Logging](docs/features/LOGGING.md) - Monitor and troubleshoot crawler activity

---

### 📚 Reference
- [Crawl lifecycle](docs/ADVANCED.md#crawl-lifecycle) - How the crawler discovers, queues, and indexes content across two stages: the primary crawl and the purge crawl
- [Document schema](docs/ADVANCED.md#document-schema) - Review the standard fields used in Elasticsearch documents, and how to extend the current schema and mappings with custom extraction rules
- [Feature comparison](docs/FEATURE_COMPARISON.md) - See how Open Crawler compares to Elastic Crawler, including feature support and deployment differences

---

### 👩‍💻 For developers
- [Build from source](docs/DEVELOPER_GUIDE.md) - Local development setup and environment requirements
- [Contributing](docs/CONTRIBUTING.md) - Bug reports, code contributions, documentation improvements, PR guidelines, and coding standards

---

💬 [Get support](docs/SUPPORT.md) — 