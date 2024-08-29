# Configuration

Configuration files live in the [config](../config) directory.
There are two kinds of configuration files:

- Crawler configuration - [config/crawler.yml.example](../config/crawler.yml.example)
- Elasticsearch configuration - [config/elasticsearch.yml.example](../config/elasticsearch.yml.example)

The Elasticsearch configuration file is optional.
It exists to allow users with multiple crawlers to only need a single Elasticsearch configuration.

There are no enforced pathing or naming for these files.
They are differentiated only by how they are provided to the CLI when running a crawl.

## Crawler configuration files

Crawler configuration files are required for all crawl jobs.
If `elasticsearch` is the output sink, the elasticsearch instance configuration can also be included in a crawler configuration file.
If the elasticsearch configuration is provided this way, it will override any configuration provided in an elasticsearch configuration file.

These are provided in the CLI as a positional argument, e.g. `bin/crawler crawl path/to/my-crawler.yml`.

## Elasticsearch configuration files

The Elasticsearch configuration is only required if the output sink is `elasticsearch`.
It is not required for `file` or `console`.

This configuration is also optional.
All of the configuration in this file can be provided in a crawler configuration file as well.
The crawler config is loaded after the Elasticsearch config, so any Elasticsearch settings in the crawler config will take priority.

These are provided in the CLI as a named argument for the option `--es-config`, e.g. `bin/crawler crawl path/to/my-crawler.yml --es-config=/path/to/elasticsearch.yml`

## Configuration files in Docker

If you are running Crawler in docker, you will need to copy any configuration files into the container before you can crawl content.
This will need to be done every time a change is made to these files, unless you are editing the file directly inside the Docker container.

```bash
$ docker cp /path/to/my-crawler.yml crawler:app/config/my-crawler.yml
```

## Example usage

The config files are provided via opts in the CLI.
The order of the opts is not important.

When performing a crawl with only a crawl config:

```shell
$ bin/crawler crawl config/my-crawler.yml
```

When performing a crawl with both a crawl config and an Elasticsearch config:

```shell
$ bin/crawler crawl config/my-crawler.yml --es-config config/elasticsearch.yml
```

## Example configurations

See [examples](../config/examples) for example configurations.
