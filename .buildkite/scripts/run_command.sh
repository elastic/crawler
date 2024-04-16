#!/bin/bash

set -euxo pipefail

COMMAND_TO_RUN=${1:-}

if [[ "${COMMAND_TO_RUN:-}" == "" ]]; then
    echo "Usage: run_command.sh {linter}"
    exit 2
fi

function realpath {
  echo "$(cd "$(dirname "$1")"; pwd)"/"$(basename "$1")";
}

SCRIPT_WORKING_DIR=$(realpath "$(dirname "$0")")
BUILDKITE_DIR=$(realpath "$(dirname "$SCRIPT_WORKING_DIR")")
PROJECT_ROOT=$(realpath "$(dirname "$BUILDKITE_DIR")")

if [[ "${COMMAND_TO_RUN:-}" == "docker" ]]; then
  echo "running docker build"
  make build-docker
else
  DOCKER_IMAGE="docker.elastic.co/ci-agent-images/enterprise-search/rbenv-buildkite-agent:latest"
  SCRIPT_CMD="/ci/.buildkite/scripts/run_ci_step.sh"

  docker run --interactive --rm             \
              --sig-proxy=true --init      \
              --user "root"                \
              --volume "$PROJECT_ROOT:/ci" \
              --workdir /ci                \
              --env HOME=/ci               \
              --env CI                     \
              --env GIT_REVISION=${BUILDKITE_COMMIT-}        \
              --env BUILD_ID=${BUILDKITE_BUILD_NUMBER-}      \
              --entrypoint "${SCRIPT_CMD}" \
              $DOCKER_IMAGE                \
              $COMMAND_TO_RUN
fi
