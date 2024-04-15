# Configuration

Configuration files live in the [config]('../config') directory.
There are two kinds of configuration files:

1. Crawler configurations (provided in CLI with `--crawler-config`)
2. Elasticsearch configurations (provided in CLI with `--es-config`)

There are two configuration files to allow crawl jobs to share Elasticsearch instance configuration.
There are no enforced pathing or naming for these files.
They are differentiated only by how they are provided to the CLI when running a crawl.

## Crawler configuration files

Crawler configuration files are required for all crawl jobs.
If `elasticsearch` is the output sink, the elasticsearch instance configuration can also be included in a crawler configuration file.
If the elasticsearch configuration is provided this way, it will override any configuration provided in an elasticsearch configuration file.

These are provided in the CLI as an argument for the option `--crawl-config`.

## Elasticsearch configuration files

The Elasticsearch configuration is only required if the output sink is `elasticsearch`.
It is not required for `file` or `console`.

This configuration is also optional.
All of the configuration in this file can be provided in a crawler configuration file as well.
The crawler config is loaded after the Elasticsearch config, so any Elasticsearch settings in the crawler config will take priority.

These are provided in the CLI as an argument for the option `--es-config`.

## Example usage

The config files are provided via opts in the CLI.
The order of the opts is not important.

When performing a crawl with only a crawl config:

```shell
$ ./bin/crawl --crawl-config config/my-crawler.yml
```

When performing a crawl with only both a crawl config and an Elasticsearch config:

```shell
$ ./bin/crawl --crawl-config config/my-crawler.yml --es-config config/elasticsearch.yml
```

## Example configurations

See [examples]('../config/examples') for example configurations.
