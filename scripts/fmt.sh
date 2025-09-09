#!/bin/bash
set -euo pipefail

# We can't directly use yamlfmt because cloud-init _isn't yaml_
find . -name "*.yaml" -o -name "*.yml" | grep -v node_modules | xargs uv run ./scripts/fmt-cloud-init-yaml.py

# Format shell scripts:
find . -name "*.sh" | grep -v node_modules | xargs shfmt -w -i 2

# Format JavaScript, JSON, and Markdown files. Only emit warnings and errors.
prettier --log-level warn --write .
