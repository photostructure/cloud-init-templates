#!/bin/bash
# Simple test runner for cloud-init base templates

set -euo pipefail

for test_file in tests/test-*.sh; do
  test_name=$(basename "$test_file" .sh | sed 's/test-//')
  if ! bash "$test_file"; then
    exit_code=$?
    echo "❌ $test_file failed with exit code $exit_code"
    exit $exit_code
  fi
done
