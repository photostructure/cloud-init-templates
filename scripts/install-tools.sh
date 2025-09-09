#!/bin/bash
set -euo pipefail

# Install uv if not present. Will fail if curl is not installed
command -v uv >/dev/null 2>&1 || curl -LsSf https://astral.sh/uv/install.sh | sh

# Install Go tools. Will fail fast if Go not installed
command -v yamlfmt >/dev/null 2>&1 || go install github.com/google/yamlfmt/cmd/yamlfmt@latest
command -v shfmt >/dev/null 2>&1 || go install mvdan.cc/sh/v3/cmd/shfmt@latest

# Install prettier if not present. Will fail if npm is not installed
command -v prettier >/dev/null 2>&1 || npm install -g prettier
