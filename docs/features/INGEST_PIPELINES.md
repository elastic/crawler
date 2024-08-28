# Ingest Pipelines

Open Crawler uses an [Elasticsearch ingest pipeline](https://www.elastic.co/guide/en/elasticsearch/reference/current/ingest.html) to power several content extraction features.
The default pipeline, `ent-search-generic-ingestion`, is automatically created when Enterprise Search first starts.
This pipeline does some pre-processing on documents before they are ingested by Open Crawler.
See [Ingest pipelines for Search indices](https://www.elastic.co/guide/en/elasticsearch/reference/current/ingest-pipeline-search.html) for more details on this pipeline.

> ![NOTE]
If you are running Open Crawler without an Enterprise Search node and want to use these pipeline features, you will need to manually create this pipeline.

## Creating the ingest pipeline without Enterprise Search

You can use the [Create pipeline API](https://www.elastic.co/guide/en/elasticsearch/reference/current/put-pipeline-api.html) to create the missing pipeline without relying on an Enterprise Search node.

Run the following to create the default ingest pipeline.
This will create the same pipeline that is usually created by the Enterprise Search node.
The pipeline name can be anything you like, in this example we are using `my-crawler-pipeline`.
If you want to know what a specific step does in the pipeline process, check out [`ent-search-generic-ingestion` reference](https://www.elastic.co/guide/en/elasticsearch/reference/current/ingest-pipeline-search.html#ingest-pipeline-search-details-generic-reference).

```
PUT _ingest/pipeline/my-crawler-pipeline
{
  "description": "A pipeline for extracting binary content for Crawler",
  "processors": [
    {
      "attachment": {
        "description": "Extract text from binary attachments",
        "field": "_attachment",
        "target_field": "_extracted_attachment",
        "ignore_missing": true,
        "indexed_chars_field": "_attachment_indexed_chars",
        "if": "ctx?._extract_binary_content == true",
        "on_failure": [
          {
            "append": {
              "description": "Record error information",
              "field": "_ingestion_errors",
              "value": "Processor 'attachment' in pipeline '{{ _ingest.on_failure_pipeline }}' failed with message '{{ _ingest.on_failure_message }}'"
            }
          }
        ],
        "remove_binary": false
      }
    },
    {
      "set": {
        "tag": "set_body",
        "description": "Set any extracted text on the 'body' field",
        "field": "body",
        "copy_from": "_extracted_attachment.content",
        "ignore_empty_value": true,
        "if": "ctx?._extract_binary_content == true",
        "on_failure": [
          {
            "append": {
              "description": "Record error information",
              "field": "_ingestion_errors",
              "value": "Processor 'set' with tag 'set_body' in pipeline '{{ _ingest.on_failure_pipeline }}' failed with message '{{ _ingest.on_failure_message }}'"
            }
          }
        ]
      }
    },
    {
      "gsub": {
        "tag": "remove_replacement_chars",
        "description": "Remove unicode 'replacement' characters",
        "field": "body",
        "pattern": "�",
        "replacement": "",
        "ignore_missing": true,
        "if": "ctx?._extract_binary_content == true",
        "on_failure": [
          {
            "append": {
              "description": "Record error information",
              "field": "_ingestion_errors",
              "value": "Processor 'gsub' with tag 'remove_replacement_chars' in pipeline '{{ _ingest.on_failure_pipeline }}' failed with message '{{ _ingest.on_failure_message }}'"
            }
          }
        ]
      }
    },
    {
      "gsub": {
        "tag": "remove_extra_whitespace",
        "description": "Squish whitespace",
        "field": "body",
        "pattern": "\\s+",
        "replacement": " ",
        "ignore_missing": true,
        "if": "ctx?._reduce_whitespace == true",
        "on_failure": [
          {
            "append": {
              "description": "Record error information",
              "field": "_ingestion_errors",
              "value": "Processor 'gsub' with tag 'remove_extra_whitespace' in pipeline '{{ _ingest.on_failure_pipeline }}' failed with message '{{ _ingest.on_failure_message }}'"
            }
          }
        ]
      }
    },
    {
      "trim": {
        "description": "Trim leading and trailing whitespace",
        "field": "body",
        "ignore_missing": true,
        "if": "ctx?._reduce_whitespace == true",
        "on_failure": [
          {
            "append": {
              "description": "Record error information",
              "field": "_ingestion_errors",
              "value": "Processor 'trim' in pipeline '{{ _ingest.on_failure_pipeline }}' failed with message '{{ _ingest.on_failure_message }}'"
            }
          }
        ]
      }
    },
    {
      "remove": {
        "tag": "remove_meta_fields",
        "description": "Remove meta fields",
        "field": [
          "_attachment",
          "_attachment_indexed_chars",
          "_extracted_attachment",
          "_extract_binary_content",
          "_reduce_whitespace",
          "_run_ml_inference"
        ],
        "ignore_missing": true,
        "on_failure": [
          {
            "append": {
              "description": "Record error information",
              "field": "_ingestion_errors",
              "value": "Processor 'remove' with tag 'remove_meta_fields' in pipeline '{{ _ingest.on_failure_pipeline }}' failed with message '{{ _ingest.on_failure_message }}'"
            }
          }
        ]
      }
    }
  ]
}
```

## Managing ingest pipelines in Kibana

You can also [view and manage](https://www.elastic.co/guide/en/elasticsearch/reference/current/ingest.html#create-manage-ingest-pipelines) this pipeline in Kibana.
