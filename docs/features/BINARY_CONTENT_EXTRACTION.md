# Binary Content Extraction

The web crawler can extract content from downloadable binary files, such as PDF and DOCX files.
Binary content is extracted by converting file contents to base64 and including the output in a document to index.
This value is picked up by an [Elasticsearch ingest pipeline](https://www.elastic.co/guide/en/elasticsearch/reference/current/ingest.html) that will convert the base64 content into plain text, to store in the `body` field of the same document.

## Using this feature

1. Enable ingest pipelines in the Elasticsearch configuration
2. Enable binary content extraction in the Crawler configuration
3. Select which MIME types should have their contents extracted
   - The MIME type is determined by the HTTP response’s `Content-Type` header when downloading a given file
   - While intended primarily for PDF and Microsoft Office formats, you can use any of the formats supported by [Apache Tika](https://tika.apache.org/)
   - No default MIME types are defined, so at least at least one MIME type must be configured in order to extract non-HTML content
   - The ingest attachment processor does not support compressed files, e.g., an archive file containing a set of PDFs

For example, the following configuration allows for the binary content extraction of PDF and DOCX files, through the default pipeline `ent-search-ingestion-pipeline`:

```yaml
binary_content_extraction_enabled: true
binary_content_extraction_mime_types:
  - application/pdf
  - application/msword

elasticsearch:
   pipeline: ent-search-generic-ingestion
   pipeline_enabled: true
```

Read more on ingest pipelines in Open Crawler [here](./INGEST_PIPELINES.md).
