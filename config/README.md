# Config files

## `elasticsearch.yml`
This configuration file determines the base connection settings to an Elasticsearch instance. This is applied to all crawlers, unless the crawler specifies a different connection configuration.

## `crawlers/{crawler-name}.yml`
The files in the `crawlers` directory are for configuring crawlers. Each file can be run as a single crawler using the CLI.
Elasticsearch connection settings are optional in these files. If they are present, they will override the `elasticsearch.yml` settings for that specific crawler only.

## Load order
The config files are loaded in the following order:

1. `config/elasticsearch.yml`
2. `config/crawlers/{crawler-name}.yml`
