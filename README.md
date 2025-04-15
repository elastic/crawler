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
Just paste the following commands into your terminal:
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

## Understanding Elastic Open Crawler

Indexing web content with the Open Crawler requires:

1. An instance of Elasticsearch (on-prem, cloud, or serverless)
2. A valid Crawler configuration file (see [Configuring crawlers](#configuring-crawlers))

Crawler runs crawl jobs on-demand or on a schedule, based on configuration files you reference when running crawler.
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

## Setup Elastic Open Crawler

A running instance of Elasticsearch is required to index documents into.
If you don't have this set up yet, you can sign up for an [Elastic Cloud free trial](https://www.elastic.co/cloud/cloud-trial-overview) or check out the [quickstart guide for Elasticsearch](https://www.elastic.co/guide/en/elasticsearch/reference/master/quickstart.html).

### Connecting to Elasticsearch

Open Crawler will attempt to use the `_bulk` API to index crawl results into Elasticsearch.
To facilitate this connection, Open Crawler needs to have either an API key or a username/password configured to access the Elasticsearch instance.
If using an API key, ensure that the API key has read and write permissions to access the index configured in `output_index`.

- [Elasticsearch documentation](https://www.elastic.co/guide/en/elasticsearch/reference/current/security-api-create-api-key.html) for managing API keys for more details
- [elasticsearch.yml.example](config/elasticsearch.yml.example) file for all of the available Elasticsearch configurations for Crawler

<details>
  <summary>Creating an API key</summary>
  Here is an example of creating an API key with minimal permissions for Open Crawler.
  This will return a JSON with an `encoded` key.
  The value of `encoded` is what Open Crawler can use in its configuration.

  ```bash
  POST /_security/api_key
  {
    "name": "my-api-key",
    "role_descriptors": { 
      "my-crawler-role": {
        "cluster": ["all"],
        "indices": [
          {
            "names": ["my-crawler-index-name"],
            "privileges": ["monitor"]
          }
        ]
      }
    },
    "metadata": {
      "application": "my-crawler"
    }
  }
  ```
</details>

### Configuring Crawlers

Crawler has template configuration files that contain every configuration available.

- [config/crawler.yml.example](config/crawler.yml.example)
- [config/elasticsearch.yml.example](config/elasticsearch.yml.example)

Crawler can be configured using two config files, a Crawler configuration and an optional Elasticsearch configuration.
The Elasticsearch configuration exists to allow users with multiple crawlers to share a common Elasticsearch configuration.

See [CONFIG.md](docs/CONFIG.md) for more details on these files.

### Logging
You can learn more about setting up Crawler's logging [here](docs/features/LOGGING.md).

### Running a Crawl Job

As covered in the quickstart, running a crawl job is simple.
Just navigate to the directory with your Crawler configuration and run:

```bash
docker run \
  -v ./<your crawler configuration>.yml:/crawl-config.yml \
  -it docker.elastic.co/integrations/crawler:latest jruby bin/crawler crawl /crawl-config.yml
```

### Scheduling Recurring Crawl Jobs

Crawl jobs can also be scheduled to recur. Scheduled crawl jobs run until terminated by the user.

These schedules are defined through standard cron expressions. You can use the tool https://crontab.guru to test different cron expressions.

For example, to schedule a crawl job that will execute once every 30 minutes, create a configuration file called `scheduled-crawl.yml` with the following contents:

```yaml
domains:
  - url: "https://example.com"
schedule:
  pattern: "*/30 * * * *" # run every 30th minute
```

Then, use the CLI to then begin the crawl job schedule:

```bash
docker run \
  -v ./scheduled-crawl.yml:/scheduled-crawl.yml \
  -it docker.elastic.co/integrations/crawler:latest jruby bin/crawler schedule /scheduled-crawl.yml
```

**Scheduled crawl jobs from a single execution will not overlap.**

Scheduled jobs will also not wait for existing jobs to complete. That means if a crawl job is already in progress when another schedule is triggered, the new job will be dropped. For example, if you have a schedule that triggers at every hour, but your crawl job takes 1.5 hours to complete, the crawl schedule will effectively trigger on every 2nd hour.

**Executing multiple crawl schedules _can_ cause overlap.**
Be wary of executing multiple schedules against the same index. As with ad-hoc triggered crawl jobs, two crawlers simultaneously interacting with a single index can lead to data loss.

## Other Resources

### Crawler Document Schema and Mappings

See [DOCUMENT_SCHEMA.md](docs/DOCUMENT_SCHEMA.md) for information regarding the Elasticsearch document schema and mappings.

### CLI Commands

Open Crawler does not have a graphical user interface.
All interactions with Open Crawler take place through the CLI.
When given a command, Open Crawler will run until the process is finished.
OpenCrawler is not kept alive in any way between commands.

See [CLI.md](docs/CLI.md) for a full list of CLI commands available for Crawler.

#### Running Open Crawler from source

> [!TIP]
> We recommend running from source only if you are actively developing Open Crawler.

<details>
  <summary>Instructions for running from source</summary>
  ℹ️ Open Crawler uses both JRuby and Java.
  We recommend using version managers for both.
  When developing Open Crawler we use <b>rbenv</b> and <b>jenv</b>.
  There are instructions for setting up these env managers here:

  - [Official documentation for installing jenv](https://www.jenv.be/)
  - [Official documentation for installing rbenv](https://github.com/rbenv/rbenv?tab=readme-ov-file#installation)

  1. Clone the repository: `git clone https://github.com/elastic/crawler.git`
  2. Go to the root of the Open Crawler directory and check the expected Java and Ruby versions are being used:
      ```bash
      # should output the same version as `.ruby-version`
      $ ruby --version

      # should output the same version as `.java-version`
      $ java -version
      ```

  3. If the versions seem correct, you can install dependencies:
      ```bash
      $ make install
      ```

     You can also use the env variable `CRAWLER_MANAGE_ENV` to have the install script automatically check whether `rbenv` and `jenv` are installed, and that the correct versions are running on both:
     Doing this requires that you use both `rbenv` and `jenv` in your local setup.

      ```bash
      $ CRAWLER_MANAGE_ENV=true make install
      ```
</details>
