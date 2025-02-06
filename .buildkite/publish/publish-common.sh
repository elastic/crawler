#!/bin/bash

if [[ "${CURDIR:-}" == "" ]]; then
  echo "!! CURDIR is not set. Exiting."
  exit 2
fi

function realpath {
  echo "$(cd "$(dirname "$1")" || exit; pwd)"/"$(basename "$1")";
}

export SCRIPT_DIR="$CURDIR"

BUILDKITE_DIR=$(realpath "$(dirname "$SCRIPT_DIR")")
PROJECT_ROOT=$(realpath "$(dirname "$BUILDKITE_DIR")")
VERSION_PATH="$PROJECT_ROOT/product_version"
VERSION=$(cat "$VERSION_PATH")
IS_SNAPSHOT=$(buildkite-agent meta-data get is_snapshot)

export BUILDKITE_DIR
export PROJECT_ROOT
export VERSION

if [[ "${IS_SNAPSHOT:-}" == "true" ]]; then
  echo "Adding SNAPSHOT labeling"
  export VERSION="${VERSION}-SNAPSHOT"
fi

export BASE_TAG_NAME="${DOCKER_IMAGE_NAME:-docker.elastic.co/integrations/crawler}"
export DOCKERFILE_PATH="${DOCKERFILE_PATH:-Dockerfile.wolfi}"
export DOCKER_ARTIFACT_KEY="${DOCKER_ARTIFACT_KEY:-elastic-crawler-docker}"

export VAULT_ADDR="${VAULT_ADDR:-https://vault-ci-prod.elastic.dev}"
export VAULT_PATH="secret/ci/elastic-crawler/docker-ci-admin"
export DOCKER_PASS_KEY="secret_20240823"
export DOCKER_USER_KEY="user_20240823"
