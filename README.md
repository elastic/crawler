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
| `8.x`         | `v0.2.0` and above | Linux, OSX       |
| `9.x`         | `v0.2.1` and above | Linux, OSX       |

## Quick links

- [Hands-on quickstart](#quickstart): Run your first crawl to ingest web content into Elasticsearch.
- [Learn more](#learn-more): Learn how to configure advanced features and understand detailed options.
- [Developer guide](#for-developers): Learn how to build and run Open Crawler from source, for developers who want to modify or extend the code.

### Quickstart 

Get from zero to crawling your website into Elasticsearch in just a few steps.

#### Steps

- [Prerequisites](#prerequisites)
  - [Step 1: Test crawl](#step-1-verify-docker-setup-and-run-a-test-crawl)
  - [Step 2: Get Elasticsearch details](#step-2-get-your-elasticsearch-details)
  - [Step 3: Set environment variables](#step-3-set-environment-variables-optional)
  - [Step 4: Configure crawler](#step-4-update-crawler-configuration-for-elasticsearch)
  - [Step 5: Run crawl](#step-5-crawl-and-ingest-into-elasticsearch)
  - [Step 6: View data](#step-6-view-your-data)

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

The `-v "$(pwd)":/config` flag maps your current directory to the container's `/config` directory, making your config file available to the crawler.

✅ **Success check**: You should see HTML content from `example.com` printed to your console, ending with `[primary] Finished a crawl. Result: success;`

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

> [!NOTE]
> Connection settings differ based on where Elasticsearch is running (e.g., cloud hosted, serverless, or localhost).

- `ES_HOST`: Your Elasticsearch endpoint URL
	- **Cloud Hosted/Serverless**: Looks like `https://your-deployment.es.region.aws.elastic.cloud`
	- **Localhost**:
      - Use `http://host.docker.internal` if Elasticsearch is running locally but not in the same Docker network
      - Use `http://elasticsearch` if Elasticsearch is running in a Docker container on the same network
- `ES_PORT`: Elasticsearch port
	- **Cloud Hosted/Serverless**: `443`
	- **Localhost**: `9200`
- `ES_API_KEY`: API key from Step 2
- `TARGET_WEBSITE`: Website to crawl
  - Delete any trailing slashes (`/`) or you'll hit an error. `ArgumentError: Domain "https://www.example.com/" cannot have a path`

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

#### Step 5: Crawl and ingest into Elasticsearch

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

#### Step 6: View your data

Now that the crawl is complete, you can view the indexed data in Elasticsearch:

<details><summary><b>Use the API</b></summary>
The fastest way is to use `curl` from the command line. This reuses the environment variables you set earlier.

```bash
curl -X GET "${ES_HOST}:${ES_PORT}/web-crawl-test/_search" \
    -H "Authorization: ApiKey ${ES_API_KEY}" \
    -H "Content-Type: application/json"
```

Alternatively, run the following API call in the Dev Tools Console:

```shell
GET /web-crawl-test/_search
```

</details>

<details><summary><b>Use Kibana/Serverless UI</b></summary>

1. Go to the Kibana or Serverless UI
2. Find the **Index Management** page using the [global search bar](https://www.elastic.co/docs/explore-analyze/find-and-organize/find-apps-and-objects)
3. Select the `web-crawl-test` index

</details>

---

## 📖 Learn more

### 🚀 Essential guides and concepts

- [CLI reference](docs/CLI.md) - Commands for running crawls, validation, and management
- [Configuration](docs/CONFIG.md) - Understand how to configure crawlers with `crawler.yml` and `elasticsearch.yml` files
- [Document schema](docs/ADVANCED.md#document-schema) - Understand how crawled content is indexed into a set of predefined fields in Elasticsearch and how to add fields using extraction rules
- [Crawl rules](docs/features/CRAWL_RULES.md) - Control which URLs the crawler visits

### ⚙️ Advanced topics

- [Crawl lifecycle](docs/ADVANCED.md#crawl-lifecycle) - Understand how the crawler discovers, queues, and indexes content across two stages: the primary crawl and the purge crawl
- [Extraction rules](docs/features/EXTRACTION_RULES.md) - Define how crawler extracts content from HTML
- [Binary content extraction](docs/features/BINARY_CONTENT_EXTRACTION.md) - Extract text from PDFs, DOCX files
- [Crawler directives](docs/features/CRAWLER_DIRECTIVES.md) - Use robots.txt, meta tags, or embedded data attributes to guide discovery and content extraction
- [Scheduling](docs/features/SCHEDULING.md) - Automate crawls with cron scheduling
- [Ingest pipelines](docs/features/INGEST_PIPELINES.md) - Elasticsearch ingest pipeline integration
- [Logging](docs/features/LOGGING.md) - Monitor and troubleshoot crawler activity
- [Running on Windows](https://www.elastic.co/search-labs/blog/elastic-open-crawler-in-windows-with-docker) - Learn how to run Open Crawler in Windows with Docker

---

### ⚖️ Elastic Crawler comparison

- [Feature comparison](docs/FEATURE_COMPARISON.md) - See how Open Crawler compares to Elastic Crawler, including feature support and deployment differences

---

## 👩🏽‍💻 Developer guide

### Build from source

You can build and run the Open Crawler locally using the provided setup instructions.
Detailed setup steps, including environment requirements, are in the [Developer Guide](docs/DEVELOPER_GUIDE.md).

### Contribute
Want to contribute? We welcome bug reports, code contributions, and documentation improvements.
Read the [Contributing Guide](docs/CONTRIBUTING.md) for contribution types, PR guidelines, and coding standards.

## 💬 Support

Learn how to get help, report issues, and find community resources in the [Support Guide](docs/SUPPORT.md).
