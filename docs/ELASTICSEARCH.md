# Ingesting Data into Elasticsearch

A running instance of Elasticsearch is required to index documents.
If you don't have this set up yet, you can sign up for an [Elastic Cloud free trial](https://www.elastic.co/cloud/cloud-trial-overview) or check out the [quickstart guide for Elasticsearch](https://www.elastic.co/guide/en/elasticsearch/reference/master/quickstart.html).

## Connecting to Elasticsearch

Open Crawler interacts with a single Elasticsearch index, which is configured by the user in the config file under `output_index`.
To facilitate this, Open Crawler needs to have either an API key or a username/password configured to access the index.
If using an API key, ensure that the API key has read and write permissions to access the configured index.

- [Elasticsearch documentation](https://www.elastic.co/guide/en/elasticsearch/reference/current/security-api-create-api-key.html) for managing API keys for more details
- [elasticsearch.yml.example](../config/elasticsearch.yml.example) file for all of the available Elasticsearch configurations for Crawler

### Creating an API key
Here is an example of creating an API key with minimal permissions for Open Crawler.
This will return a JSON with an `encoded` key.
The value of `encoded` is what Open Crawler can use in its configuration.

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
          "privileges": ["monitor"]
        }
      ]
    }
  },
  "metadata": {
    "application": "my-crawler"
  }
}
```

## Configuring Crawlers

Crawler has template configuration files that contain every configuration available.

- [config/crawler.yml.example](../config/crawler.yml.example)
- [config/elasticsearch.yml.example](../config/elasticsearch.yml.example)

Crawler can be configured using two config files, a Crawler configuration and an optional Elasticsearch configuration.
The Elasticsearch configuration exists to allow users with multiple crawlers to share a common Elasticsearch configuration.

See [CONFIG.md](CONFIG.md) for more details on these files.
