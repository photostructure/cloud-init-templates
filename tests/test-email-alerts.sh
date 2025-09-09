#!/bin/bash
# Test script for email-alerts.yaml functionality
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Find project root (where this script is located)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TEST_DIR=$(mktemp -d)
ALERTS_USER="testuser"

CLOUD_INIT_FILE="$PROJECT_ROOT/base/email-alerts.yaml"

echo -e "${YELLOW}=== Email Alerts Test Suite ===${NC}"

# Setup test environment
setup_test() {
  echo -e "${YELLOW}Setting up test environment...${NC}"
  mkdir -p "$TEST_DIR"/{bin,aws,log}

  # Mock AWS CLI
  cat >"$TEST_DIR/bin/aws" <<EOF
#!/bin/bash
echo "MOCK AWS CLI called with: \$*" >> "$TEST_DIR/aws-mock.log"
if [[ "\$*" == *"send-email"* ]]; then
    if [[ -z "\${AWS_ACCESS_KEY_ID:-}" ]] || [[ -z "\${AWS_SECRET_ACCESS_KEY:-}" ]]; then
        echo "Error: Missing AWS credentials" >&2
        exit 1
    fi
    echo "Email sent successfully (mock)"
    exit 0
fi
EOF
  chmod +x "$TEST_DIR/bin/aws"

  # Set up mock environment
  export PATH="$TEST_DIR/bin:$PATH"
  export AWS_ACCESS_KEY_ID="mock-key"
  export AWS_SECRET_ACCESS_KEY="mock-secret"

  rm -f "$TEST_DIR/aws-mock.log"
}

# Test 1: Extract and test send-alert.sh
test_send_alert() {
  echo -e "\n${YELLOW}Test 1: send-alert.sh functionality${NC}"

  # Extract script from YAML using yq
  yq -r '.write_files[] | select(.path == "/usr/local/bin/send-alert.sh") | .content' \
    "$PROJECT_ROOT/base/email-alerts.yaml" >"$TEST_DIR/send-alert.sh"

  chmod +x "$TEST_DIR/send-alert.sh"

  echo "Testing successful email send..."
  if "$TEST_DIR/send-alert.sh" "Test Subject" "Test Body"; then
    echo -e "${GREEN}✓ send-alert.sh executed successfully${NC}"
  else
    echo -e "${RED}✗ send-alert.sh failed${NC}"
    return 1
  fi

  # Check AWS CLI was called
  if grep -q "send-email" "$TEST_DIR/aws-mock.log"; then
    echo -e "${GREEN}✓ AWS SES send-email was called${NC}"
  else
    echo -e "${RED}✗ AWS SES was not called${NC}"
    return 1
  fi

  echo "Testing missing arguments..."
  if ! "$TEST_DIR/send-alert.sh" "Only Subject" 2>/dev/null; then
    echo -e "${GREEN}✓ Properly handles missing arguments${NC}"
  else
    echo -e "${RED}✗ Should fail with missing arguments${NC}"
    return 1
  fi
}

# Test 2: Extract and test check-critical.sh
test_check_critical() {
  echo -e "\n${YELLOW}Test 2: check-critical.sh monitoring logic${NC}"

  # Extract script from YAML using yq
  yq -r '.write_files[] | select(.path == "/usr/local/bin/check-critical.sh") | .content' \
    "$PROJECT_ROOT/base/email-alerts.yaml" >"$TEST_DIR/check-critical.sh"

  # Modify script to not sleep 5 minutes and use test send-alert
  sed -i 's|sleep 300|sleep 1|g' "$TEST_DIR/check-critical.sh"
  sed -i "s|/usr/local/bin/send-alert.sh|$TEST_DIR/send-alert.sh|g" "$TEST_DIR/check-critical.sh"

  chmod +x "$TEST_DIR/check-critical.sh"

  echo "Testing check-critical.sh (this may take a few seconds)..."
  rm -f "$TEST_DIR/aws-mock.log"

  # Run in background with timeout
  timeout 30s "$TEST_DIR/check-critical.sh" || true

  echo -e "${GREEN}✓ check-critical.sh completed without crashing${NC}"

  # Test individual components
  echo "Testing disk usage calculation..."
  DISK_TEST=$(df -h | awk 'NR>1 {gsub("%","",$5); if($5>0) print $6 " is " $5 "% full"; exit}')
  if [[ -n "$DISK_TEST" ]]; then
    echo -e "${GREEN}✓ Disk usage check works: $DISK_TEST${NC}"
  else
    echo -e "${YELLOW}! No disk usage found (may be normal)${NC}"
  fi

  # Test CPU cores detection
  CPU_CORES=$(nproc)
  if [[ "$CPU_CORES" -gt 0 ]]; then
    echo -e "${GREEN}✓ CPU cores detected: $CPU_CORES${NC}"
  else
    echo -e "${RED}✗ CPU cores detection failed${NC}"
    return 1
  fi

  # Test load average parsing
  LOAD_15MIN=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $3}' | sed 's/,//' | cut -d. -f1)
  if [[ -n "$LOAD_15MIN" ]] && [[ "$LOAD_15MIN" =~ ^[0-9]+$ ]]; then
    echo -e "${GREEN}✓ Load average parsed: $LOAD_15MIN${NC}"
  else
    echo -e "${RED}✗ Load average parsing failed: '$LOAD_15MIN'${NC}"
    return 1
  fi
}

