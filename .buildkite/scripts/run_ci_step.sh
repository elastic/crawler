#!/bin/bash

set -euxo pipefail

RUBY_VERSION="$(cat .ruby-version)"
JAVA_VERSION="$(cat .java-version)"

export RUBY_VERSION
export JAVA_VERSION

# The Docker image excludes dev/test gems for a leaner production build.
# CI needs them, so clear the 'without' config before installing.
bundle config unset without

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
