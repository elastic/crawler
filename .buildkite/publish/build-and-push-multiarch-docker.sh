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
LATEST_TAG_NAME="${BASE_TAG_NAME}:LATEST"
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
echo "Creating ${VERSION} manifest..."
buildah manifest create "$TAG_NAME" \
  "$AMD64_TAG" \
  "$ARM64_TAG"

# ... and push it
echo "Pushing ${VERSION} manifest..."
buildah manifest push "$TAG_NAME" "docker://$TAG_NAME"

# Write out the final manifest for debugging purposes
echo "Built and pushed ${VERSION} multiarch image... dumping final manifest..."
buildah manifest inspect "$TAG_NAME"

# Repeat for LATEST if applicable
if [[ "${APPLY_LATEST_TAG:-}" == "true" ]]; then
  echo "Creating LATEST manifest..."
  buildah manifest create "$LATEST_TAG_NAME" \
    "$AMD64_TAG" \
    "$ARM64_TAG"

  echo "Pushing LATEST manifest..."
  buildah manifest push "$LATEST_TAG_NAME" "docker://$LATEST_TAG_NAME"

  echo "Built and pushed LATEST multiarch image... dumping final manifest..."
  buildah manifest inspect "$LATEST_TAG_NAME"
else
  echo "No LATEST manifest required."
fi
