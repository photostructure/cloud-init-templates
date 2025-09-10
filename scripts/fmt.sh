#!/bin/bash
set -euo pipefail

# Get the project root directory (where this script is located)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

find . -name "*.yaml" -o -name "*.yml" | xargs yamlfmt

# Format shell scripts:
find . -name "*.sh" | xargs shfmt -w -i 2

# Format JavaScript, JSON, and Markdown files. Only emit warnings and errors.
prettier --log-level warn --write .
