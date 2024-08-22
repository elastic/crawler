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
VAULT_DIR="secret/k8s/elastic-apps-registry-production/container-library/machine-users/search-crawler-ci"
DOCKER_PASS_KEY="password"
DOCKER_USER_KEY="username"

echo "Fetching Docker credentials from Vault..."
DOCKER_USER=$(vault read -address "${VAULT_ADDR}" -field ${DOCKER_USER_KEY} ${VAULT_DIR})
DOCKER_PASSWORD=$(vault read -address "${VAULT_ADDR}" -field ${DOCKER_PASS_KEY} ${VAULT_DIR})
echo "Done!"
echo

echo "Logging into Docker as '$DOCKER_USER'..."
docker login -u "${DOCKER_USER}" -p ${DOCKER_PASSWORD} docker.elastic.co
echo "Done!"
echo
echo "Pushing the image to docker.elastic.co"
make docker-push
