# Config Organization & DRY Patterns - TL;DR

## Why Organize Cloud-init Configs?

As you scale deployments, you'll want to share common configuration (hardening, monitoring, logging) across different server types while keeping deployment-specific customizations. Cloud-init provides several excellent mechanisms for DRYing up your configs.

**Key concept**: Don't repeat yourself - create reusable, composable configuration components that can be mixed and matched for different deployment flavors.

## Cloud Config Archives (Primary DRY Mechanism)

**Best approach for sharing configs across deployments with proper ordering**

> ⚠️ **Do NOT put `text/x-include-url` inside a `#cloud-config-archive`.**
> cloud-init only expands an include when it is a **top-level** part. Inside an
> archive, `_explode_archive()` attaches the include part inert and never fetches
> it — so the referenced base templates silently never run. (This is long-standing
> behavior, verifiable in `cloudinit/user_data.py`.) The `#include`-a-list-of-URLs
> pattern below is only valid as top-level user-data, not as an archive part.
>
> **To share templates in an archive, INLINE them** — one `text/cloud-config` part
> per template, assembled at render time. That is what the PhotoStructure
> `cloud-init-servers` repo does with `bin/render.py`, and what the "Cloud Config
> Archives (YAML alternative)" and `cloud-init devel make-mime` examples below show.
> The rendered archive is self-contained: nothing is fetched at boot.

### Basic Pattern

```yaml
#cloud-config-archive

# Environment setup (runs first)
- type: text/cloud-config
  content: |
    write_files:
      - path: /etc/environment.d/90-infrastructure.conf
        content: |
          ENV=production
          REGION=us-west-2
        permissions: '0644'
        owner: root:root

# Base configurations, INLINED (one part per template) by the renderer.
# Do NOT use `text/x-include-url` here — an archive never fetches it.
- type: text/cloud-config
  content: |
    # ...full contents of base-hardening.yaml, spliced in at render time...
- type: text/cloud-config
  content: |
    # ...full contents of monitoring-alerts.yaml, spliced in at render time...

# Service-specific overrides
- type: text/cloud-config
  content: |
    packages:
      - nginx
    runcmd:
      - systemctl enable nginx
```

### Organization Structure

```
https://configs.company.com/
├── base/
│   ├── hardening.yaml          # Security baseline for all servers
│   └── logging.yaml           # Centralized logging config
├── environments/
│   ├── production.yaml        # Prod-specific settings
│   ├── staging.yaml          # Staging overrides
│   └── development.yaml      # Dev environment config
└── services/
    ├── web-server.yaml       # Nginx, SSL, etc.
    ├── database.yaml         # MySQL/PostgreSQL config
    ├── load-balancer.yaml    # HAProxy/nginx LB
    └── worker.yaml           # Background job processing
```

### Environment-Specific Cloud Config Archives

```yaml
# Production web server user-data
#cloud-config-archive

# Environment variables (first)
- type: text/cloud-config
  content: |
    write_files:
      - path: /etc/environment.d/90-infrastructure.conf
        content: |
          ENVIRONMENT=production
          REGION=us-east-1
        permissions: '0644'
        owner: root:root

# Base configurations
- type: text/x-include-url
  content: |
    https://configs.company.com/base/hardening.yaml
    https://configs.company.com/environments/production.yaml
    https://configs.company.com/services/web-server.yaml

# Development database user-data
#cloud-config-archive

# Environment variables (first)
- type: text/cloud-config
  content: |
    write_files:
      - path: /etc/environment.d/90-infrastructure.conf
        content: |
          ENVIRONMENT=development
          REGION=us-west-2
        permissions: '0644'
        owner: root:root

# Base configurations
- type: text/x-include-url
  content: |
    https://configs.company.com/environments/development.yaml
    https://configs.company.com/services/database.yaml
```

### Authentication for Private Configs

```yaml
#cloud-config-archive

- type: text/x-include-url
  content: |
    https://deploy-token:secret@private-configs.company.com/hardening.yaml
    https://user:pass@internal.company.com/monitoring-prod.yaml
```

## MIME Multi-part Archives

**Programmatically build deployment-specific configs**

### Build Script Pattern

```bash
#!/bin/bash
# build-user-data.sh

ENVIRONMENT=${1:-production}
SERVICE_TYPE=${2:-web}

# Build deployment-specific user-data
cloud-init devel make-mime \
  -a configs/base/hardening.yaml:cloud-config \
  -a configs/environments/${ENVIRONMENT}.yaml:cloud-config \
  -a configs/services/${SERVICE_TYPE}.yaml:cloud-config \
  -a scripts/post-install.sh:x-shellscript \
  > user-data-${SERVICE_TYPE}-${ENVIRONMENT}.mime

echo "Generated: user-data-${SERVICE_TYPE}-${ENVIRONMENT}.mime"
```

### Usage Examples

```bash
# Generate different deployment configs
./build-user-data.sh production web
./build-user-data.sh staging database
./build-user-data.sh development worker
```

## Cloud Config Archives

**YAML-based alternative to MIME (easier to read/maintain)**

