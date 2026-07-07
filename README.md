# Cloud-Init Infrastructure Templates

Reusable, generic cloud-init configuration templates for common server infrastructure patterns. Compose them into your own server configs by **inlining** them at render time (see the composable pattern below).

> ⚠️ **Do not pull these templates with `text/x-include-url` from inside a
> `#cloud-config-archive`.** cloud-init never fetches an include nested in an
> archive — it attaches the part inert, so the templates silently don't run. Inline
> them instead (one `text/cloud-config` part per template, assembled at render
> time). PhotoStructure's `cloud-init-servers` repo does this with `bin/render.py`.

## 🏗️ Architecture

These templates follow a **composable pattern**:

- **Generic base templates** (this repo) - safe to open source
- **Your server configurations** (private repo) - domain-specific customizations

```yaml
# your-private-repo/servers/web-server.yaml
#cloud-config-archive

# Environment setup (runs first)
- type: text/cloud-config
  content: |
    write_files:
      - path: /etc/environment.d/90-infrastructure.conf
        content: |
          ADMIN_EMAIL="admin@yourcompany.com"
          AWS_REGION="us-west-2"
        permissions: '0644'
        owner: root:root

# Base templates, INLINED by the renderer (one part per template).
# Your renderer splices in the full contents of each base/*.yaml here.
- type: text/cloud-config
  content: |
    # ...full contents of base/hardening.yaml...
- type: text/cloud-config
  content: |
    # ...full contents of base/docker.yaml...

# Your application-specific configuration
- type: text/cloud-config
  content: |
    # Your app config here...
```

A ~120-line renderer (see `cloud-init-servers/bin/render.py`) turns a short
manifest of role names into exactly this archive — nothing is fetched at boot.

## 📦 Available Base Templates

### Template Variants

Some templates come in multiple variants to support different use cases:

- **Node.js**: Choose between `nodejs-22.yaml` (LTS) or `nodejs-24.yaml` (Latest) based on your application requirements
- **PostgreSQL**: Single template `postgres.yaml` installs latest version from PostgreSQL's official repository

### `base/hardening.yaml`

- **Purpose**: Security hardening for Ubuntu servers
- **Features**: UFW firewall, fail2ban, automatic security updates, SSH hardening
- **Environment Variables**: None required
- **Use Case**: Apply to all production servers
- ⚠️ **CAUTION**: This configuration **reboots the server at 2AM UTC time** if there are updates that required a reboot. **You may not want this**.

### `base/docker.yaml`

