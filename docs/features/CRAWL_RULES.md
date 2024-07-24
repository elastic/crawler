# Crawl Rules

A crawl rule is a crawler instruction to allow or disallow specific paths within a domain.
These are configured in the crawler's yaml config file.

A single domain can have multiple crawl rules.
Remember that order matters and each URL is evaluated according to the first match.
Any URLs that do not match a crawl rule will be crawled as normal.
If you want the web crawler to change this behaviour, be sure to end your crawl rules with a catch-all `deny` rule (see [restricting paths using crawl rules](#restricting-paths-using-crawl-rules) for details).

## Crawl rule logic (rules)

The logic for each rule is as follows:

### `begins`

- The path pattern is a literal string except for the character `*`, which is a meta character that will match anything
- The rule matches when the path pattern matches the beginning of the path (which always begins with `/`)
- If using this rule, begin your path pattern with `/`

### `ends`

- The path pattern is a literal string except for the character `*`, which is a meta character that will match anything
- The rule matches when the path pattern matches the end of the path

### `contains`

- The path pattern is a literal string except for the character `*`, which is a meta character that will match anything.
- The rule matches when the path pattern matches anywhere within the path.

### `regex`

- The path pattern is a regular expression compatible with the Ruby language regular expression engine
  - In addition to literal characters, the path pattern may include:
    - [Metacharacters](https://ruby-doc.org/core-3.1.0/Regexp.html#class-Regexp-label-Metacharacters+and+Escapes)
    - [Character classes](https://ruby-doc.org/core-3.1.0/Regexp.html#class-Regexp-label-Character+Classes)
    - [Repetitions](https://ruby-doc.org/core-3.1.0/Regexp.html#class-Regexp-label-Repetition)
  - You can test Ruby regular expressions using [Rubular](https://rubular.com/)
- The rule matches when the path pattern matches the beginning of the path (which always begins with `/`)
- If using this rule, begin your path pattern with `\/` or a metacharacter or character class that matches `/`

## Crawl rule matching

The following table provides various examples of crawl rule matching:

| URL path                  | Rule type  | Path pattern   | Match? |
|---------------------------|------------|----------------|--------|
| `/foo/bar`                | `begins`   | `/foo`         | YES    |
| `/foo/bar`                | `begins`   | `/*oo`         | YES    |
| `/bar/foo`                | `begins`   | `/foo`         | NO     |
| `/foo/bar`                | `begins`   | `foo`          | NO     |
| `/blog/posts/hello-world` | `ends`     | `world`        | YES    |
| `/blog/posts/hello-world` | `ends`     | `hello-*`      | YES    |
| `/blog/world-hello `      | `ends`     | `world `       | NO     |
| `/blog/world-hello`       | `ends`     | `*world`       | NO     |
| `/fruits/bananas`         | `contains` | `banana`       | YES    |
| `/fruits/apples`          | `contains` | `banana`       | NO     |
| `/2020`                   | `regex`    | `\/[0-9]{3,5}` | YES    |
| `/20`                     | `regex`    | `\/[0-9]{3,5}` | NO     |
| `/2020`                   | `regex`    | `[0-9]{3,5}`   | NO     |

## Restricting paths using crawl rules

To restrict paths, use either of the following techniques:

1. Add rules that disallow specific paths (e.g. disallow any URLs that begin with `/blog`):
    ```yaml
    domains:
    - url: http://example.com
      crawl_rules:
      - policy: deny
        type: begins
        pattern: /blog
    ```

2. Add rules that allow specific paths and disallow all others (e.g. allow only URLs that begin with `/blog`):
    ```yaml
    domains:
    - url: http://example.com
      seed_urls:
        - http://example.com/blog
      crawl_rules:
      - policy: allow
        type: begins
        pattern: /blog
      - policy: deny
        type: regex
        pattern: .*
    ```
    When you restrict a crawl to specific paths, be sure to add entry points that allow the crawler to discover those paths.
    For example, if your crawl rules restrict the crawler to `/blog`, add `/blog` as an entry point.
    If you leave only the default entry point `/`, the crawl will end immediately, since `/` is disallowed.