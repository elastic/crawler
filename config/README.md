# Config files

## `elasticsearch.yml`
This configuration file determines the base connection settings to an Elasticsearch instance. These values can be overridden by crawl config values.

## `crawls/{crawler-name}.yml`
The files in the `crawls` directory are for configuring crawls. Each config file can be run a crawl using the CLI.
Elasticsearch connection settings are optional in these files. If they are present, they will override the `elasticsearch.yml` settings for that specific crawler only.

## Load order
The config files are loaded in the following order:

1. `config/elasticsearch.yml`
2. `config/crawls/{crawler-name}.yml`
