#!/bin/bash

set -euxo pipefail

export RUBY_VERSION=$(cat .ruby-version)
export JAVA_VERSION=$(cat .java-version)

case $1 in
  lint)
    echo "---- running linter"
    make install-gems lint
    ;;

  *)
    echo "Usage: run_command {linter}"
    exit 2
    ;;
esac
