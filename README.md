# Elastic Open Web Crawler

This repository contains code for the Elastic Open Web Crawler.
This is a tool to allow users to easily ingest content into Elasticsearch from the web.

## How it works

Crawler runs crawl jobs on command based on config files in the `config` directory.
1 URL endpoint on a site will correlate with 1 result output.

The crawl results can be output in 3 different modes:

- As docs to an Elasticsearch index
- As files to a specified directory
- Directly to the terminal

### Setup

#### Running from Docker

Crawler has a Dockerfile that can be built and run locally.

1. Build the image `docker build -t crawler-image .`
2. Run the container `docker run -i -d --name crawler crawler-image`
   - `-i` allows the container to stay alive so CLI commands can be executed inside it
   - `-d` allows the container to run "detached" so you don't have to dedicate a terminal window to it
3. Confirm that Crawler commands are working `docker exec -it crawler bin/crawler version`
4. Execute other CLI commands from outside of the container by prepending `docker exec -it crawler <command>`.
   - See [Crawling content](#crawling-content) for examples.

#### Running from source

Crawler uses both JRuby and Java.
We recommend using version managers for both.
When developing Crawler we use `rbenv` and `jenv`.
There are instructions for setting up these env managers here:

- [Official documentation for installing jenv](https://www.jenv.be/)
- [Official documentation for installing rbenv](https://github.com/rbenv/rbenv?tab=readme-ov-file#installation)

Go to the root of the Crawler directory and check the expected Java and Ruby versions are being used:

```bash
# should output the same version as `.ruby-version`
$ ruby --version

# should output the same version as `.java-version`
$ java --version
```

If the versions seem correct, you can install dependencies:

```bash
$ make install
```

Crawler should now be functional.
See [Configuring Crawlers](#configuring-crawlers) to begin crawling web content.

### Configuring Crawlers

See [CONFIG.md](docs/CONFIG.md) for in-depth details on Crawler configuration files.

Once you have a Crawler configured, you can validate the domain(s) using the CLI.

```bash
$ bin/crawler validate config/my-crawler.yml
```

If you are running from docker, you will first need to copy the config file into the docker container.

```bash
# copy file (if you haven't already done so)
$ docker cp /path/to/my-crawler.yml crawler:config/my-crawler.yml

# run 
$ docker exec -it crawler bin/crawler validate config/my-crawler.yml
```

See [Crawling content](#crawling-content).

### Crawling content

Use the following command to run a crawl based on the configuration provided.

```bash
$ bin/crawler crawl config/my-crawler.yml
```

And from Docker.

```bash
$ docker exec -it crawler bin/crawler crawl config/my-crawler.yml
```

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
