#!/bin/bash

set -euxo pipefail

export RUBY_VERSION=$(cat .ruby-version)
export JAVA_VERSION=$(cat .java-version)

case $1 in
  install)
    echo "---- installing dependencies"
    make install-ci
    ;;

  lint)
    echo "---- running linter"
    make lint
    ;;

  *)
    echo "Usage: run_command {linter}"
    exit 2
    ;;
esac
