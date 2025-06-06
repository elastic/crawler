# Configuration

The Open Crawler uses YAML configuration files to define crawl behavior and connection settings. Template configuration files and examples are located in the [config](../config) directory.

There are two types of configuration files:

- [`crawler.yml`](#crawler-configuration-files) 
  - **Required** for all crawls. Defines what to crawl, where to send results, and crawl behavior settings.
    - Example: [config/crawler.yml.example](../config/crawler.yml.example)
- [`elasticsearch.yml`](#elasticsearch-configuration-files)
  - **Optional** separate file for Elasticsearch connection settings. Useful when running multiple crawlers that share the same Elasticsearch instance.
    - Example: [config/elasticsearch.yml.example](../config/elasticsearch.yml.example)

> [!NOTE]
> You can include Elasticsearch settings directly in your crawler configuration file instead of using a separate file. Settings in the crawler configuration take precedence over the separate Elasticsearch configuration.
> The standalone Elasticsearch configuration file is only needed if you want to share connection settings across multiple crawlers. Most users can put everything in the crawler configuration file.

## Crawler configuration files (`crawler.yml`)

Crawler configuration files are required for all crawl jobs.
If `elasticsearch` is the output sink, the elasticsearch instance configuration can also be included in a crawler configuration file.
If the elasticsearch configuration is provided this way, it will override any configuration provided in an elasticsearch configuration file.

These are provided in the CLI as a positional argument, e.g. `bin/crawler crawl path/to/my-crawler.yml`.

## Elasticsearch configuration files (`elasticsearch.yml`)

The Elasticsearch configuration is only required if the output sink is `elasticsearch`.
It is not required for `file` or `console`.

This configuration is also optional.
All of the configuration in this file can be provided in a crawler configuration file as well.
The crawler config is loaded after the Elasticsearch config, so any Elasticsearch settings in the crawler config will take priority.

These are provided in the CLI as a named argument for the option `--es-config`, e.g. `bin/crawler crawl path/to/my-crawler.yml --es-config=/path/to/elasticsearch.yml`

### Connecting to Elasticsearch with Self-Signed Certificates

If your Elasticsearch instance uses SSL/TLS with certificates signed by a private Certificate Authority (CA) or uses self-signed certificates, you will need to configure the crawler to trust these certificates.

1.  **Obtain the CA Certificate:** Get the CA certificate file (usually a `.pem` or `.crt` file) that was used to sign your Elasticsearch node certificates. If using self-signed certificates directly on the nodes, you might need the certificate file for each node or a combined CA file.
2.  **Configure `ca_file`:** Place the CA certificate file(s) in a directory accessible to the crawler. In your `elasticsearch.yml` or crawler configuration file, set the `elasticsearch.ca_file` parameter to the certificate.
    ```yaml
    elasticsearch.ca_file: /path/to/your/ca.crt
    ```

**Note:** For detailed explanations of all Elasticsearch connection parameters, including authentication and other SSL options, refer to the comments within the [config/elasticsearch.yml.example](../config/elasticsearch.yml.example) file.

### Sink Lock Retry Settings

These settings control the retry behavior when the Elasticsearch output sink is locked.

*   `sink_lock_retry_interval`: The interval in seconds to wait before retrying to acquire the sink lock. Defaults to `1`.
*   `sink_lock_max_retries`: The maximum number of times to retry acquiring the sink lock before dropping the crawl result. Defaults to `120`.

## Configuration files in Docker

See [CLI in Docker](./CLI.md#cli-in-docker) for details on how to mount configuration files into the Docker container for use with commands.

## Example usage

The config files are provided via opts in the CLI.
The order of the opts is not important.

When performing a crawl with only a crawl config:

```shell
bin/crawler crawl config/my-crawler.yml
```

When performing a crawl with both a crawl config and an Elasticsearch config:

```shell
bin/crawler crawl config/my-crawler.yml --es-config config/elasticsearch.yml
```

## Environment Variables

```yaml
elasticsearch:
  username: <%= ENV['ES_USER'] %>
  password: <%= ENV['ES_PASS'] %>
```

**Example: Default Value Logic**

```yaml
output_path: <%= ENV['OUTPUT_PATH'] || '/tmp/crawl-output' %>
```

**How it works:**
- Before parsing YAML, the file is processed with [Embedded Ruby (ERB) template syntax](https://github.com/ruby/erb).
- You can use any Ruby code inside `<%= ... %>` tags, but the most common use is referencing environment variables.

## Example configurations

For more examples, see the sample configuration files in the [config directory](../config).