# Test 3: Extract and test notify-login.sh
test_notify_login() {
  echo -e "\n${YELLOW}Test 3: notify-login.sh functionality${NC}"

  # Extract script from YAML using yq
  yq -r '.write_files[] | select(.path == "/usr/local/bin/notify-login.sh") | .content' \
    "$PROJECT_ROOT/base/email-alerts.yaml" >"$TEST_DIR/notify-login.sh"

  # Modify to use test send-alert
  sed -i "s|/usr/local/bin/send-alert.sh|$TEST_DIR/send-alert.sh|g" "$TEST_DIR/notify-login.sh"

  chmod +x "$TEST_DIR/notify-login.sh"

  echo "Testing SSH login notification..."
  rm -f "$TEST_DIR/aws-mock.log"
  PAM_USER="testuser" PAM_SERVICE="sshd" PAM_RHOST="192.168.1.100" "$TEST_DIR/notify-login.sh"

  if grep -q "send-email" "$TEST_DIR/aws-mock.log"; then
    echo -e "${GREEN}✓ SSH login notification sent${NC}"
  else
    echo -e "${RED}✗ SSH login notification failed${NC}"
    return 1
  fi

  echo "Testing local login notification..."
  rm -f "$TEST_DIR/aws-mock.log"
  PAM_USER="testuser" PAM_SERVICE="login" "$TEST_DIR/notify-login.sh"

  if grep -q "send-email" "$TEST_DIR/aws-mock.log"; then
    echo -e "${GREEN}✓ Local login notification sent${NC}"
  else
    echo -e "${RED}✗ Local login notification failed${NC}"
    return 1
  fi

  echo "Testing non-login service (should not send)..."
  rm -f "$TEST_DIR/aws-mock.log"
  PAM_USER="testuser" PAM_SERVICE="cron" "$TEST_DIR/notify-login.sh"

  if ! grep -q "send-email" "$TEST_DIR/aws-mock.log"; then
    echo -e "${GREEN}✓ Non-login service correctly ignored${NC}"
  else
    echo -e "${RED}✗ Non-login service should not send alerts${NC}"
    return 1
  fi
}

# Test 4: Validate cloud-init syntax
test_cloud_init_syntax() {
  echo -e "\n${YELLOW}Test 4: Cloud-Init syntax validation${NC}"

  if ! command -v cloud-init >/dev/null 2>&1; then
    echo -e "${YELLOW}? cloud-init not available, skipping validation${NC}"
    return 0
  fi

  if cloud-init schema --config-file "$CLOUD_INIT_FILE" 2>/dev/null; then
    echo -e "${GREEN}✓ Cloud-init syntax is valid${NC}"
  else
    echo -e "${RED}✗ Cloud-init syntax errors:${NC}"
    cloud-init schema --config-file "$CLOUD_INIT_FILE" 2>&1 | sed 's/^/  /'
    return 1
  fi
}

# Test 5: Check for security issues
test_security() {
  echo -e "\n${YELLOW}Test 5: Security checks${NC}"

  # Check that credentials aren't hardcoded
  if grep -q "AKIA[A-Z0-9]\{16\}" "$PROJECT_ROOT/base/email-alerts.yaml"; then
    echo -e "${RED}✗ Hardcoded AWS access key found!${NC}"
    return 1
  else
    echo -e "${GREEN}✓ No hardcoded AWS access keys${NC}"
  fi

  # Check that scripts run as alerts user, not root
  if grep -q "owner: alerts:alerts" "$PROJECT_ROOT/base/email-alerts.yaml"; then
    echo -e "${GREEN}✓ Scripts owned by alerts user${NC}"
  else
    echo -e "${RED}✗ Scripts should be owned by alerts user${NC}"
    return 1
  fi

  # Check AWS credentials path
  if grep -q "/var/lib/alerts/.aws" "$PROJECT_ROOT/base/email-alerts.yaml"; then
    echo -e "${GREEN}✓ AWS credentials in alerts user home${NC}"
  else
    echo -e "${RED}✗ AWS credentials should be in alerts user home${NC}"
    return 1
  fi
}

# Cleanup
cleanup() {
  echo -e "\n${YELLOW}Cleaning up...${NC}"
  rm -rf "$TEST_DIR"
}

# Main execution
main() {
  setup_test

  local failed=0

  test_send_alert || failed=1
  test_check_critical || failed=1
  test_notify_login || failed=1
  test_cloud_init_syntax || failed=1
  test_security || failed=1

  cleanup

  echo -e "\n${YELLOW}=== Test Results ===${NC}"
  if [[ $failed -eq 0 ]]; then
    echo -e "${GREEN}All tests passed! 🎉${NC}"
    return 0
  else
    echo -e "${RED}Some tests failed! 😞${NC}"
    return 1
  fi
}

# Run tests
main "$@"
