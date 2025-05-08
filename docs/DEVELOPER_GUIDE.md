# Elastic Crawler Developer's Guide

- [Running from Source](#running-from-source)
- [Configuration](#configuration)
- [Installation](#installation)
- [Architecture](#architecture)
- [Testing the elastic-crawler](#testing-the-elastic-crawler)
  - [Unit tests](#unit-tests)

## Running from Source

ℹ️ Open Crawler uses both JRuby and Java.
We recommend using version managers for both.
When developing Open Crawler we use <b>rbenv</b> and <b>jenv</b>.
There are instructions for setting up these env managers here:

- [Official documentation for installing jenv](https://www.jenv.be/)
- [Official documentation for installing rbenv](https://github.com/rbenv/rbenv?tab=readme-ov-file#installation)

1. Clone the repository: `git clone https://github.com/elastic/crawler.git`
2. Go to the root of the Open Crawler directory and check the expected Java and Ruby versions are being used:
    ```bash
    # should output the same version as `.ruby-version`
    ruby --version

    # should output the same version as `.java-version`
    java -version
    ```
3. If the versions seem correct, you can install dependencies:
    ```bash
    make install
    ```

   You can also use the env variable `CRAWLER_MANAGE_ENV` to have the install script automatically check whether `rbenv` and `jenv` are installed, and that the correct versions are running on both:
   Doing this requires that you use both `rbenv` and `jenv` in your local setup.

    ```bash
    CRAWLER_MANAGE_ENV=true make install
    ```
4. Now you should be able to run Crawler locally
    ```bash
   bin/crawler crawl path/to/config.yml
   ```

## Configuration

The crawler details need to be provided in a crawler configuration file.
You can specify Elasticsearch instance configuration within that file, or optionally in a separate configuration file.
This allows multiple crawlers to share a single Elasticsearch configuration.

For more details check out the following [documentation](https://github.com/elastic/elastic-crawler/blob/main/docs/CONFIG.md).

## Architecture

Starting with the endpoints specified in `seed_urls` in the config, the [coordinator](../lib/crawler/coordinator.rb) creates a [crawl task](../lib/crawler/data/crawl_task.rb) and adds it to a queue.
These are then executed by the [HTTP executor](../lib/crawler/http_executor.rb), which will produce a [crawl result](../lib/crawler/data/crawl_result.rb), which contains further links to follow.
The coordinator will then send the crawl result to the [output sink](../lib/crawler/output_sink.rb), and create more crawl tasks for the links it found.
The output sink will then format the doc using the [document mapper](../lib/crawler/document_mapper.rb) before outputting the result.

If the output sink is `console` or `file`, it simply outputs the crawl result as soon as it is crawled.

If the output sink is `elasticsearch`, it adds crawl results to a bulk queue for processing.
The bulk queue is added to until a threshold is met (either queue number or queue size in bytes).
It will then flush the queue, which prompts a `_bulk` API request to the configured Elasticsearch instance.
The `_bulk` API settings can be configured in the config file.

## Testing the elastic-crawler

Unit tests are found under the [spec](../spec) directory.
We require unit tests to be added or updated for every contribution.

### Unit Tests

We have makefile commands to run tests.
These act as a wrapper around a typical `bundle exec rspec` command.
You can use the makefile command to run all tests in the repo, all tests in a single file, or a single spec in a file.
Target files are specified with the `file=/path/to/spec` argument.

```shell
# run all tests in elastic-crawler
make test

# runs all unit tests in `crawl_spec.rb`
make test file=spec/lib/crawler/api/crawl_spec.rb

# runs only the unit test on line 35 in `crawl_spec.rb`
make test file=spec/lib/crawler/api/crawl_spec.rb:35
```
