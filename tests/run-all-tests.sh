#!/bin/bash
# Simple test runner for cloud-init base templates

set -euo pipefail

echo "=== Cloud-Init Templates Test Suite ==="

for test_file in tests/test-*.sh; do
  test_name=$(basename "$test_file" .sh | sed 's/test-//')
  if ! bash "$test_file"; then
    echo "❌ FAILED: $test_file"
    exit 1
  fi
done

echo "🎉 ALL TESTS PASSED!"
