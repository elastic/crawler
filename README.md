# Elastic Open Web Crawler

This repository contains code for the Elastic Open Web Crawler.
The crawler enables users to easily ingest web content into Elasticsearch.

⚠️ _The Open Crawler is currently in **tech-preview**_.
Tech-preview features are subject to change and are not covered by the support SLA of generally available (GA) features.
Elastic plans to promote this feature to GA in a future release.

### How it works

Crawler runs crawl jobs on command based on config files in the `config` directory.
1 URL endpoint on a site will correlate with 1 result output.

The crawl results can be output in 3 different modes:

- As docs to an Elasticsearch index
- As files to a specified directory
- Directly to the terminal

### Setup

#### Prerequisites

If you are using the Crawler to index documents into Elasticsearch, you will require a running instance of Elasticsearch to index documents into.
If you don't have this set up yet, you can sign up for an [Elastic Cloud free trial](https://www.elastic.co/cloud/cloud-trial-overview) or check out the [quickstart guide for Elasticsearch](https://www.elastic.co/guide/en/elasticsearch/reference/master/quickstart.html).

_Open Crawler `v0.1` is confirmed to be compatible with Elasticsearch `v8.13.0` and above._

#### Running from Docker

Crawler has a Dockerfile that can be built and run locally.

1. Clone the repository
2. Build the image `docker build -t crawler-image .`
3. Run the container `docker run -i -d --name crawler crawler-image`
   - `-i` allows the container to stay alive so CLI commands can be executed inside it
   - `-d` allows the container to run "detached" so you don't have to dedicate a terminal window to it
4. Confirm that Crawler commands are working `docker exec -it crawler bin/crawler version`
5. Execute other CLI commands from outside of the container by prepending `docker exec -it crawler <command>`.
6. See [Configuring crawlers](#configuring-crawlers) for next steps.

#### Running from source

To avoid complications caused by different operating systems and managing ruby and java versions, we recommend running from source only if you are actively developing Open Crawler.

<details>
  <summary>Instructions for running from source</summary>
  ℹ️ Crawler uses both JRuby and Java.
  We recommend using version managers for both.
  When developing Crawler we use <b>rbenv</b> and <b>jenv</b>.
  There are instructions for setting up these env managers here:

  - [Official documentation for installing jenv](https://www.jenv.be/)
  - [Official documentation for installing rbenv](https://github.com/rbenv/rbenv?tab=readme-ov-file#installation)

  1. Clone the repository
  2. Go to the root of the Crawler directory and check the expected Java and Ruby versions are being used:
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

See [CONFIG.md](docs/CONFIG.md) for in-depth details on Crawler configuration files.

### CLI Commands

Open Crawler has no UI.
All interactions with Crawler take place through the CLI.
When given a command, Crawler will run until the process is finished.
Crawler is not kept alive in any way between commands.

See [CLI.md](docs/CLI.md) for a full list of CLI commands available for Crawler.

### Connecting to Elasticsearch

If you set the `output_sink` value to `elasticsearch`, Crawler will attempt to bulk index crawl results into Elasticsearch.
To facilitate this connection, Crawler needs to have either an API key or a username/password configured to access the Elasticsearch instance.
If using an API key, ensure that the API key has read and write permissions to access the index configured in `output_index`.

- [Elasticsearch documentation](https://www.elastic.co/guide/en/elasticsearch/reference/current/security-api-create-api-key.html) for managing API keys for more details
- [elasticsearch.yml.example](config/elasticsearch.yml.example) file for all of the available Elasticsearch configurations for Crawler

Here is an example of creating an API key with minimal permissions for Crawler.
This will return a JSON with an `encoded` key.
The value of `encoded` is what Crawler can use in its configuration. 

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
