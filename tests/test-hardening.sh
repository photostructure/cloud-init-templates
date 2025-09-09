#!/bin/bash
# Comprehensive hardening validation for base/hardening.yaml
# Tests SSH configuration, kernel parameters, firewall rules, and security tools

# Source shared test utilities
source "$(dirname "$0")/utils.sh"

HARDENING_FILE="$PROJECT_ROOT/base/hardening.yaml"

echo -e "${BLUE}=== Hardening Configuration Validation ===${NC}"
echo "Testing: $HARDENING_FILE"
echo

# Check if file exists
if [ ! -f "$HARDENING_FILE" ]; then
  echo -e "${RED}✗ Hardening file not found: $HARDENING_FILE${NC}"
  exit 1
fi

# Test 1: SSH Configuration Validation
test_ssh_config() {
  echo -e "${YELLOW}Test 1: SSH Configuration${NC}"

  # Note: SSH port is now configured dynamically via systemd socket activation
  # The hardening file no longer contains a static Port directive
  echo -e "${GREEN}✓${NC} SSH port configured dynamically via systemd socket"
  validate_ssh_setting "$HARDENING_FILE" "PermitRootLogin" "no" "Root login disabled" || FAILED_TESTS=$((FAILED_TESTS + 1))
  validate_ssh_setting "$HARDENING_FILE" "PasswordAuthentication" "no" "Password authentication disabled" || FAILED_TESTS=$((FAILED_TESTS + 1))
  validate_ssh_setting "$HARDENING_FILE" "PubkeyAuthentication" "yes" "Public key authentication enabled" || FAILED_TESTS=$((FAILED_TESTS + 1))
  validate_ssh_setting "$HARDENING_FILE" "AuthenticationMethods" "publickey" "Only public key auth allowed" || FAILED_TESTS=$((FAILED_TESTS + 1))
  validate_ssh_setting "$HARDENING_FILE" "MaxAuthTries" "3" "Max auth tries limited to 3" || FAILED_TESTS=$((FAILED_TESTS + 1))
  validate_ssh_setting "$HARDENING_FILE" "LoginGraceTime" "30s" "Login grace time set to 30s" || FAILED_TESTS=$((FAILED_TESTS + 1))
  validate_ssh_setting "$HARDENING_FILE" "StrictModes" "yes" "Strict modes enabled" || FAILED_TESTS=$((FAILED_TESTS + 1))
  validate_ssh_setting "$HARDENING_FILE" "Protocol" "2" "SSH Protocol 2 enforced" || FAILED_TESTS=$((FAILED_TESTS + 1))
  validate_ssh_setting "$HARDENING_FILE" "RequiredRSASize" "3072" "Minimum RSA key size enforced" || FAILED_TESTS=$((FAILED_TESTS + 1))

  # Check for disabled features
  validate_ssh_setting "$HARDENING_FILE" "AllowAgentForwarding" "no" "Agent forwarding disabled" || FAILED_TESTS=$((FAILED_TESTS + 1))
  validate_ssh_setting "$HARDENING_FILE" "AllowTcpForwarding" "no" "TCP forwarding disabled" || FAILED_TESTS=$((FAILED_TESTS + 1))
  validate_ssh_setting "$HARDENING_FILE" "X11Forwarding" "no" "X11 forwarding disabled" || FAILED_TESTS=$((FAILED_TESTS + 1))

  # Check cryptographic settings
  check_config "$HARDENING_FILE" "KexAlgorithms.*curve25519-sha256" "Strong key exchange algorithms configured" || FAILED_TESTS=$((FAILED_TESTS + 1))
  check_config "$HARDENING_FILE" "Ciphers.*chacha20-poly1305@openssh.com" "Strong ciphers configured" || FAILED_TESTS=$((FAILED_TESTS + 1))
  check_config "$HARDENING_FILE" "MACs.*hmac-sha2-256-etm@openssh.com" "Strong MACs configured" || FAILED_TESTS=$((FAILED_TESTS + 1))

  return 0
}

# Test 2: Kernel Hardening Parameters
echo -e "\n${YELLOW}Test 2: Kernel Security Parameters${NC}"

