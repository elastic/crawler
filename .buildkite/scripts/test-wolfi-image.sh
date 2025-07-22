#!/bin/bash

set -euxo pipefail

# Simple tests to verify Wolfi image functionality
echo "Testing JRuby installation..."
docker run --rm crawler-ci-wolfi ruby --version | grep -E "jruby\s9\.4\..*"

echo "Testing crawler installation..."
docker run --rm crawler-ci-wolfi jruby bin/crawler version

echo "Wolfi image tests passed!"
