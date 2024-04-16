#!/bin/bash

set -euxo pipefail

export PATH="$PATH:/root/.jenv/bin:/ci/.jenv/shims:/root/.rbenv/bin:/ci/.rbenv/shims"

case $1 in

  linter)
    echo "---- running linter"
    make install lint
    ;;

  *)
    echo "Usage: run_command {linter}"
    exit 2
    ;;
esac
