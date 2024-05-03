#!/bin/bash

set -euxo pipefail

export RUBY_VERSION=$(cat .ruby-version)
export JAVA_VERSION=$(cat .java-version)

case $1 in
  lint)
    echo "---- running linter"
    make install-gems lint
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
