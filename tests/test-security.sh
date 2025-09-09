#!/bin/bash

# Source shared test utilities
source "$(dirname "$0")/utils.sh"

echo -e "${BLUE}=== Security Checks ===${NC}"

# Test YAML syntax validation
test_yaml_syntax() {
  echo -e "${YELLOW}Checking YAML syntax...${NC}"
  local yaml_failed=0

  # Check base directory YAML files
  for yaml_file in "$PROJECT_ROOT/base"/*.yaml "$PROJECT_ROOT/base"/*.yml; do
    [ ! -f "$yaml_file" ] && continue
    if ! validate_yaml_syntax "$yaml_file" "false"; then
      echo -e "${RED}✗ YAML syntax error in $yaml_file${NC}"
      yaml_failed=$((yaml_failed + 1))
    fi
  done

  # Check servers directory YAML files (skip files with #include)
  for yaml_file in "$PROJECT_ROOT/servers"/*.yaml "$PROJECT_ROOT/servers"/*.yml; do
    [ ! -f "$yaml_file" ] && continue
    if ! validate_yaml_syntax "$yaml_file" "true"; then
      echo -e "${RED}✗ YAML syntax error in $yaml_file${NC}"
      yaml_failed=$((yaml_failed + 1))
    fi
  done

  if [ $yaml_failed -eq 0 ]; then
    echo -e "${GREEN}✓ All YAML files have valid syntax${NC}"
    return 0
  else
    echo -e "${RED}✗ $yaml_failed YAML file(s) have syntax errors${NC}"
    return 1
  fi
}

# Test GitLeaks
test_gitleaks() {
  echo -e "${YELLOW}Running GitLeaks scan...${NC}"
  if docker run --rm -v "$PROJECT_ROOT:/path" zricethezav/gitleaks:latest detect --source="/path" --no-git --config="/path/.gitleaks.toml" --exit-code 1 >/dev/null 2>&1; then
    echo -e "${GREEN}✓ GitLeaks: No secrets detected${NC}"
    return 0
  else
    echo -e "${RED}✗ GitLeaks: Secrets detected!${NC}"
    return 1
  fi
}

# Test TruffleHog
test_trufflehog() {
  echo -e "${YELLOW}Running TruffleHog scan...${NC}"
  if docker run --rm -v "$PROJECT_ROOT:/pwd" trufflesecurity/trufflehog:latest filesystem /pwd --no-verification >/dev/null 2>&1; then
    echo -e "${GREEN}✓ TruffleHog: No secrets detected${NC}"
    return 0
  else
    echo -e "${RED}✗ TruffleHog: Secrets detected!${NC}"
    return 1
  fi
}

# Main execution
main() {
  # Check if Docker is available (required)
  echo -e "${YELLOW}Checking for Docker...${NC}"
  if ! command -v docker >/dev/null 2>&1; then
    echo -e "${RED}✗ Docker is required for secret scanning${NC}"
    echo -e "${BLUE}Install Docker: apt install docker.io  OR  brew install docker${NC}"
    exit 1
  fi
  echo -e "${GREEN}✓ Docker found${NC}"

  run_test test_gitleaks "GitLeaks scan" || true
  run_test test_trufflehog "TruffleHog scan" || true
  run_test test_yaml_syntax "YAML Syntax" || true

  if show_test_results "security checks"; then
    return 0
  else
    return 1
  fi
}

# Run main
main "$@"
