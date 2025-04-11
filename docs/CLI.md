# CLI

Crawler CLI is a command-line interface for use in the terminal or scripts.
This is the only user interface for interacting with Crawler.

## Installation and Configuration

Ensure you complete the [setup](../README.md#setup) before using the CLI.

For instructions on configuring a Crawler, see [CONFIG.md](./CONFIG.md).

### CLI in Docker

If you are running a dockerized version of Crawler, you can run CLI commands in two ways;

1. Exec into the docker container and execute commands directly using `docker exec -it <container name> bash`
    - This requires no changes to CLI commands
    ```bash
    # exec into container
    $ docker exec -it crawler bash
    
    # execute commands
    $ bin/crawler version
    ```
2. Execute commands externally using `docker exec -it <container name> <command>`
    ```bash
    # execute command directly without entering docker container
    $ docker exec -it crawler bin/crawler version
    ```

## Available commands
### Getting help
Use the `--help or -h` option with any command to get more information.

For example:
```bash
$ bin/crawler --help

> Commands:
>   crawler crawl CRAWL_CONFIG                   # Run a crawl of the site
>   crawler schedule CRAWL_CONFIG                # Schedule a recurrent crawl of the site
>   crawler urltest CRAWL_CONFIG                 # Test a URL against a configuration
>   crawler validate CRAWL_CONFIG                # Validate crawler configuration
>   crawler version                              # Print version
```

### Commands

- [`crawler crawl`](#crawler-crawl)
- [`crawler schedule`](#crawler-schedule)
- [`crawler urltest`](#crawler-urltest)
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

#### `crawler urltest`

Crawls a single URL against the provided crawler config and optional Elasticsearch config, and provides a brief summary
of the crawl as well as the downloaded document.

The downloaded document will appear under `/crawled_docs` unless otherwise specified with the `output_dir` config
field in your crawler config.

```bash
> bin/crawler urltest config/my-crawler.yml https://www.speedhunters.com/2025/01/project-964-hitting-the-touge-for-the-first-time-in-rwb-form/

[2025-04-10T09:26:10.806Z] [crawl:67f7c6f2714375360db0a1b8] [primary] Initialized an in-memory URL queue for up to 10000 URLs
[2025-04-10T09:26:10.810Z] [crawl:67f7c6f2714375360db0a1b8] [primary] ... // logs truncated for brevity
[2025-04-10T09:26:15.100Z] [crawl:67f7c6f2714375360db0a1b8] [primary] Finished a crawl. Result: failure; Successfully finished the primary crawl with an empty crawl queue |

---- URL Test Results ----
- Attempted to crawl https://www.speedhunters.com/2025/01/project-964-hitting-the-touge-for-the-first-time-in-rwb-form/
- Status code: 200
- Content type: text/html; charset=UTF-8
- Crawl duration (seconds): 2.8990111351013184
- Extracted links:
  - http://store.speedhunters.com
  - http://store.speedhunters.com
  - http://www.speedhunters.com/category/carfeatures/
  - http://www.speedhunters.com/tag/car-spotlight/
  - http://www.speedhunters.com/tag/dragracing/
  - https://www.speedhunters.com
  - https://www.speedhunters.com
  - https://www.speedhunters.com/2025/01/project-964-hitting-the-touge-for-the-first-time-in-rwb-form/#content
  - https://www.speedhunters.com/category/content/
  - https://www.speedhunters.com/category/content/special-feature/

You can find the downloaded document under ./crawled_docs
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