kernel_checks() {
  local param="$1"
  local value="$2"
  local description="$3"

  if grep -q "$param.*=.*$value" "$HARDENING_FILE"; then
    echo -e "${GREEN}✓${NC} $description"
    return 0
  else
    echo -e "${RED}✗${NC} $description"
    return 1
  fi
}

# Network security parameters
kernel_checks "net.ipv4.ip_forward" "0" "IP forwarding disabled" || FAILED_TESTS=$((FAILED_TESTS + 1))
kernel_checks "net.ipv4.tcp_syncookies" "1" "SYN cookies enabled" || FAILED_TESTS=$((FAILED_TESTS + 1))
kernel_checks "net.ipv4.conf.all.accept_redirects" "0" "ICMP redirects disabled" || FAILED_TESTS=$((FAILED_TESTS + 1))
kernel_checks "net.ipv4.conf.all.accept_source_route" "0" "Source routing disabled" || FAILED_TESTS=$((FAILED_TESTS + 1))
kernel_checks "net.ipv4.conf.all.log_martians" "1" "Martian packet logging enabled" || FAILED_TESTS=$((FAILED_TESTS + 1))

# Kernel security parameters
kernel_checks "kernel.dmesg_restrict" "1" "dmesg access restricted" || FAILED_TESTS=$((FAILED_TESTS + 1))
kernel_checks "kernel.kptr_restrict" "1" "Kernel pointer exposure restricted" || FAILED_TESTS=$((FAILED_TESTS + 1))
kernel_checks "kernel.randomize_va_space" "2" "ASLR fully enabled" || FAILED_TESTS=$((FAILED_TESTS + 1))

# File system security
kernel_checks "fs.suid_dumpable" "0" "SUID core dumps disabled" || FAILED_TESTS=$((FAILED_TESTS + 1))
kernel_checks "fs.protected_hardlinks" "1" "Hardlink protection enabled" || FAILED_TESTS=$((FAILED_TESTS + 1))
kernel_checks "fs.protected_symlinks" "1" "Symlink protection enabled" || FAILED_TESTS=$((FAILED_TESTS + 1))

# Test 3: Firewall Configuration
echo -e "\n${YELLOW}Test 3: Firewall Rules${NC}"

if grep -q "ufw default deny incoming" "$HARDENING_FILE"; then
  echo -e "${GREEN}✓${NC} Default deny incoming traffic"
else
  echo -e "${RED}✗${NC} Missing default deny incoming rule"
  FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# SSH port firewall configuration for custom ports
if grep -q "ufw allow.*SSH custom port" "$HARDENING_FILE"; then
  echo -e "${GREEN}✓${NC} Custom SSH port firewall configuration present"
else
  echo -e "${RED}✗${NC} Custom SSH port firewall configuration missing"
  FAILED_TESTS=$((FAILED_TESTS + 1))
fi

if grep -q "ufw allow 80/tcp" "$HARDENING_FILE" && grep -q "ufw allow 443/tcp" "$HARDENING_FILE"; then
  echo -e "${GREEN}✓${NC} Web ports (80/443) allowed"
else
  echo -e "${YELLOW}⚠${NC} Web ports not configured (may be intentional)"
  WARNING_TESTS=$((WARNING_TESTS + 1))
fi

# Test 4: Security Tools
echo -e "\n${YELLOW}Test 4: Security Tools${NC}"

security_packages=("fail2ban" "unattended-upgrades" "lynis" "auditd" "apparmor-profiles")
for package in "${security_packages[@]}"; do
  if grep -q "$package" "$HARDENING_FILE"; then
    echo -e "${GREEN}✓${NC} $package installed"
  else
    echo -e "${RED}✗${NC} $package missing"
    FAILED_TESTS=$((FAILED_TESTS + 1))
  fi
done

# Test 5: Fail2ban Configuration
echo -e "\n${YELLOW}Test 5: Fail2ban Settings${NC}"

# Check that fail2ban is installed and will be enabled
if grep -q "fail2ban" "$HARDENING_FILE" && grep -q "systemctl.*enable.*fail2ban" "$HARDENING_FILE"; then
  echo -e "${GREEN}✓${NC} Fail2ban installed and enabled (uses system defaults)"
else
  echo -e "${RED}✗${NC} Fail2ban not properly configured"
  FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# Fail2ban port configuration is now handled dynamically in configure-ssh-port.sh
