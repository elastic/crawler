# CLI

Crawler CLI is a command-line interface for use in the terminal or scripts.
This is the only user interface for interacting with Crawler.

## Installation and Configuration

Ensure you are able to run Crawler in docker or have completed the steps to run Crawler [from source](../README.md#running-open-crawler-from-source) before using the CLI.

For instructions on configuring a Crawler, see [CONFIG.md](./CONFIG.md).

### CLI in Docker

To run individual CLI commands in Docker, you can use the following format

```bash
docker run -it docker.elastic.co/integrations/crawler:latest jruby \
    bin/crawler <command> <args>
```

For an interactive shell with Crawler, simply change the entrypoint to `/bin/bash`:

```bash
docker run -it --entrypoint /bin/bash docker.elastic.co/integrations/crawler:latest
```

If you need to mount a file into the container, for example `crawl-config.yml`, you can use the `-v` option to mount it into the container:

```bash
docker run -it -v ./crawl-config.yml:/crawl-config.yml docker.elastic.co/integrations/crawler:latest jruby \
    bin/crawler crawl /crawl-config.yml

## Available commands
### Getting help
Use the `--help or -h` option with any command to get more information.

For example:
```bash
$ bin/crawler --help

> Commands:
>   crawler crawl CRAWL_CONFIG                   # Run a crawl of the site
>   crawler schedule CRAWL_CONFIG                # Schedule a recurrent crawl of the site
>   crawler validate CRAWL_CONFIG                # Validate crawler configuration
>   crawler version                              # Print version
```

### Commands

- [`crawler crawl`](#crawler-crawl)
- [`crawler schedule`](#crawler-schedule)
- [`crawler validate`](#crawler-validate)
- [`crawler version`](#crawler-version)

#### `crawler crawl`

Crawls the configured domain in the provided config file.
Can optionally take a second configuration file for Elasticsearch settings.
See [CONFIG.md](./CONFIG.md) for details on the configuration files.

```bash
# crawl using only crawler config
$ bin/crawler crawl config/examples/parks-australia.yml
```

```bash
# crawl using crawler config and optional --es-config
$ bin/crawler crawl config/examples/parks-australia.yml --es-config=config/es.yml
```

#### `crawler schedule`

Creates a schedule to recurrently crawl the configured domain in the provided config file.
The scheduler uses a cron expression that is configured in the Crawler configuration file using the field `schedule.pattern`.
See [scheduling recurring crawl jobs](../README.md#scheduling-recurring-crawl-jobs) for details on scheduling.

Can optionally take a second configuration file for Elasticsearch settings.
See [CONFIG.md](./CONFIG.md) for details on the configuration files.

```bash
# schedule crawls using only crawler config
$ bin/crawler schedule config/examples/parks-australia.yml
```

```bash
# schedule crawls using crawler config and optional --es-config
$ bin/crawler schedule config/examples/parks-australia.yml --es-config=config/es.yml
```

#### `crawler validate`

Checks the configured domains in `domain_allowlist` to see if they can be crawled.

```bash
# when valid
$ bin/crawler validate path/to/crawler.yml

> Domain https://www.elastic.co is valid
```

```bash
# when invalid (e.g. has a redirect)
$ bin/crawler validate path/to/invalid-crawler.yml

> Domain https://elastic.co is invalid:
> The web server at https://elastic.co redirected us to a different domain URL (https://www.elastic.co/).
> If you want to crawl this site, please configure https://www.elastic.co as one of the domains.
```

#### `crawler version`

Checks the product version of Crawler

```bash
$ bin/crawler version

> v0.2.0
```
