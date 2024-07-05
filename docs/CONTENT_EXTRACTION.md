# Content Extraction

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
  - If it does exist, Crawler will add the configured `value` to the document using `field_name` as the doc's field name
  - If it does not exist, Crawler will not add anything to the document

### `domains[].extraction_rulesets[].rules[].field_name`

The document field name that Crawler will add the extracted content to.
This can be any string value, as long as it is not one of the following reserved field names.

- `body_content`
- `domains`
- `headings`
- `meta_description`
- `title`
- `url`
- `url_host`
- `url_path`
- `url_path_dir1`
- `url_path_dir2`
- `url_path_dir3`
- `url_port`
- `url_scheme`

### `domains[].extraction_rulesets[].rules[].selector`

The selector for finding the content in HTML.
Can be a CSS selector or an Xpath selector.

There are examples in W3schools for selector syntax:
- [CSS selectors syntax examples](https://www.w3schools.com/css/css_selectors.asp)
- [XPath selectors syntax examples](https://www.w3schools.com/xml/xpath_syntax.asp)

You can also refer to the official W3C documentation for more details:
- [CSS selectors official documentation](https://www.w3.org/TR/selectors-3/) 
- [XPath selectors official documentation](https://www.w3.org/TR/xpath-31/)

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
Currently only `html` is supported.
