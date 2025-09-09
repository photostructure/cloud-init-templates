# Debugging Cloud-init - TL;DR

## Essential Commands

### Status and Wait

```bash
# Check current status
cloud-init status

# Wait for cloud-init to complete
cloud-init status --wait

# Detailed status with timing
cloud-init status --long

# Check if cloud-init has errors
cloud-init status --wait && echo "Success" || echo "Failed"
```

**Status outputs**:

- `status: running` - Cloud-init is still executing
- `status: done` - Completed successfully
- `status: error` - Failed with errors
- `status: disabled` - Cloud-init is disabled

### Query Instance Data

```bash
# View all instance data
cloud-init query --all

# Specific values
cloud-init query v1.instance_id
cloud-init query v1.cloud_name
cloud-init query v1.region

# User data (root only)
sudo cloud-init query userdata

# Raw datasource metadata
cloud-init query ds.meta_data
```

### Performance Analysis

```bash
# Boot timing analysis
cloud-init analyze show

# Most expensive operations
cloud-init analyze blame

# Boot stages timing
cloud-init analyze boot

# Machine-readable JSON dump
cloud-init analyze dump
```

## Key Log Files

### Primary Logs

| File                             | Contents                          |
| -------------------------------- | --------------------------------- |
| `/var/log/cloud-init.log`        | Main cloud-init execution log     |
| `/var/log/cloud-init-output.log` | Output from user commands/scripts |
| `/run/cloud-init/result.json`    | Final execution results           |
| `/run/cloud-init/status.json`    | Current status information        |

### Debug Logs

```bash
# Enable debug logging (before cloud-init runs)
echo 'debug: true' | sudo tee /etc/cloud/cloud.cfg.d/05_logging.cfg

# View debug output
sudo tail -f /var/log/cloud-init.log
```

### Specific Checks

```bash
# Check for errors
grep -i "error\|fail\|traceback" /var/log/cloud-init.log

# Check datasource detection
grep -i "datasource" /var/log/cloud-init.log

# Check user-data processing
grep -i "user.data" /var/log/cloud-init.log

# Check module execution
grep "cc_" /var/log/cloud-init.log
```

## Configuration Validation

### Schema Validation

```bash
# Validate cloud-config file
cloud-init schema --config-file myconfig.yaml

# Check for schema errors
cloud-init schema --config-file myconfig.yaml --annotate
```

### Template Rendering

```bash
# Test Jinja template rendering
cloud-init devel render --user-data template.yaml

# Preview what would happen without executing
cloud-init devel render --user-data config.yaml --instance-data /run/cloud-init/instance-data.json
```

## Testing and Development

### Clean and Re-run

```bash
# Clean cloud-init state (for testing)
sudo cloud-init clean

# Clean and reboot
sudo cloud-init clean --reboot

# Clean with additional options
sudo cloud-init clean --logs --configs all --seed
```

### Single Module Testing

```bash
# Run specific module
sudo cloud-init single --name cc_runcmd --frequency once

# Run with debug output
sudo cloud-init --debug single --name cc_write_files

# List available modules
grep -r "cc_" /etc/cloud/cloud.cfg /etc/cloud/cloud.cfg.d/
```

### Manual Stage Execution

```bash
# Run specific stages manually (for debugging)
sudo cloud-init init --local
sudo cloud-init init
sudo cloud-init modules --mode config
sudo cloud-init modules --mode final
```

## Common Issues and Solutions

### Cloud-init Not Running

**Symptoms**: No cloud-init logs, status shows disabled

**Check**:

```bash
# Verify cloud-init is enabled
systemctl is-enabled cloud-init

# Check datasource detection
sudo /usr/lib/cloud-init/ds-identify --force

# Check systemd services
systemctl status cloud-init-local
systemctl status cloud-init
systemctl status cloud-config
systemctl status cloud-final
```

**Solutions**:

```bash
# Enable cloud-init
sudo systemctl enable cloud-init

# Force datasource (if detection fails)
echo 'datasource_list: ["Ec2"]' | sudo tee /etc/cloud/cloud.cfg.d/90_datasource.cfg
```

### User-data Not Applied

**Symptoms**: User-data commands not executed, files not created

**Check**:

```bash
# Verify user-data was received
sudo cloud-init query userdata

# Check for user-data processing errors
grep -A 10 -B 10 "user.data" /var/log/cloud-init.log

# Validate user-data format
cloud-init schema --config-file <(sudo cloud-init query userdata)
```

**Common causes**:

- Invalid YAML syntax
- Missing `#cloud-config` header
- User-data too large
- Network issues fetching external includes

### Network Configuration Issues

**Symptoms**: Wrong network config, no connectivity

**Check**:

```bash
# Check applied network config
cat /run/cloud-init/network-config.json

# Check network rendering logs
grep -i "network" /var/log/cloud-init.log

# Check for network config source
cloud-init query network_config
```

**Debug**:

```bash
# Disable cloud-init networking (fallback to distro)
echo 'network: {config: disabled}' | sudo tee /etc/cloud/cloud.cfg.d/99_disable_network.cfg
```

### Package Installation Failures

