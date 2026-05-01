# HTML to Markdown Reformatting


The Open Crawler can automatically reformat HTML content into Markdown before indexing it into Elasticsearch. This is particularly useful for Large Language Model (LLM) applications and Retrieval-Augmented Generation (RAG), as Markdown is often a preferred format for these systems.

## Configuration

To enable Markdown reformatting, set `markdown_reformatting_enabled: true` in your crawler configuration file.

```yaml
# crawler.yml
markdown_reformatting_enabled: true
```

## How it Works

When enabled, the crawler will:

1.  Extract the relevant content from the HTML body (respecting `exclude_tags` and `data-elastic-exclude` attributes).
2.  Convert common HTML tags into their Markdown equivalents:
    *   Headers (`<h1>` - `<h6>`)
    *   Paragraphs (`<p>`) and line breaks (`<br>`)
    *   Bold (`<strong>`, `<b>`) and Italic (`<em>`, `<i>`)
    *   Links (`<a>`)
    *   Lists (`<ul>`, `<ol>`, `<li>`)
    *   Images (`<img>`)
    *   Code blocks (`<code>`, `<pre>`)
3.  Remove non-content tags like `<script>`, `<style>`, `<svg>`, etc.
4.  Consolidate multiple newlines to maintain clean Markdown structure.

## Benefits for RAG

*   **Improved Context:** LLMs are typically trained on large amounts of Markdown content (e.g., from GitHub, Wikipedia), making them more effective at parsing and understanding reformatted web content.
*   **Reduced Token Usage:** Markdown often uses fewer characters than raw HTML to represent the same structure, helping to optimize token usage in LLM prompts.
*   **Cleaner Data:** By removing unnecessary HTML boilerplate and non-content tags, you ensure that the indexed data is focused on the actual information.
