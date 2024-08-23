#!/bin/bash

set -euxo pipefail

RUBY_VERSION="$(cat .ruby-version)"
JAVA_VERSION="$(cat .java-version)"

export RUBY_VERSION
export JAVA_VERSION

case $1 in
  lint)
    echo "---- running linter"
    make install-gems lint lint-scripts
    ;;

  test)
    echo "---- running tests"
    make install test
    ;;

  *)
    echo "Usage: run_command {docker|lint}"
    exit 2
    ;;
esac
