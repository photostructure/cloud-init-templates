# User-data Formats - TL;DR

## What is User-data?

User-data is configuration provided by users to customize cloud instances at launch. Cloud-init supports multiple formats that can be mixed and matched for maximum flexibility.

**Key concept**: The first line of user-data determines the format. Cloud-init processes user-data during the Network stage and later.

## Format Overview

| Format               | Header                          | Use Case                       | When Runs          |
| -------------------- | ------------------------------- | ------------------------------ | ------------------ |
| Cloud-config         | `#cloud-config`                 | Declarative YAML configuration | Config/Final stage |
| Shell script         | `#!/bin/sh`                     | Custom commands                | Final stage        |
| Cloud boothook       | `#cloud-boothook`               | Early boot scripts             | Network stage      |
| Include file         | `#include`                      | Reference external configs     | Network stage      |
| MIME multi-part      | `Content-Type: multipart/mixed` | Combine multiple formats       | Various            |
| Cloud config archive | `#cloud-config-archive`         | YAML-based multi-format        | Various            |
| Part handler         | `#part-handler`                 | Custom format handlers         | Network stage      |
| Jinja template       | `## template: jinja`            | Dynamic configuration          | Any stage          |

## Cloud-config (Most Common)

**YAML-based declarative configuration**

```yaml
#cloud-config

# System identification
hostname: webserver-01
fqdn: webserver-01.example.com

# Users and SSH access
users:
  - name: admin
    gecos: Admin User
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: [sudo, docker]
    shell: /bin/bash
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2E... user@host

# Package management
package_update: true
package_upgrade: true
packages:
  - nginx
  - docker.io
  - python3-pip

# File operations
write_files:
  - path: /etc/nginx/sites-available/default
    content: |
      server {
        listen 80;
        root /var/www/html;
      }
    permissions: "0644"

# Command execution
runcmd:
  - systemctl enable nginx
  - systemctl start nginx
  - docker pull nginx:alpine

# Final actions
power_state:
  mode: reboot
  message: "Rebooting after setup"
  timeout: 30
```

**Validation**:

```bash
# Validate cloud-config syntax
cloud-init schema --config-file myconfig.yaml

# Dry-run to see what would happen
cloud-init devel render --user-data myconfig.yaml
```

## User-data Script

**Simple shell script execution**

```bash
#!/bin/bash
echo "Starting custom setup..." | tee /var/log/setup.log

# Install custom software
apt-get update
apt-get install -y htop

# Configure application
mkdir -p /opt/myapp
cat > /opt/myapp/config.json << EOF
{
  "environment": "production",
  "port": 8080
}
EOF

# Start services
systemctl enable myapp
systemctl start myapp

echo "Setup complete!" | tee -a /var/log/setup.log
```

**Key points**:

- Runs during Final stage (late in boot)
- Full shell capabilities
- Output goes to `/var/log/cloud-init-output.log`
- Must be executable shell script

## Cloud Boothook

**Scripts that run early and on every boot**

```bash
#cloud-boothook
#!/bin/bash

# Run only once per instance
cloud-init-per instance setup-hosts /bin/bash -c '
echo "192.168.1.100 database.local" >> /etc/hosts
echo "192.168.1.200 cache.local" >> /etc/hosts
'

# Run on every boot
echo "$(date): Boothook executed" >> /var/log/boothook.log

# Set kernel parameters
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p
```

**Key differences from user-data script**:

- Runs during Network stage (earlier)
- Runs on **every** boot (not just first)
- Use `cloud-init-per` for once-per-instance behavior

## Jinja Templates

**Dynamic configuration using instance data**

```yaml
## template: jinja
#cloud-config
hostname: {{ v1.instance_id }}-web
fqdn: {{ v1.instance_id }}-web.{{ v1.region }}.example.com

users:
  - name: {{ v1.distro }}
    groups: [sudo]

write_files:
  - path: /etc/instance-info
    content: |
      Instance ID: {{ v1.instance_id }}
      Cloud: {{ v1.cloud_name }}
      Region: {{ v1.region }}
      Distro: {{ v1.distro }} {{ v1.distro_version }}

runcmd:
  - echo "Running on {{ v1.cloud_name }}" > /tmp/cloud-name
```

**Available template variables**:

```bash
# See all available variables
cloud-init query --all

# Common template variables
v1.instance_id         # Instance identifier
v1.cloud_name         # aws, azure, gce, etc.
v1.region             # Cloud region
v1.distro             # ubuntu, centos, etc.
v1.distro_version     # 22.04, 8, etc.
ds.meta_data          # Raw datasource metadata
```

## MIME Multi-part Archive

**Combine multiple formats in one user-data**

```
Content-Type: multipart/mixed; boundary="===============1234567890=="
MIME-Version: 1.0

--===============1234567890==
Content-Type: text/cloud-boothook; charset="us-ascii"
MIME-Version: 1.0
Content-Disposition: attachment; filename="setup-hosts"

#cloud-boothook
#!/bin/bash
echo "192.168.1.100 database.local" >> /etc/hosts

--===============1234567890==
Content-Type: text/cloud-config; charset="us-ascii"
MIME-Version: 1.0
Content-Disposition: attachment; filename="main-config"

#cloud-config
packages:
  - nginx
  - mysql-client

--===============1234567890==
Content-Type: text/x-shellscript; charset="us-ascii"
MIME-Version: 1.0
Content-Disposition: attachment; filename="final-setup"

#!/bin/bash
systemctl restart nginx
--===============1234567890==--
```

