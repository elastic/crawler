# Config files

There are two config files that can be used when running Elastic Crawler. This is so multiple crawl jobs can share Elasticsearch settings if required.
The Elasticsearch config file is optional, and all Elasticsearch configurations can be specified in a Crawler configuration if desired.

## `elasticsearch.yml.example`
This configuration file determines the base connection settings to an Elasticsearch instance. These values can be overridden by crawl config values.
Usage example: `./bin/crawl --es-config elasticsearch.yml --crawler-config crawler.yml` (crawler config is still required).

## `crawler.yml.example`
This is an example configuration for configuring crawls. An individually config file can be run a crawl using the CLI.
Elasticsearch connection settings are optional in these files. If they are present, they will override the `elasticsearch.yml` settings for that specific crawler only.
Usage example: `./bin/crawl --crawler-config crawler.yml` (can be used without Elasticsearch config).

## Load order
The config file arguments are loaded in the following order:

1. `--es-config`
2. `--crawler-config`
