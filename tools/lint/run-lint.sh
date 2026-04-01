#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== Running markdownlint (Docker) ==="
docker build -t md-lint "$SCRIPT_DIR" > /dev/null 2>&1
docker run --rm -v "$PROJECT_ROOT:/docs" md-lint "docs/**/*.md"

echo "=== Lint passed ==="
