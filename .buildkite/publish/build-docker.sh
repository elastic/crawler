#!/bin/bash

########
# Builds the docker image and saves it to an archive file
# so it can be stored as an artifact in Buildkite
########

set -exu
set -o pipefail

if [[ "${ARCHITECTURE:-}" == "" ]]; then
  echo "!! ARCHITECTURE is not set. Exiting."
  exit 2
fi

# Load our common environment variables for publishing
CURDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export CURDIR

# shellcheck source=./publish-common.sh
source "$CURDIR/publish-common.sh"

pushd "$PROJECT_ROOT"

# set our complete tag name and build the image
VERSION_TAG_SUFFIX="${VERSION}-${ARCHITECTURE}"
LATEST_TAG_SUFFIX="LATEST-${ARCHITECTURE}"

TAG_NAME="$BASE_TAG_NAME:${VERSION_TAG_SUFFIX}"
LATEST_TAG_NAME="$BASE_TAG_NAME:${LATEST_TAG_SUFFIX}"

if [[ "${APPLY_LATEST_TAG:-}" == "true" ]]; then
  echo "Creating tags for ${VERSION_TAG_SUFFIX} and ${LATEST_TAG_SUFFIX}"
  docker build -f "$DOCKERFILE_PATH" -t "$TAG_NAME" -t "$LATEST_TAG_NAME" .
else
  echo "Creating tags for ${VERSION_TAG_SUFFIX}"
  docker build -f "$DOCKERFILE_PATH" -t "$TAG_NAME" .
fi

# save the image to an archive file
OUTPUT_PATH="$PROJECT_ROOT/.artifacts"
mkdir -p "$OUTPUT_PATH"

OUTPUT_FILE="$OUTPUT_PATH/${DOCKER_ARTIFACT_KEY}-${VERSION_TAG_SUFFIX}.tar.gz"
echo "Saving ${VERSION_TAG_SUFFIX} image to an archive file ${OUTPUT_FILE}..."
docker save "$TAG_NAME" | gzip > "$OUTPUT_FILE"

if [[ "${APPLY_LATEST_TAG:-}" == "true" ]]; then
  LATEST_OUTPUT_FILE="$OUTPUT_PATH/${DOCKER_ARTIFACT_KEY}-${LATEST_TAG_SUFFIX}.tar.gz"
  echo "Saving ${LATEST_TAG_SUFFIX} image to an archive file ${LATEST_OUTPUT_FILE}..."
  docker save "$LATEST_TAG_NAME" | gzip > "$LATEST_OUTPUT_FILE"
else
  echo "No LATEST image to save archive file for"
fi

popd
