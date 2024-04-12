# Elastic Crawler Developer's Guide

- [General Configuration](#general-configuration)
- [Installation](#installation)
- [Architecture](#architecture)
- [Testing the elastic-crawler](#testing-the-elastic-crawler)
  - [Unit tests](#unit-tests)

## General Configuration

The crawler details need to be provided in a crawler configuration file.
You can specify Elasticsearch instance configuration within that file, or optionally in a separate configuration file.
This is possible so that multiple crawlers can run using a single Elasticsearch configuration.

For more details check out the following [documentation](https://github.com/elastic/elastic-crawler/blob/main/docs/CONFIG.md).

## Installation

This project uses JRuby. To simplify handling dependencies between both Ruby and Java, we have scripts that handle installation.
To avoid breaking anything in your project, __avoid running bundle directly__.
If you need to run bundle, always do so through the `./script/bundle` command.

To install dependencies, run:
```shell
$ ./script/bundle install
```

Checkout the bundle script file if you're curious what is happening. A summary of its behaviour:

- Inits rbenv and jenv
- Sets versions for bundler, ruby, and java
- Installs ruby and java dependencies
- Executes whatever code comes after it

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

To test the elastic-crawler, run:

```shell
./script/rspec path/to/file_spec.rb
```
