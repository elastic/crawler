# Ingest Pipelines

Open Crawler uses an [Elasticsearch ingest pipeline](https://www.elastic.co/guide/en/elasticsearch/reference/current/ingest.html) to power several content extraction features.
The default pipeline, `ent-search-generic-ingestion`, is automatically created when Elasticsearch first starts.
This pipeline does some pre-processing on documents before they are ingested by Open Crawler.
See [Ingest pipelines for Search indices](https://www.elastic.co/guide/en/elasticsearch/reference/current/ingest-pipeline-search.html) for more details on this pipeline.
