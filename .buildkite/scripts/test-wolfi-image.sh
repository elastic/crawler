#!/bin/bash

set -euxo pipefail

# Simple tests to verify Wolfi image functionality
echo "Testing JRuby installation..."
docker run --rm crawler-ci-wolfi ruby --version | grep -E "jruby\s9\.4\..*"

echo "Testing crawler installation..."
docker run --rm crawler-ci-wolfi jruby bin/crawler version

# Crawl a page so runtime gaps in the jlink JDK fail here, not after publishing
echo "Testing crawl execution..."
SMOKE_DIR="$(mktemp -d)"
trap 'rm -rf "$SMOKE_DIR"' EXIT
cat > "$SMOKE_DIR/crawl.yml" <<'EOF'
output_sink: console
domains:
  - url: https://example.com
EOF
# The container runs as uid 1000 and needs to read the mounted config
chmod 755 "$SMOKE_DIR"
chmod 644 "$SMOKE_DIR/crawl.yml"

docker run --rm -v "$SMOKE_DIR:/smoke:ro" crawler-ci-wolfi \
  jruby bin/crawler crawl /smoke/crawl.yml | grep -F "Finished a crawl. Result: success"

echo "Wolfi image tests passed!"