```yaml
#cloud-config-archive

# Base hardening - applied first
- type: text/cloud-config
  content: |
    package_update: true
    package_upgrade: true
    packages:
      - fail2ban
      - ufw
      - unattended-upgrades

    # Disable root login
    disable_root: true

    # Configure firewall
    runcmd:
      - ufw --force enable
      - ufw default deny incoming
      - ufw allow ssh

# Monitoring setup
- type: text/cloud-config
  content: |
    packages:
      - prometheus-node-exporter
      - filebeat

    write_files:
      - path: /etc/filebeat/filebeat.yml
        content: |
          output.logstash:
            hosts: ["logs.company.com:5044"]

    runcmd:
      - systemctl enable prometheus-node-exporter
      - systemctl start prometheus-node-exporter
      - systemctl enable filebeat
      - systemctl start filebeat

# Service-specific config
- type: text/cloud-config
  content: |
    packages:
      - nginx
      - certbot
      - python3-certbot-nginx

    write_files:
      - path: /etc/nginx/sites-available/default
        content: |
          server {
              listen 80;
              server_name _;
              return 301 https://$server_name$request_uri;
          }

    runcmd:
      - systemctl enable nginx
      - systemctl start nginx
      - certbot --nginx --non-interactive --agree-tos --email admin@company.com
```

## Jinja Templates for Dynamic DRY

**Template-driven configuration with variables**

### Environment-Based Templates

```yaml
## template: jinja
#cloud-config

# Environment-specific settings
{% if v1.region == "us-east-1" %}
timezone: America/New_York
ntp:
  servers: [time-a-g.nist.gov, time-b-g.nist.gov]
{% elif v1.region == "eu-west-1" %}
timezone: Europe/London
ntp:
  servers: [0.europe.pool.ntp.org, 1.europe.pool.ntp.org]
{% endif %}

# Instance-specific hostname
hostname: {{ v1.instance_id }}-{{ v1.region }}

# Cloud-specific package sources
{% if v1.cloud_name == "aws" %}
packages:
  - awscli
  - amazon-ssm-agent
{% elif v1.cloud_name == "gce" %}
packages:
  - google-cloud-sdk
{% endif %}

# Include environment-specific monitoring config
{% set monitor_config = "https://configs.company.com/monitoring-" + v1.region + ".yaml" %}
# Note: Can't directly include in Jinja, but can set variables for runcmd
runcmd:
  - curl -s {{ monitor_config }} | cloud-init devel render --user-data - --output /tmp/monitoring.yaml
  - cloud-init single --name cc_write_files --config /tmp/monitoring.yaml
```

### Service Discovery Templates

```yaml
## template: jinja
#cloud-config

# Dynamic service configuration based on instance metadata
write_files:
  - path: /etc/consul/consul.json
    content: |
      {
        "datacenter": "{{ v1.region }}",
        "node_name": "{{ v1.instance_id }}",
        "bind_addr": "{{ v1.local_ipv4 }}",
        "retry_join": [
          "consul-{{ v1.region }}-1.company.internal",
          "consul-{{ v1.region }}-2.company.internal",
          "consul-{{ v1.region }}-3.company.internal"
        ]
      }
```

## Configuration Merging

**Understanding how cloud-init combines multiple configs**

### Default Merge Behavior

```yaml
# Config 1
#cloud-config
packages:
  - nginx
  - git

runcmd:
  - systemctl start nginx

# Config 2
#cloud-config
packages:
  - mysql-server
  - python3

runcmd:
  - systemctl start mysql

# Merged Result:
# packages: [nginx, git, mysql-server, python3]  # Lists append
# runcmd: [systemctl start nginx, systemctl start mysql]  # Lists append
```

### Custom Merge Behavior

```yaml
#cloud-config
merge_how:
  - name: list
    settings: [append] # default
  - name: dict
    settings: [no_replace, recurse_list]

# Override merge behavior for specific keys
merge_type: dict(replace)+list(append)
```

## Best Practices

### 1. Repository Structure

```
cloud-configs/
├── README.md
├── base/
│   ├── hardening.yaml       # Security baseline
│   ├── logging.yaml         # Log forwarding
│   └── packages.yaml        # Common packages
├── environments/
│   ├── production.yaml      # Prod-specific settings
│   ├── staging.yaml         # Staging overrides
│   └── development.yaml     # Dev environment
├── services/
│   ├── web/
│   │   ├── nginx.yaml       # Web server config
│   │   └── ssl.yaml         # SSL/TLS setup
│   ├── database/
│   │   ├── mysql.yaml       # MySQL configuration
│   │   └── postgresql.yaml  # PostgreSQL configuration
│   └── cache/
│       └── redis.yaml       # Redis configuration
├── scripts/
│   ├── build-config.sh      # Config builder
│   └── validate-config.sh   # Validation script
└── templates/
    ├── hostname.j2          # Jinja templates
    └── service-discovery.j2
```

### 2. Version Control & CI/CD

