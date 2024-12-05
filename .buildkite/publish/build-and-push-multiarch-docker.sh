#!/bin/bash

########
# Builds the multiarch docker image and pushes it to the docker registry
########

set -exu
set -o pipefail

# Load our common environment variables for publishing
CURDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export CURDIR

# shellcheck source=./publish-common.sh
source "$CURDIR/publish-common.sh"

# Set our tag name as well as the tag names of the individual platform images
TAG_NAME="${BASE_TAG_NAME}:${VERSION}"
AMD64_TAG="${BASE_TAG_NAME}:${VERSION}-amd64"
ARM64_TAG="${BASE_TAG_NAME}:${VERSION}-arm64"

# Pull the images from the registry
buildah pull "$AMD64_TAG"
buildah pull "$ARM64_TAG"

# ensure +x is set to avoid writing any sensitive information to the console
set +x

# Log into Docker
echo "Logging into docker..."
DOCKER_USER=$(vault read -address "${VAULT_ADDR}" -field "${DOCKER_USER_KEY}" "${VAULT_PATH}")
vault read -address "${VAULT_ADDR}" -field "${DOCKER_PASS_KEY}" "${VAULT_PATH}" | \
  buildah login --username="${DOCKER_USER}" --password-stdin docker.elastic.co

# Create the manifest for the multiarch image
echo "Creating manifest..."
buildah manifest create "$TAG_NAME" \
  "$AMD64_TAG" \
  "$ARM64_TAG"

# ... and push it
echo "Pushing manifest..."
buildah manifest push "$TAG_NAME" "docker://$TAG_NAME"

# Write out the final manifest for debugging purposes
echo "Built and pushed multiarch image... dumping final manifest..."
buildah manifest inspect "$TAG_NAME"
