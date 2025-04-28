# Elastic Open Web Crawler

Elastic Open Crawler is a lightweight, open code web crawler designed for discovering, extracting, and indexing web content directly into Elasticsearch. This CLI-driven tool streamlines web content ingestion into Elasticsearch, enabling easy searchability through on-demand or scheduled crawls defined by configuration files. 

This repository contains code for the Elastic Open Web Crawler.
Docker images are available for the crawler at [the Elastic Docker registry](https://www.docker.elastic.co/r/integrations/crawler).

> [!IMPORTANT]
> _The Open Crawler is currently in **beta**_.
Beta features are subject to change and are not covered by the support SLA of generally available (GA) features.
Elastic plans to promote this feature to GA in a future release.

### Compatibility Matrix

| Elasticsearch | Open Crawler       | Operating System |
|---------------|--------------------|------------------|
| `8.x`         | `v0.2.x`           | Linux, OSX       |
| `9.x`         | `v0.2.1` and above | Linux, OSX       |

## Simple Docker Quickstart

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

Once you're ready to run a more complex crawl, check out the sections below to send data to Elasticsearch, schedule crawls, and more.

## Further Resources

- [Connecting to Elasticsearch](docs/ELASTICSEARCH.md)
- [CLI command list](docs/CLI.md)
- [Logging](docs/features/LOGGING.md)
- [Crawl lifecycle](docs/ADVANCED.md#crawl-lifecycle)
- [Document Schema](docs/ADVANCED.md#document-schema)
- [Developer guide](docs/DEVELOPER_GUIDE)
