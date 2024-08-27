# Extraction Rules

This document contains detailed explanation about the individual fields in the extraction ruleset configuration.
There are also [example usages](#examples) at the end of this page.

## Summary

Extraction rules enable you to customize how the crawler extracts content from webpages.
Extraction rules are configured in the Crawler config file.
These are configured under the `domains[].extraction_rulesets` field.

`domains[].extraction_rulesets` is an array, and it is tied to the `url` within the same `domains` array item.
If a crawl result's base URL matches the configured `domains[].url`, then Crawler will check if the crawl result's full URL matches any of the URL filters.
If any of the URL filters match, then Crawler will execute the extraction rules.

## URL Filters

URL filters are an array.
If a URL matches any of the conditions in this array, then all of the extraction rules will be executed.
If the URL filter is empty, then the extraction rules will be applied to every crawl result.

### `domains[].extraction_rulesets[].url_filters[].type`

The type of URL filter that will be used.

Possible values:

- `begins`
  - The beginning of the URL endpoint
- `ends`
  - The end of the URL endpoint
- `contains`
  - Any value match within the endpoint
- `regex`
  - Any regular expression

### `domains[].extraction_rulesets[].url_filters[].pattern`

The pattern the URL filter will follow, dependent on the value for `type`.

The following examples would all work for the URL `http://example.com/blog/help/contact`:

| `type` value | `pattern`  example    |
|--------------|-----------------------|
| `begins`     | `/blog`               |
| `ends`       | `contact`, `/contact` | 
| `contains`   | `help`, `/help/`      | 
| `regex`      | `^blog/help/support$` | 

## Rules

Rules are an array.
If any of the URL filters are true for an endpoint, then Crawler will attempt to execute all of the configured rules in the array.

### `domains[].extraction_rulesets[].rules[].action`

What Crawler should do for this rule.

Possible values:

- `extract` 
  - Crawler will extract the full HTML element found using the `selector`
  - Crawler will directly add it to the document using `field_name` as the doc's field name
  - If multiple values are found, they will be concatenated according to the `join_as` value
- `set`
  - Crawler will see if the HTML element configured in `selector` exists or not
  - If one or multiple elements exist, Crawler will add the configured `value` to the document using `field_name` as the doc's field name
  - If it does not exist, Crawler will not add anything to the document

### `domains[].extraction_rulesets[].rules[].field_name`

The document field name that Crawler will add the extracted content to.
This can be any string value, as long as it is not one of the predefined field names in the [document schema](./DOCUMENT_SCHEMA.md).

### `domains[].extraction_rulesets[].rules[].selector`

The selector for finding the content in HTML.

#### Selectors for `html` sources

If `source` is `html`, this can be a CSS selector or an Xpath selector.

There are examples in W3schools for selector syntax:
- [CSS selectors syntax examples](https://www.w3schools.com/css/css_selectors.asp)
- [XPath selectors syntax examples](https://www.w3schools.com/xml/xpath_syntax.asp)

You can also refer to the official W3C documentation for more details:
- [CSS selectors official documentation](https://www.w3.org/TR/selectors-3/) 
- [XPath selectors official documentation](https://www.w3.org/TR/xpath-31/)

#### Selectors for `url` sources

If `source` is `url`, this must be a regular expression (regexp).
We recommend using capturing groups to explicitly indicate which part of the regular expression needs to stored as a content field.

Here are some examples:

| String                                        | Regex                                       | Match result       | Match group (final result) |
|-----------------------------------------------|---------------------------------------------|--------------------|----------------------------|
| `https://example.org/posts/2023/01/20/post-1` | `posts\/([0-9]{4})`                         | `posts/2023`       | `2023`                     |
| `https://example.org/posts/2023/01/20/post-1` | `posts\/([0-9]{4})\/([0-9]{2})\/([0-9]{2})` | `posts/2023/01/20` | `[2023, 01, 20]`           |

### `domains[].extraction_rulesets[].rules[].join_as`

The method for concatenating multiple values.
This is only applicable if `action` is `extract`.

Values can be `string` or `array`.

### `domains[].extraction_rulesets[].rules[].value`

The value to be inserted into the document if the selector finds any value.
This is only applicable if `action` is `set`.

Value can be anything except `null`.

### `domains[].extraction_rulesets[].rules[].source`

The source that Crawler will try to extract content from.
Currently only `html` or `url` is supported.

## Examples

### Extracting from HTML

I have a simple website for an RPG.
A page describing cities in the RPG is hosted at `https://totally-real-rpg.com/cities`.
The HTML for this page looks like this:

```HTML
<!DOCTYPE html>
<html>
  <body>
    <div>Cities:</div>
    <div class="city">Neverwinter</div>
    <div class="city">Waterdeep</div>
    <div class="city">Menzoberranzan</div>
  </body>
</html>
```

I want to extract all of the cities as an array, but only from the webpage that ends with `/cities`.
First I must set the `url_filters` for this extraction rule to apply to only this URL.
Then I can define what the Crawler should do when it encounters this webpage.

```yaml
domains:
  - url: https://totally-real-rpg.com
    extraction_rulesets:
      - url_filters:
          - type: "ends"
            pattern: "/cities"
        rules:
          - action: "extract"
            field_name: "cities"
            selector: ".city"
            join_as: "array"
            source: "html"
```

In this example, the output document will include the following field on top of the standard crawl result fields:

```json
{
  "cities": ["Neverwinter", "Waterdeep", "Menzoberranzan"]
}
```

### Extracting from URLs

Now, I also have a blog on this website.
There are three posts on this blog, which fall under the following URLs:

- https://totally-real-rpg.com/blog/2023/12/25/beginners-guide
- https://totally-real-rpg.com/blog/2024/01/07/patch-1.0-changes
- https://totally-real-rpg.com/blog/2024/02/18/upcoming-server-maintenance

When these sites are crawled, I want to get only the year that the blog was published.
First I should define the `url_filters` so that this extraction only applies to blogs.
Then I can use a `regex` selector in the rule to fetch the year from the URL.

```yaml
domains:
  - url: https://totally-real-rpg.com
    extraction_rulesets:
      - url_filters:
          - type: "begins"
            pattern: "/blog"
        rules:
          - action: "extract"
            field_name: "publish_year"
            selector: "blog\/([0-9]{4})"
            join_as: "string"
            source: "url"
```
In this example, the ingested documents will include the following fields on top of the standard crawl result fields:

- https://totally-real-rpg.com/blog/2023/12/25/beginners-guide
    ```json
    { "publish_year": "2023" }
    ```
- https://totally-real-rpg.com/blog/2024/01/07/patch-1.0-changes
    ```json
    { "publish_year": "2024" }
    ```
- https://totally-real-rpg.com/blog/2024/02/18/upcoming-server-maintenance
    ```json
    { "publish_year": "2024" }
    ```

### Combined example

Multiple extraction rulesets can be defined for a single Crawler.
Taking the above two examples, we can combine them into a single configuration.
There's no limit to the number of extraction rulesets that can be defined.

```yaml
domains:
  - url: https://totally-real-rpg.com
    extraction_rulesets:
      - url_filters:
            - type: "ends"
              pattern: "/cities"
        rules:
          - action: "extract"
            field_name: "cities"
            selector: ".city"
            join_as: "array"
            source: "html"
      - url_filters:
          - type: "begins"
            pattern: "/blog"
        rules:
          - action: "extract"
            field_name: "publish_year"
            selector: "blog\/([0-9]{4})"
            join_as: "string"
            source: "url"
```
