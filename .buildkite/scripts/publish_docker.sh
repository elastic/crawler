#!/bin/bash

# !!! WARNING DO NOT add -x to avoid leaking vault passwords
set -euo pipefail

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install ca-certificates curl gnupg lsb-release -y

BASEDIR=$(realpath $(dirname $0))
ROOT=$(realpath $BASEDIR/../)

cd $ROOT

# docker snapshot publication
echo "Building the image"
make docker-build

# !!! WARNING be cautious about the following lines, to avoid leaking the secrets in the CI logs

set +x   # Do not remove so we don't leak passwords
VAULT_ADDR=${VAULT_ADDR:-https://secrets.elastic.co}

echo "Fetching Docker credentials for '$VAULT_USER' from Vault..."
DOCKER_USER=$(vault read -address "${VAULT_ADDR}" -field user_20230609 secret/ci/elastic-connectors/${VAULT_USER})
DOCKER_PASSWORD=$(vault read -address "${VAULT_ADDR}" -field secret_20230609 secret/ci/elastic-connectors/${VAULT_USER})
echo "Done!"
echo

echo "Logging into Docker as '$DOCKER_USER'..."
docker login -u "${DOCKER_USER}" -p ${DOCKER_PASSWORD} docker.elastic.co
echo "Done!"
echo
echo "Pushing the image to docker.elastic.co"
make docker-push