- **Purpose**: Docker CE installation and configuration
- **Features**: Latest Docker CE, docker-compose, systemd integration
- **Environment Variables**: None required
- **Use Case**: Container-based applications
- ⚠️ **CAUTION**: You should look into more secure docker-like replacements, like [podman](https://podman.io/).

### `base/email-alerts.yaml`

- **Purpose**: Critical system alerts via AWS SES
- **Features**: Login notifications, disk/system monitoring, service failure alerts
- **Environment Variables**: `DEVOPS_EMAIL`, `ALERTS_EMAIL`, `AWS_REGION`
- **Use Case**: Production monitoring and incident response

### `base/nodejs-22.yaml` & `base/nodejs-24.yaml`

- **Purpose**: Node.js runtime installation
- **Features**: Node.js 22.x or 24.x LTS via NodeSource repository
- **Environment Variables**: None required
- **Use Case**: Node.js applications

### `base/postgres.yaml`

- **Purpose**: PostgreSQL database installation
- **Features**: Latest PostgreSQL from official PostgreSQL repository
- **Environment Variables**: None required
- **Use Case**: Database servers

## 🔧 Environment Variable System

Templates use environment variables loaded from `/etc/environment.d/90-infrastructure.conf` for customization without hardcoded values.

### ⚠️ Important: Using Cloud-Config-Archive

**You cannot mix `#include` with `#cloud-config` in the same user-data.** Instead, use `#cloud-config-archive` to combine multiple formats.

**Correct approach with cloud-config-archive (inline the template — see warning at top):**

```yaml
#cloud-config-archive

# 1. Create environment files first
- type: text/cloud-config
  content: |
    write_files:
      - path: /etc/environment.d/90-infrastructure.conf
        content: |
          DEVOPS_EMAIL="ops@example.com"
        permissions: '0644'
        owner: root:root

# 2. Base template, INLINED by the renderer (NOT text/x-include-url)
- type: text/cloud-config
  content: |
    # ...full contents of base/email-alerts.yaml...

# 3. Additional configuration
- type: text/cloud-config
  content: |
    merge_how:
      - name: list
        settings: [append]
      - name: dict
        settings: [no_replace, recurse_list]
    packages: [...]
```

**Why this approach works:** Cloud-config-archive processes each section in order, ensuring environment files are created before included templates run.

### Setting Environment Variables

Create the environment file in your server configuration:

```yaml
# In your private server configs (using cloud-config-archive)
#cloud-config-archive

- type: text/cloud-config
  content: |
    write_files:
      - path: /etc/environment.d/90-infrastructure.conf
        content: |
          # Email Configuration
          DEVOPS_EMAIL="devops@yourcompany.com"
          ALERTS_EMAIL="alerts@yourcompany.com"
          ADMIN_EMAIL="admin@yourcompany.com"

          # Infrastructure
          AWS_REGION="us-west-2"
          BACKUP_RETENTION_DAYS="14"
        permissions: "0644"
        owner: root:root
```

### Environment Variables

Templates use environment variables for customization. Common variables include `DEVOPS_EMAIL`, `ALERTS_EMAIL`, `AWS_REGION`, and `SSH_PORT`.

**📋 Complete reference**: See [`ENVIRONMENT_VARIABLES.md`](ENVIRONMENT_VARIABLES.md) for all available variables, their purposes, and defaults.

## 🚀 Quick Start

### 1. Fork this repository

```bash
# Create your own copy
gh repo fork your-org/cloud-init-templates
```

### 2. Create a server configuration

```yaml
# servers/web-server.yaml
#cloud-config-archive

# Environment setup (runs first)
- type: text/cloud-config
  content: |
    write_files:
      - path: /etc/environment.d/90-infrastructure.conf
        content: |
          DEVOPS_EMAIL="ops@yourcompany.com"
          ALERTS_EMAIL="alerts@yourcompany.com"
          AWS_REGION="us-west-2"
        permissions: '0644'
        owner: root:root

# Base templates, INLINED by the renderer (one part per template)
- type: text/cloud-config
  content: |
    # ...full contents of base/hardening.yaml...
- type: text/cloud-config
  content: |
    # ...full contents of base/docker.yaml...

# Your application-specific config
- type: text/cloud-config
  content: |
    packages:
      - nginx
    runcmd:
      - systemctl enable nginx
      - systemctl start nginx
```

### 3. Deploy with cloud provider

Render the self-contained user-data locally, then pass it to your provider:

```bash
# See cloud-init-servers/bin/render.py
render.py web-server > web-server.user-data
doctl compute droplet create web-01 --user-data-file web-server.user-data ...
```

## 🔒 Security Best Practices

### Base Templates (This Repo)

- ✅ **No hardcoded secrets** - All sensitive values use environment variables
- ✅ **Generic configurations** - Domain-agnostic settings only
- ✅ **Sensible defaults** - Safe fallback values provided
- ✅ **Open source friendly** - Safe to publish publicly

### Server Configurations (Your Repo)

- 🔐 **Keep private** - Contains your domain-specific secrets
- 🔐 **Environment variables** - Store sensitive values in env files
- 🔐 **Least privilege** - Only expose what's necessary for deployment

## 📁 Repository Structure

```
cloud-init-templates/
├── README.md                   # This file
├── ENVIRONMENT_VARIABLES.md    # Environment variable reference
├── base/                       # Base templates
│   ├── docker.yaml             # Docker installation
│   ├── email-alerts.yaml       # AWS SES alerting
│   ├── hardening.yaml          # Security hardening
│   ├── nodejs-22.yaml          # Node.js 22.x runtime
│   ├── nodejs-24.yaml          # Node.js 24.x runtime
│   └── postgres.yaml           # PostgreSQL from official repo
├── examples/                   # Example server configs
│   ├── search-server.yaml      # Search server with Meilisearch
│   └── web-server.yaml         # Web application server
└── tests/                      # Validation test suite
    ├── README.md               # Testing documentation
    ├── run-all-tests.sh        # Comprehensive test runner
    ├── test-email-alerts.sh    # Email alerting tests
    ├── test-hardening.sh       # Security hardening tests
    ├── test-security.sh        # General security tests
    └── utils.sh                # Shared testing utilities
```

## 🤝 Contributing

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/new-template`
3. **Follow the template standards**:
   - Use environment variables for customization
   - Provide sensible defaults
   - Include comprehensive comments
   - Test with multiple distributions
4. **Submit a pull request**

### Template Standards

- **Environment Loading**: All scripts must load env vars:
  ```bash
  [ -f /etc/environment.d/90-infrastructure.conf ] && . /etc/environment.d/90-infrastructure.conf
  ```
- **Sensible Defaults**: Always provide fallback values:
  ```bash
  EMAIL="${ADMIN_EMAIL:-admin@example.com}"
  ```
- **Documentation**: Clearly document required environment variables
- **Security**: No hardcoded secrets or domain-specific information

## 📚 Examples

See the `examples/` directory for complete server configuration examples showing how to combine multiple base templates.

## 🆘 Support

- **Documentation**: [Cloud-Init Docs](https://cloud-init.readthedocs.io/)

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

---

**🔧 Infrastructure as Code • 🔒 Security First • 🚀 Production Ready**
