# Cloud-Init Infrastructure Templates

Reusable, generic cloud-init configuration templates for common server infrastructure patterns. These templates are designed to be included in your own cloud-init configurations via `#include` directives.

## 🏗️ Architecture

These templates follow a **composable pattern**:

- **Generic base templates** (this repo) - safe to open source
- **Your server configurations** (private repo) - domain-specific customizations

```yaml
# your-private-repo/servers/web-server.yaml
#cloud-config

# Environment variables (must be before #include)
write_files:
  - path: /etc/environment.d/90-infrastructure.conf
    content: |
      ADMIN_EMAIL="admin@yourcompany.com"
      AWS_REGION="us-west-2"
    permissions: '0644'
    owner: root:root

#include
https://raw.githubusercontent.com/your-org/cloud-init-templates/main/base/hardening.yaml
https://raw.githubusercontent.com/your-org/cloud-init-templates/main/base/docker.yaml

# Your application-specific configuration...
```

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
- **WARNING**: This configuration **reboots the server at 2AM UTC time** if there are updates that required a reboot. **You may not want this**.

### `base/docker.yaml`

- **Purpose**: Docker CE installation and configuration
- **Features**: Latest Docker CE, docker-compose, systemd integration
- **Environment Variables**: None required
- **Use Case**: Container-based applications

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

### ⚠️ Important: Ordering Requirements

**Environment files must be created BEFORE #include directives** to ensure included templates can access the variables during execution.

**Correct order:**

```yaml
#cloud-config

# 1. Create environment files first
write_files:
  - path: /etc/environment.d/90-infrastructure.conf
    content: |
      DEVOPS_EMAIL="ops@example.com"

# 2. Then include templates that use those variables
#include
https://raw.githubusercontent.com/your-org/cloud-init-templates/main/base/email-alerts.yaml

# 3. Configure merge behavior (if needed)
merge_how:
  - name: list
    settings: [append]
  - name: dict
    settings: [no_replace, recurse_list]

# 4. Additional application-specific configuration
packages: [...]
```

**Why this matters:** Cloud-init processes #include files during the parsing phase, merging all configurations before individual modules execute. The write_files module runs early in the 'init' stage, so files created after #include may not be available to included templates.

### Setting Environment Variables

Create the environment file in your server configuration:

```yaml
# In your private server configs
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
#cloud-config

# Environment variables for templates (must be before #include)
write_files:
  - path: /etc/environment.d/90-infrastructure.conf
    content: |
      DEVOPS_EMAIL="ops@yourcompany.com"
      ALERTS_EMAIL="alerts@yourcompany.com"
      AWS_REGION="us-west-2"
    permissions: '0644'
    owner: root:root

#include
https://raw.githubusercontent.com/your-org/cloud-init-templates/main/base/hardening.yaml
https://raw.githubusercontent.com/your-org/cloud-init-templates/main/base/docker.yaml

# Your application-specific config
packages:
  - nginx

runcmd:
  - systemctl enable nginx
  - systemctl start nginx
```

### 3. Deploy with cloud provider

Most cloud providers accept cloud-init data during instance creation. Point to your server configuration:

```bash
# Use raw GitHub URL for your server config
https://raw.githubusercontent.com/your-org/your-servers/main/servers/web-server.yaml
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
│   ├── hardening.yaml          # Security hardening
│   ├── docker.yaml             # Docker installation
│   ├── email-alerts.yaml       # AWS SES alerting
│   ├── nodejs-22.yaml          # Node.js 22.x runtime
│   ├── nodejs-24.yaml          # Node.js 24.x runtime
│   └── postgres.yaml           # PostgreSQL from official repo
├── examples/                   # Example server configs
│   ├── web-server.yaml         # Web application server
│   └── search-server.yaml      # Search server with Meilisearch
└── tests/                      # Validation test suite
    ├── README.md               # Testing documentation
    ├── run-all-tests.sh        # Comprehensive test runner
    ├── test-hardening.sh       # Security hardening tests
    ├── test-email-alerts.sh    # Email alerting tests
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

## 🧪 Testing

Validate your templates and deployments with the included test suite:

```bash
# Run all tests
./tests/run-all-tests.sh

# Run specific tests
./tests/test-hardening.sh      # Security hardening
./tests/test-email-alerts.sh   # Email alerting
./tests/test-security.sh       # General security tests
```

**Use cases:**

- **Pre-deployment**: Validate templates before deploying
- **Post-deployment**: Verify server configuration after cloud-init
- **CI/CD**: Include in deployment pipelines for automated validation

See [`tests/README.md`](tests/README.md) for detailed testing documentation.

## 🆘 Support

- **Documentation**: [Cloud-Init Docs](https://cloud-init.readthedocs.io/)

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

---

**🔧 Infrastructure as Code • 🔒 Security First • 🚀 Production Ready**