```yaml
# .github/workflows/validate-configs.yml
name: Validate Cloud-Init Configs
on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install cloud-init
        run: sudo apt-get update && sudo apt-get install -y cloud-init

      - name: Validate all configs
        run: |
          find . -name "*.yaml" -exec cloud-init schema --config-file {} \;

      - name: Build test configs
        run: |
          ./scripts/build-config.sh production web
          ./scripts/build-config.sh staging database
```

### 3. Testing Configs

```bash
#!/bin/bash
# validate-config.sh

CONFIG_FILE=${1}

if [ -z "$CONFIG_FILE" ]; then
    echo "Usage: $0 <config-file>"
    exit 1
fi

echo "Validating $CONFIG_FILE..."

# Schema validation
cloud-init schema --config-file "$CONFIG_FILE"
if [ $? -ne 0 ]; then
    echo "❌ Schema validation failed"
    exit 1
fi

# Template rendering test (if it's a template)
if grep -q "## template: jinja" "$CONFIG_FILE"; then
    echo "Testing Jinja template rendering..."
    cloud-init devel render --user-data "$CONFIG_FILE" > /dev/null
    if [ $? -ne 0 ]; then
        echo "❌ Template rendering failed"
        exit 1
    fi
fi

echo "✅ $CONFIG_FILE is valid"
```

### 4. Security Considerations

```yaml
# configs/base/hardening.yaml
#cloud-config

# Never put secrets directly in shared configs
# Use placeholders or fetch at runtime
write_files:
  - path: /opt/app/fetch-secrets.sh
    permissions: "0755"
    content: |
      #!/bin/bash
      # Fetch actual secrets at runtime
      # Implementation depends on your secret management system
      echo "Fetching secrets..." >> /var/log/app-setup.log

# Use include-once for sensitive one-time setup
# #include-once
# https://private-configs.company.com/ssh-keys.yaml
```

### 5. Monitoring Config Deployment

```yaml
# Add to all base configs for tracking
#cloud-config
phone_home:
  url: https://monitoring.company.com/cloud-init-status
  post:
    - instance_id
    - hostname
    - fqdn
  tries: 3

final_message: |
  Cloud-init deployment completed successfully.
  Instance: $INSTANCE_ID
  Uptime: $UPTIME seconds

  Deployed configuration components:
  - Base hardening: ✅
  - Monitoring setup: ✅
  - Service config: ✅
```

## Deployment Patterns

### Pattern 1: Infrastructure as Code

```python
# terraform/user-data.tf
locals {
  base_configs = [
    "https://configs.company.com/base/hardening.yaml"
  ]

  web_configs = concat(local.base_configs, [
    "https://configs.company.com/environments/${var.environment}.yaml",
    "https://configs.company.com/services/web-server.yaml"
  ])
}

data "template_file" "web_user_data" {
  template = <<-EOF
  #cloud-config-archive

  # Environment setup
  - type: text/cloud-config
    content: |
      write_files:
        - path: /etc/environment.d/90-infrastructure.conf
          content: |
            ENVIRONMENT=${var.environment}
            REGION=${var.region}
          permissions: '0644'
          owner: root:root

  # Include base configurations
  - type: text/x-include-url
    content: |
      ${join("\n      ", local.web_configs)}
  EOF
}

resource "aws_instance" "web" {
  user_data = data.template_file.web_user_data.rendered
  # ... other configuration
}
```

### Pattern 2: Config Management Integration

```yaml
#cloud-config-archive

# Environment setup
- type: text/cloud-config
  content: |
    write_files:
      - path: /etc/environment.d/90-infrastructure.conf
        content: |
          ENVIRONMENT=production
        permissions: '0644'
        owner: root:root

# Bootstrap configuration management
- type: text/cloud-config
  content: |
    packages: [ansible]

    runcmd:
      # Apply base configuration via Ansible
      - ansible-pull -U https://github.com/company/infrastructure.git \
        -i localhost, \
        --tags "hardening,monitoring" \
        site.yml

      # Apply service-specific configuration
      - ansible-pull -U https://github.com/company/infrastructure.git \
        -i localhost, \
        --tags "web-server" \
        --extra-vars "environment=production" \
        site.yml
```

---

## 📚 More Information

- **User-data formats**: [doc/rtd/explanation/format.rst](../doc/rtd/explanation/format.rst)
- **Include files**: [doc/rtd/explanation/format.rst#include-file](../doc/rtd/explanation/format.rst#include-file)
- **Merging behavior**: [doc/rtd/reference/merging.rst](../doc/rtd/reference/merging.rst)
- **Jinja templates**: [doc/rtd/explanation/instancedata.rst](../doc/rtd/explanation/instancedata.rst)
- **MIME multi-part**: [doc/rtd/explanation/format.rst#mime-multi-part-archive](../doc/rtd/explanation/format.rst#mime-multi-part-archive)
- **Cloud config archives**: [doc/rtd/explanation/format.rst#cloud-config-archive](../doc/rtd/explanation/format.rst#cloud-config-archive)
- **Configuration sources**: [doc/rtd/explanation/configuration.rst](../doc/rtd/explanation/configuration.rst)
