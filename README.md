# Elastic Open Web Crawler

This repository contains code for the Elastic Open Web Crawler.
Open Crawler enables users to easily ingest web content into Elasticsearch.

> [!IMPORTANT]
> _The Open Crawler is currently in **beta**_.
Beta features are subject to change and are not covered by the support SLA of generally available (GA) features.
Elastic plans to promote this feature to GA in a future release.

_Open Crawler `v0.2` is confirmed to be compatible with Elasticsearch `v8.13.0` and above._

### User workflow

Indexing web content with the Open Crawler requires:

1. Running an instance of Elasticsearch (on-prem, cloud, or serverless)
2. Cloning of the Open Crawler repository (see [Setup](#setup))
3. Configuring a crawler config file (see [Configuring crawlers](#configuring-crawlers))
4. Using the CLI to begin a crawl job (see [CLI commands](#cli-commands))

### Execution logic

Open Crawler runs crawl jobs on command based on config files in the `config` directory.
Each URL endpoint found during the crawl will result in one document to be indexed into Elasticsearch.

Open Crawler performs crawl jobs in a multithreaded environment, where one thread will be used to visit one URL endpoint.
The crawl results from these are added to a pool of results.
These are indexed into Elasticsearch using the `_bulk` API once the pool reaches a configurable threshold.

### Setup

#### Prerequisites

A running instance of Elasticsearch is required to index documents into.
If you don't have this set up yet, you can sign up for an [Elastic Cloud free trial](https://www.elastic.co/cloud/cloud-trial-overview) or check out the [quickstart guide for Elasticsearch](https://www.elastic.co/guide/en/elasticsearch/reference/master/quickstart.html).

#### Connecting to Elasticsearch

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
            "privileges": ["all"]
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

#### Running Open Crawler from Docker

> [!IMPORTANT]
> **Do not trigger multiple crawl jobs that reference the same index simultaneously.**
A single crawl execution can be thought of as a single crawler.
Even if two crawl executions share a configuration file, the two crawl processes will not communicate with each other.
Two crawlers simultaneously interacting with a single index can lead to data loss.

Open Crawler has a Dockerfile that can be built and run locally.

1. Clone the repository: `git clone https://github.com/elastic/crawler.git`
2. Create a docker network `docker network create elastic`
3. Build the image `docker build -t crawler-image .`
4. Run the container
    ```bash
    docker run \
    -i -d \
    --network elastic \
    --name crawler \
    crawler-image
    ```
   - `-i` allows the container to stay alive so CLI commands can be executed inside it
   - `-d` allows the container to run "detached" so you don't have to dedicate a terminal window to it
   - `--network` if you're running Elasticsearch in another docker container on the same machine, they will both need to run on the same network
5. Confirm that CLI commands are working `docker exec -it crawler bin/crawler version`
   - Execute other CLI commands from outside of the container by prepending `docker exec -it crawler <command>`
6. Create a config file for your crawler. See [Configuring crawlers](#configuring-crawlers) for next steps.

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
      $ java --version
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

### Configuring Crawlers

Crawler has template configuration files that contain every configuration available.

- [config/crawler.yml.example](config/crawler.yml.example)
- [config/elasticsearch.yml.example](config/elasticsearch.yml.example)

To use these files, make a copy in the same directory without the `.example` suffix:

```bash
$ cp config/crawler.yml.example config/crawler.yml
```

Then remove the `#` comment-out characters from the configurations that you need.

Crawler can be configured using two config files, a Crawler configuration and an Elasticsearch configuration.
The Elasticsearch configuration file is optional.
It exists to allow users with multiple crawlers to only need a single Elasticsearch configuration.
See [CONFIG.md](docs/CONFIG.md) for more details on these files.

### Scheduling Recurring Crawl Jobs

Crawl jobs can also be scheduled to recur.
Scheduled crawl jobs run until terminated by the user.

These schedules are defined through a cron expression.
This expression needs to be included in the Crawler config file.
You can use the tool https://crontab.guru to test different cron expressions.
Crawler supports all standard cron expressions.

See an example below for a crawl schedule that will execute once every 30 minutes.

```yaml
domains:
  - url: "https://elastic.co"
schedule:
  - pattern: "*/30 * * * *" # run every 30th minute
```

Then, use the CLI to then begin the crawl job schedule:

```bash
docker exec -it crawler bin/crawler schedule path/to/my-crawler.yml
```

**Scheduled crawl jobs from a single execution will not overlap.**
Scheduled jobs will also not wait for existing jobs to complete.
If a crawl job is already in progress when another schedule is triggered, the job will be dropped.
For example, if you have a schedule that triggers at every hour, but your crawl job takes 1.5 hours to complete, the crawl schedule will effectively trigger on every 2nd hour.

**Executing multiple crawl schedules _can_ cause overlap**.
Be wary of executing multiple schedules against the same index.
As with ad-hoc triggered crawl jobs, two crawlers simultaneously interacting with a single index can lead to data loss.

### Crawler Document Schema and Mappings

See [DOCUMENT_SCHEMA.md](docs/DOCUMENT_SCHEMA.md) for information regarding the Elasticsearch document schema and mappings.

### CLI Commands

Open Crawler does not have a graphical user interface.
All interactions with Open Crawler take place through the CLI.
When given a command, Open Crawler will run until the process is finished.
OpenCrawler is not kept alive in any way between commands.

See [CLI.md](docs/CLI.md) for a full list of CLI commands available for Crawler.
