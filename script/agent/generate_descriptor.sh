#!/usr/bin/env bash
#
# Regenerates lib/crawler/agent/proto/elastic-agent-client.textproto from the protocol
# definitions published in https://github.com/elastic/elastic-agent-client.
#
# Requires `protoc` on the PATH and the project's bundle (`make install`).
# Usage: script/agent/generate_descriptor.sh [git ref, defaults to main]

set -euo pipefail

REF="${1:-main}"
BASE_URL="https://raw.githubusercontent.com/elastic/elastic-agent-client/${REF}"
PROTO_FILES=(elastic-agent-client.proto elastic-agent-client-deprecated.proto)

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUTPUT="${ROOT}/lib/crawler/agent/proto/elastic-agent-client.textproto"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

for file in "${PROTO_FILES[@]}"; do
  curl -fsSL -o "${WORK_DIR}/${file}" "${BASE_URL}/${file}"
done

protoc -I "${WORK_DIR}" --descriptor_set_out="${WORK_DIR}/descriptors.bin" \
  "${WORK_DIR}/elastic-agent-client.proto" "${WORK_DIR}/elastic-agent-client-deprecated.proto"

cd "${ROOT}"
bundle exec ruby -e '
  require "jar_dependencies"
  Jars.require_jars_lock!
  set = Java::ComGoogleProtobuf::DescriptorProtos::FileDescriptorSet.parseFrom(File.binread(ARGV[0]).to_java_bytes)
  File.write(ARGV[1], Java::ComGoogleProtobuf::TextFormat.printer.printToString(set))
' "${WORK_DIR}/descriptors.bin" "${OUTPUT}"

echo "Wrote ${OUTPUT} (elastic-agent-client@${REF})"
