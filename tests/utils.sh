#!/bin/bash
# Shared utilities for cloud-init-templates test suite
# Source this file in test scripts: source "$(dirname "$0")/utils.sh"

set -euo pipefail

# =============================================================================
# SETUP AND INITIALIZATION
# =============================================================================

# Initialize common variables and colors
init_test_env() {
  # Find project root (where this script is located)
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
  PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

  # Colors for output
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  NC='\033[0m' # No Color

  # Export for use in calling scripts
  export SCRIPT_DIR PROJECT_ROOT RED GREEN YELLOW BLUE NC
}

# =============================================================================
# CLOUD-INIT SYNTAX VALIDATION
# =============================================================================

# Test cloud-init syntax validation with #include directive handling
test_cloud_init_syntax() {
  local cloud_init_file="$1"
  local test_name="${2:-Cloud-Init Syntax Validation}"

  echo -e "${YELLOW}$test_name${NC}"

  if ! command -v cloud-init >/dev/null 2>&1; then
    echo -e "${YELLOW}? cloud-init not available, skipping validation${NC}"
    return 0
  fi

  if cloud-init schema --config-file "$cloud_init_file" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Cloud-init syntax is valid"
    return 0
  else
    # Check if it's just the #include directive issue
    if grep -q "^#include" "$cloud_init_file" && grep -q "expected '<document start>'" <(cloud-init schema --config-file "$cloud_init_file" 2>&1); then
      echo -e "${YELLOW}?${NC} Cloud-init contains include directives (valid cloud-config feature)"
      return 0
    else
      echo -e "${RED}✗${NC} Cloud-init syntax errors:"
      cloud-init schema --config-file "$cloud_init_file" 2>&1 | sed 's/^/  /'
      return 1
    fi
  fi
}

# =============================================================================
# CONFIGURATION VALIDATION HELPERS
# =============================================================================

# Check if a configuration setting exists in a file
check_config() {
  local file="$1"
  local pattern="$2"
  local description="$3"
  local required="${4:-true}"

  if grep -q "$pattern" "$file"; then
    echo -e "${GREEN}✓${NC} $description"
    return 0
  else
    if [ "$required" = "true" ]; then
      echo -e "${RED}✗${NC} $description"
      return 1
    else
      echo -e "${YELLOW}?${NC} $description"
      return 0
    fi
  fi
}

# =============================================================================
# YAML VALIDATION HELPERS
# =============================================================================

# Validate YAML syntax using available tools
validate_yaml_syntax() {
  local yaml_file="$1"
  local skip_includes="${2:-true}"

  # Skip files with #include if requested
  if [ "$skip_includes" = "true" ] && [ -f "$yaml_file" ] && grep -q "^#include" "$yaml_file"; then
    return 0
  fi

  if [ ! -f "$yaml_file" ]; then
    return 1
  fi

  # Try yq first, then python as fallback
  if command -v yq >/dev/null 2>&1; then
    yq '.' "$yaml_file" >/dev/null 2>&1
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c "import yaml; yaml.safe_load(open('$yaml_file'))" 2>/dev/null
  else
    # No YAML validator available, assume valid
    return 0
  fi
}

# =============================================================================
# TEST RESULT MANAGEMENT
# =============================================================================

# Initialize test counters
init_test_counters() {
  FAILED_TESTS=0
  WARNING_TESTS=0
  TOTAL_TESTS=0
  export FAILED_TESTS WARNING_TESTS TOTAL_TESTS
}

# Run a test function and track results
run_test() {
  local test_func="$1"
  local test_name="$2"

  TOTAL_TESTS=$((TOTAL_TESTS + 1))

  if $test_func; then
    return 0
  else
    FAILED_TESTS=$((FAILED_TESTS + 1))
    return 1
  fi
}

# Display final test results
show_test_results() {
  local test_type="${1:-Tests}"
  if [ $FAILED_TESTS -ne 0 ]; then
    echo -e "${RED}❌ $FAILED_TESTS test(s) failed!${NC}"
    return 1
  elif [ $WARNING_TESTS -ne 0 ]; then
    echo -e "${YELLOW}✅ All $test_type passed with $WARNING_TESTS warning(s).${NC}"
    return 0
  fi
}

# =============================================================================
# SECURITY VALIDATION HELPERS
# =============================================================================

# SSH configuration validation
validate_ssh_setting() {
  local config_file="$1"
  local setting="$2"
  local expected="$3"
  local description="$4"

  if grep -q "$setting.*$expected" "$config_file"; then
    echo -e "${GREEN}✓${NC} $description"
    return 0
  else
    echo -e "${RED}✗${NC} $description"
    return 1
  fi
}

# =============================================================================
# FILE AND DIRECTORY UTILITIES
# =============================================================================

# Create temporary test directory
create_temp_dir() {
  local temp_dir=$(mktemp -d)
  echo "$temp_dir"
}

# Cleanup temporary directory
cleanup_temp_dir() {
  local temp_dir="$1"
  [ -n "$temp_dir" ] && [ -d "$temp_dir" ] && rm -rf "$temp_dir"
}

# =============================================================================
# INITIALIZATION
# =============================================================================

init_test_env
init_test_counters