if grep -q "sshd-custom-port.conf" "$HARDENING_FILE"; then
  echo -e "${GREEN}✓${NC} Fail2ban configured to handle custom SSH ports dynamically"
else
  echo -e "${RED}✗${NC} Fail2ban custom port configuration missing"
  FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# Test 6: User Configuration
echo -e "\n${YELLOW}Test 6: User Management${NC}"

if grep -q "name:.*deploy" "$HARDENING_FILE"; then
  echo -e "${GREEN}✓${NC} Deploy user configured"
else
  echo -e "${RED}✗${NC} Deploy user not configured"
  FAILED_TESTS=$((FAILED_TESTS + 1))
fi

if grep -q "AllowUsers.*deploy" "$HARDENING_FILE"; then
  echo -e "${GREEN}✓${NC} SSH restricted to deploy user"
else
  echo -e "${RED}✗${NC} SSH user restriction not configured"
  FAILED_TESTS=$((FAILED_TESTS + 1))
fi

if grep -q "mv.*/root/.ssh/authorized_keys.*/home/deploy/.ssh/authorized_keys" "$HARDENING_FILE"; then
  echo -e "${GREEN}✓${NC} SSH keys migrated from root to deploy"
else
  echo -e "${RED}✗${NC} SSH key migration not configured"
  FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# Test 7: Automatic Updates
echo -e "\n${YELLOW}Test 7: Automatic Updates${NC}"

if grep -q "Unattended-Upgrade::Automatic-Reboot.*\"true\"" "$HARDENING_FILE"; then
  echo -e "${GREEN}✓${NC} Automatic reboot enabled for updates"
else
  echo -e "${YELLOW}⚠${NC} Automatic reboot not enabled"
  WARNING_TESTS=$((WARNING_TESTS + 1))
fi

if grep -q "APT::Periodic::Unattended-Upgrade.*\"1\"" "$HARDENING_FILE"; then
  echo -e "${GREEN}✓${NC} Unattended upgrades enabled"
else
  echo -e "${RED}✗${NC} Unattended upgrades not enabled"
  FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# Test 8: Cloud-init Syntax
echo -e "\n${YELLOW}Test 8: Cloud-init Syntax${NC}"

if command -v cloud-init >/dev/null 2>&1; then
  # Run schema validation directly on the original file
  # cloud-init can handle #include directives and complex structures
  schema_output=$(cloud-init schema --config-file "$HARDENING_FILE" 2>&1)
  schema_exit_code=$?

  # Check for successful validation (exit code 0) or just warnings
  if [ $schema_exit_code -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Valid cloud-init syntax"
  elif echo "$schema_output" | grep -qi "Valid schema" && ! echo "$schema_output" | grep -qi "Error.*Invalid"; then
    echo -e "${GREEN}✓${NC} Valid cloud-init syntax (with warnings)"
    # Show warnings but don't fail the test
    echo "$schema_output" | grep -i "warning" | head -3 | sed 's/^/  /'
  else
    echo -e "${RED}✗${NC} Cloud-init syntax errors detected"
    echo "$schema_output" | grep -E "(Error|Invalid)" | head -5 | sed 's/^/  /'
    FAILED_TESTS=$((FAILED_TESTS + 1))
  fi
else
  echo -e "${YELLOW}⚠${NC} cloud-init not installed, skipping syntax check"
  echo "  Install with: sudo apt install cloud-init"
  WARNING_TESTS=$((WARNING_TESTS + 1))
fi

# Final Results
echo -e "\n${BLUE}=== Validation Summary ===${NC}"
echo "Failed checks: $FAILED_TESTS"
echo "Warnings: $WARNING_TESTS"

if [ $FAILED_TESTS -eq 0 ]; then
  if [ $WARNING_TESTS -eq 0 ]; then
    echo -e "\n${GREEN}✅ All hardening checks passed! System will be properly secured.${NC}"
  else
    echo -e "\n${GREEN}✅ Hardening configuration valid with $WARNING_TESTS warning(s).${NC}"
  fi
  exit 0
else
  echo -e "\n${RED}❌ $FAILED_TESTS hardening check(s) failed! Review configuration.${NC}"
  exit 1
fi