**Create MIME archives**:

```bash
# Use cloud-init helper
cloud-init devel make-mime \
  -a config.yaml:cloud-config \
  -a script.sh:x-shellscript \
  > user-data.mime

# List supported content types
cloud-init devel make-mime --list-types
```

## Cloud Config Archive

**YAML-based alternative to MIME multi-part**

```yaml
#cloud-config-archive

# Cloud boothook
- type: text/cloud-boothook
  content: |
    #!/bin/bash
    echo "Early boot setup" > /tmp/early.log

# Main cloud-config
- type: text/cloud-config
  content: |
    packages:
      - nginx
      - git
    users:
      - name: webadmin
        sudo: ALL=(ALL) NOPASSWD:ALL

# Final shell script
- type: text/x-shellscript
  content: |
    #!/bin/bash
    systemctl enable nginx
    systemctl start nginx
```

**Advantages**:

- Easier to write than MIME
- Pure YAML format
- Better readability
- Version control friendly

## Include Files

**Reference external configuration sources**

```
#include
https://example.com/cloud-configs/base.yaml
https://example.com/cloud-configs/webserver.yaml
```

**Advanced includes**:

```
#include-once
# These URLs are fetched only once per instance
https://example.com/one-time-setup.sh
https://example.com/ssh-keys.yaml

#include
# These URLs are fetched on every boot
https://example.com/dynamic-config.yaml
```

**URL support**:

- `http://` and `https://`
- `file://` (local files)
- Basic authentication supported
- Recursive includes supported

## Gzip Compression

**Compress any user-data format to save space**

```bash
# Compress cloud-config
gzip -c myconfig.yaml > myconfig.yaml.gz

# Use compressed version as user-data
# Cloud-init automatically detects and decompresses
```

**Benefits**:

- Reduces user-data size limits
- Faster transmission
- Works with any format

## Content Types Reference

| Content-Type                | Header                          | Description            |
| --------------------------- | ------------------------------- | ---------------------- |
| `text/cloud-config`         | `#cloud-config`                 | YAML configuration     |
| `text/x-shellscript`        | `#!/bin/sh`                     | Shell script           |
| `text/cloud-boothook`       | `#cloud-boothook`               | Early boot script      |
| `text/x-include-url`        | `#include`                      | Include external files |
| `text/cloud-config-archive` | `#cloud-config-archive`         | Multi-format YAML      |
| `text/part-handler`         | `#part-handler`                 | Custom handler         |
| `multipart/mixed`           | `Content-Type: multipart/mixed` | MIME archive           |
| `text/jinja2`               | `## template: jinja`            | Jinja template         |

## Best Practices

### Security

- **Avoid secrets in user-data** - visible in cloud console and metadata
- Use secrets management services instead
- Consider using private include URLs for sensitive configs

### Organization

```yaml
#cloud-config

# Group related configurations
# 1. System setup
hostname: myserver
timezone: UTC

# 2. Users and access
users: [...]
ssh_authorized_keys: [...]

# 3. Packages and software
packages: [...]
package_update: true

# 4. Files and configuration
write_files: [...]

# 5. Commands and services
runcmd: [...]
```

### Testing

```bash
# Validate syntax
cloud-init schema --config-file config.yaml

# Test template rendering
cloud-init devel render --user-data template.yaml

# Dry run on running instance
sudo cloud-init single --name cc_runcmd --frequency once
```

### Error Handling

```yaml
#cloud-config

# Use proper YAML syntax
runcmd:
  - "echo 'quoted strings with special chars: like colons'"
  - mkdir -p /opt/app
  - |
    # Multi-line commands
    if [ ! -f /opt/app/config ]; then
      echo "Creating config"
      touch /opt/app/config
    fi
```

## Troubleshooting

### Check user-data processing

```bash
# View processed user-data
cloud-init query userdata

# Check for processing errors
grep -i error /var/log/cloud-init.log

# View command output
tail -f /var/log/cloud-init-output.log
```

### Debug template rendering

```bash
# Test template with current instance data
cloud-init devel render --user-data template.yaml

# Check available template variables
cloud-init query --all | jq .
```

---

## 📚 More Information

- **User-data formats**: [doc/rtd/explanation/format.rst](../doc/rtd/explanation/format.rst)
- **Cloud-config reference**: [doc/rtd/explanation/about-cloud-config.rst](../doc/rtd/explanation/about-cloud-config.rst)
- **Examples library**: [doc/rtd/reference/yaml_examples/](../doc/rtd/reference/yaml_examples/)
- **Jinja templates**: [doc/rtd/explanation/instancedata.rst](../doc/rtd/explanation/instancedata.rst)
- **Example files**: [doc/examples/](../doc/examples/)
- **Schema validation**: [doc/rtd/reference/cli.rst](../doc/rtd/reference/cli.rst)
