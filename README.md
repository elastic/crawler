# Elastic Crawler

This repository contains code for the Elastic Crawler - an tool designed to allow users to ingest content into Elasticsearch easily from the web.

## How it works

The Elastic Crawler runs crawls on command based on configuration files in the `crawlers/` directory. These crawl jobs can output the crawl result to a specified directory.

### Setup

The Elastic Crawler uses jruby. To simplify setup, there are several useful script files under `script/` that will bootstrap the project.

To set up dependencies, simply run `./script/bundle install`.
You can also ensure all crawler commands use up-to-date dependencies by prepending CLI commands with `./script/bundle exec`.

### Running a crawl

To get started, you can either use the example crawler provided, or define your own. If defining your own, create a copy of the file `crawlers/parks-australia.example.yml` and save it to the same directory. You can name this whatever you like. Change any necessary configuration in the file.

Next, run the crawler
`./bin/crawl crawlers/parks-australia.example.yml`

The crawl progress will be logged to your terminal, and results will gradually be added to the specified output directory.
