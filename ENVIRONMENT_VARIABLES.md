# Environment Variables Reference

This document describes all environment variables used by the base templates and how to configure them in your server configurations.

## 🔧 Configuration System

Base templates load environment variables from `/etc/environment.d/90-infrastructure.conf` using this pattern:

```bash
# In all base template scripts
[ -f /etc/environment.d/90-infrastructure.conf ] && . /etc/environment.d/90-infrastructure.conf

# Then use with fallbacks
EMAIL="${DEVOPS_EMAIL:-admin@example.com}"
```

## 📧 Email Configuration Variables

### `DEVOPS_EMAIL`

- **Used by**: `base/email-alerts.yaml`
- **Purpose**: Recipient email for critical system alerts
- **Default**: `admin@example.com`
- **Example**: `devops@yourcompany.com`

### `ALERTS_EMAIL`

- **Used by**: `base/email-alerts.yaml`
- **Purpose**: Sender email for outgoing alerts via AWS SES
- **Default**: `alerts@example.com`
- **Example**: `alerts@yourcompany.com`

### `ADMIN_EMAIL`

- **Used by**: Various base templates
- **Purpose**: General administrative contact email
- **Default**: `admin@example.com`
- **Example**: `admin@yourcompany.com`

## 🌐 Domain Configuration Variables

### `SEARCH_DOMAIN`

- **Used by**: Search server configurations
- **Purpose**: FQDN for search service
- **Default**: `search.example.com`
- **Example**: `search.yourcompany.com`

### `WEB_DOMAIN`

- **Used by**: Web server configurations, CORS settings
- **Purpose**: Primary website domain
- **Default**: `example.com`
- **Example**: `yourcompany.com`

### `FORUM_DOMAIN`

- **Used by**: Forum integrations, webhooks
- **Purpose**: Forum/community domain
- **Default**: `forum.example.com`
- **Example**: `forum.yourcompany.com`

## ☁️ Infrastructure Variables

### `AWS_REGION`

- **Used by**: `base/email-alerts.yaml` (AWS SES)
- **Purpose**: AWS region for SES email service
- **Default**: `us-east-1`
- **Example**: `us-west-2`

## 🔒 ~~Security~~ Configuration Variables

### `SSH_PORT`

- **Used by**: `base/hardening.yaml`
- **Purpose**: Custom SSH port for security through obscurity
- **Default**: `22` (standard SSH port)
- **Example**: `2222` (but pick something else!)
- **Notes**:
  - Default behavior: Uses standard port 22 with default fail2ban configuration
  - Note that there are some benefits to using a port under 1024, and _different_ benefits to running on a port between 49152 and 65535.
  - Custom port: Setting any other port automatically configures:
    - UFW firewall rules (removes port 22, adds custom port)
    - fail2ban jail configuration for the custom port
    - systemd socket activation and sshd_config
  - **Audit logging benefit**: Moving SSH off the standard port 22 substantially reduces automated attack attempts and subsequent noisy log files

## 💾 Setting Environment Variables

Create this file in your server configurations:

```yaml
# In your servers/your-server.yaml
write_files:
  - path: /etc/environment.d/90-infrastructure.conf
    content: |
      # Email Configuration
      DEVOPS_EMAIL="devops@yourcompany.com"
      ALERTS_EMAIL="alerts@yourcompany.com"
      ADMIN_EMAIL="admin@yourcompany.com"

      # Domain Configuration
      SEARCH_DOMAIN="search.yourcompany.com"
      WEB_DOMAIN="yourcompany.com"
      FORUM_DOMAIN="forum.yourcompany.com"

      # Infrastructure
      AWS_REGION="us-west-2"
      SSH_PORT="2222"
    permissions: "0644"
    owner: root:root
```

## 🔒 Security Notes

- **Environment file is world-readable** (0644) - don't put secrets here
- **For secrets**, use files with restricted permissions (0600)
- **AWS credentials** should go in `/var/lib/alerts/.aws/credentials`
- **API keys** should be in service-specific config files

## ✅ Validation

Test your environment configuration:

```bash
# SSH into your server after deployment
ssh -p $SSH_PORT user@your-server

# Check environment file exists
cat /etc/environment.d/90-infrastructure.conf

# Test variable loading in a script
[ -f /etc/environment.d/90-infrastructure.conf ] && . /etc/environment.d/90-infrastructure.conf
echo "Email will be sent to: ${DEVOPS_EMAIL:-admin@example.com}"
```

## 🆕 Adding New Variables

When adding new environment variables to base templates:

1. **Add to this documentation** with description and default
2. **Update base template** to source the environment file
3. **Use fallback defaults** for backward compatibility:
   ```bash
   MY_VAR="${MY_NEW_VARIABLE:-sensible-default}"
   ```

## 📖 Examples

See the `examples/` directory for complete server configurations showing proper environment variable usage.