**Symptoms**: Packages not installed, package manager errors

**Check**:

```bash
# Check package installation logs
grep -A 20 "package" /var/log/cloud-init-output.log

# Verify package sources
grep -A 10 "package_update\|packages" /var/log/cloud-init.log
```

**Debug**:

```bash
# Test package installation manually
sudo apt update
sudo apt install -y nginx  # or your failing package
```

### Script/Command Failures

**Symptoms**: Custom scripts not running, command errors

**Check**:

```bash
# Check script output and errors
tail -50 /var/log/cloud-init-output.log

# Look for specific command failures
grep -A 5 -B 5 "runcmd\|bootcmd" /var/log/cloud-init.log
```

**Debug**:

```bash
# Test commands manually
sudo /bin/bash  # Run as root like cloud-init
# Then test your failing commands
```

## Advanced Debugging

### Datasource Debugging

```bash
# Test datasource manually
sudo python3 -c "
from cloudinit.sources import DataSourceEc2
ds = DataSourceEc2.DataSourceEc2({}, None, None)
print(ds.get_data())
"

# Check metadata service connectivity
curl -m 5 http://169.254.169.254/latest/meta-data/instance-id
```

### Module Debugging

```bash
# Enable module debug output
sudo mkdir -p /var/log/cloud-init-modules/

# Run module with Python debugger
sudo python3 -c "
import sys
sys.path.insert(0, '/usr/lib/python3/dist-packages')
from cloudinit.config import cc_runcmd
# Debug module here
"
```

### Systemd Service Debugging

```bash
# Check service dependencies
systemctl list-dependencies cloud-init

# View service logs
journalctl -u cloud-init-local
journalctl -u cloud-init
journalctl -u cloud-config
journalctl -u cloud-final

# Check service timing
systemd-analyze blame | grep cloud
```

## Collecting Debug Information

### Automated Collection

```bash
# Collect all debug info into tarball
sudo cloud-init collect-logs

# Creates /root/cloud-init.tar.gz with:
# - All log files
# - Configuration files
# - System information
# - Network information
```

### Manual Collection

```bash
# Essential files for troubleshooting
sudo tar -czf cloud-init-debug.tar.gz \
  /var/log/cloud-init*.log \
  /run/cloud-init/ \
  /etc/cloud/ \
  /var/lib/cloud/
```

## Performance Optimization

### Identify Slow Operations

```bash
# Find slowest modules
cloud-init analyze blame

# Check boot timeline
cloud-init analyze show

# Look for network timeouts
grep -i "timeout\|slow" /var/log/cloud-init.log
```

### Common Optimizations

```bash
# Disable unused modules
# Edit /etc/cloud/cloud.cfg.d/90_custom.cfg
cloud_config_modules:
  - [cc_users_groups, once]
  # Remove unused modules

# Reduce datasource timeout
datasource:
  Ec2:
    timeout: 10
    max_wait: 30
```

## Testing Cloud-init Configs

### Local Testing with NoCloud

```bash
# Create test directory
sudo mkdir -p /var/lib/cloud/seed/nocloud-net/

# Add user-data
sudo tee /var/lib/cloud/seed/nocloud-net/user-data << 'EOF'
#cloud-config
hostname: test-host
users:
  - name: testuser
    sudo: ALL=(ALL) NOPASSWD:ALL
EOF

# Add meta-data
sudo tee /var/lib/cloud/seed/nocloud-net/meta-data << 'EOF'
instance-id: test-instance-001
local-hostname: test-host
EOF

# Clean and test
sudo cloud-init clean
sudo cloud-init init --local
```

### Container Testing

```bash
# Test with LXD (if available)
lxc launch ubuntu:22.04 test-cloud-init
lxc config set test-cloud-init user.user-data - << 'EOF'
#cloud-config
packages: [nginx]
runcmd: [systemctl, enable, nginx]
EOF
```

## Useful Aliases

```bash
# Add to ~/.bashrc for easier debugging
alias ci-status='cloud-init status'
alias ci-wait='cloud-init status --wait'
alias ci-logs='sudo tail -f /var/log/cloud-init.log'
alias ci-output='sudo tail -f /var/log/cloud-init-output.log'
alias ci-query='cloud-init query'
alias ci-clean='sudo cloud-init clean'
alias ci-analyze='cloud-init analyze show'
```

---

## 📚 More Information

- **CLI reference**: [doc/rtd/reference/cli.rst](../doc/rtd/reference/cli.rst)
- **Performance analysis**: [doc/rtd/reference/performance_analysis.rst](../doc/rtd/reference/performance_analysis.rst)
- **FAQ**: [doc/rtd/reference/faq.rst](../doc/rtd/reference/faq.rst)
- **Instance data**: [doc/rtd/explanation/instancedata.rst](../doc/rtd/explanation/instancedata.rst)
- **Analyze command**: [doc/rtd/explanation/analyze.rst](../doc/rtd/explanation/analyze.rst)
- **Troubleshooting guide**: [doc/rtd/howto/](../doc/rtd/howto/)
- **Development guide**: [doc/rtd/development/](../doc/rtd/development/)
