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
export CURDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $CURDIR/publish-common.sh

pushd $PROJECT_ROOT

# set our complete tag name and build the image
TAG_NAME="$BASE_TAG_NAME:${VERSION}-${ARCHITECTURE}"
docker build -f $DOCKERFILE_PATH -t $TAG_NAME .

# save the image to an archive file
OUTPUT_PATH="$PROJECT_ROOT/.artifacts"
OUTPUT_FILE="$OUTPUT_PATH/${DOCKER_ARTIFACT_KEY}-${VERSION}-${ARCHITECTURE}.tar.gz"
mkdir -p $OUTPUT_PATH
docker save $TAG_NAME | gzip > $OUTPUT_FILE

popd
