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

export BUILDKITE_DIR
export PROJECT_ROOT
export VERSION

if [[ "${USE_SNAPSHOT:-}" == "true" ]]; then
  echo "Adding SNAPSHOT labeling"
  export VERSION="${VERSION}-SNAPSHOT"
fi

export BASE_TAG_NAME="${DOCKER_IMAGE_NAME:-docker.elastic.co/enterprise-search/crawler}"
export DOCKERFILE_PATH="${DOCKERFILE_PATH:-Dockerfile}"
export DOCKER_ARTIFACT_KEY="${DOCKER_ARTIFACT_KEY:-crawler-docker}"

export VAULT_ADDR="${VAULT_ADDR:-https://secrets.elastic.co}"
export VAULT_PATH="secret/k8s/elastic-apps-registry-production/container-library/machine-users/search-crawler-ci"
export DOCKER_PASS_KEY="password"
export DOCKER_USER_KEY="username"
