# Elastic Open Web Crawler

This repository contains code for the Elastic Open Web Crawler.
This is a tool to allow users to ingest content into Elasticsearch easily from the web.

## How it works

Crawler runs crawl jobs on command based on config files in the `config` directory.
1 URL endpoint on a site will correlate with 1 result output.

The crawl results can be output in 3 different modes:

- As docs to an Elasticsearch index
- As files to a specified directory
- Directly to the terminal

### Setup

#### Running from source

Crawler uses `jenv` and `rbenv` to manage both java and ruby versions.

1. Install `jenv` and `rbenv`
    - [Official documentation for installing jenv](https://www.jenv.be/)
    - [Official documentation for installing rbenv](https://github.com/rbenv/rbenv?tab=readme-ov-file#installation)
2. Install the required java version (check the file `.java-version`) and add it to `jenv`
    ```bash
    # jenv is a little complicated to set up
    # this is an example for openjdk@21 on mac using homebrew
    # first install the java version
    brew install openjdk@21

    # create symlink 
    sudo ln -sfn \
      /opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk \
      /Library/Java/JavaVirtualMachines/openjdk-21.jdk

    # add to jenv and update JAVA_HOME
    jenv add /Library/Java/JavaVirtualMachines/openjdk-21.jdk/Contents/Home
    export JAVA_HOME=$(/usr/libexec/java_home -v21)

    # check java version, which should be set by `.java-version` file
    java --version
    ```
3. Install the required jruby version
    ```bash
    # rbenv is easier to use and can install a version based on `.ruby-version` file
    rbenv install

    # check ruby version
    ruby --version
    ```
4. Run `make install` to install Crawler dependencies

### Configuring and running a crawl job

See [CONFIG.md](docs/CONFIG.md) for more details.
