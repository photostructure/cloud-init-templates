# Datasources - TL;DR

## What are Datasources?

Datasources are sources of configuration data for cloud-init that provide:

- **Meta-data**: Instance platform data (machine ID, hostname, network config)
- **User-data**: User-provided configuration (cloud-config, scripts, etc.)
- **Vendor-data**: Cloud provider-specific configuration

**Key concept**: Cloud-init auto-detects which datasource it's running on during the Detect stage, then fetches configuration from that source during the Local stage.

## How Datasource Detection Works

1. **Platform identification**: `ds-identify` tool checks hardware/environment
2. **Auto-detection**: Cloud-init tries to determine the cloud platform automatically
3. **Fallback**: Uses configuration or kernel parameters if auto-detection fails

```bash
# Check detected datasource
cloud-init query ds_name
# Example output: "ec2"
```

## Major Datasources

### EC2 (Amazon Web Services)

**Detection**: Checks for AWS metadata service at `169.254.169.254`

```bash
# Metadata service endpoints
GET http://169.254.169.254/2009-04-04/meta-data/
GET http://169.254.169.254/2009-04-04/user-data
```

**Common metadata**:

- `instance-id`, `ami-id`, `instance-type`
- `local-ipv4`, `public-ipv4`, `hostname`
- `placement/availability-zone`, `security-groups`
- `public-keys/` (SSH keys)

**API versions supported**:

- `2021-03-23`: Instance tag support
- `2016-09-02`: Secondary IP address support
- `2009-04-04`: Minimum version for basic metadata

**Configuration**:

```yaml
# /etc/cloud/cloud.cfg.d/90_ec2.cfg
datasource:
  Ec2:
    timeout: 50
    max_wait: 120
    metadata_urls: ["http://169.254.169.254"]
```

### Azure

**Detection**: Looks for Azure IMDS service + OVF CD-ROM

**Data sources**:

- **IMDS** (Instance Metadata Service): `169.254.169.254` for network config, SSH keys
- **OVF CD-ROM**: `/dev/sr0` or similar for user-data in `ovf-env.xml`

**Configuration**:

```yaml
datasource:
  Azure:
    apply_network_config: true
    apply_network_config_for_secondary_ips: true
    data_dir: /var/lib/waagent
```

**User-data**: Base64 encoded in `<UserData>` element of `ovf-env.xml`

### ConfigDrive (OpenStack)

**Detection**: Looks for filesystem labeled `config-2` or `CONFIG-2`

**Format**: Version 2 (recommended)

```
/config-drive/
├── openstack/
│   ├── latest/
│   │   ├── meta_data.json
│   │   └── user_data
│   └── content/
│       ├── 0000
│       └── 0001
└── ec2/
    └── latest/
        └── meta-data.json
```

**Filesystem**: Usually `vfat` or `iso9660`

**Behavior**: Often used for network config only, then EC2 metadata for full config

### Google Compute Engine (GCE)

**Detection**: Checks GCE metadata service

```bash
# Metadata service with required header
curl -H "Metadata-Flavor: Google" \
  http://169.254.169.254/computeMetadata/v1/instance/
```

**Unique features**:

- Requires `Metadata-Flavor: Google` header
- SSH keys in `project/attributes/ssh-keys` and `instance/attributes/ssh-keys`

### DigitalOcean

**Detection**: Checks for DO metadata service

```bash
# Metadata endpoints
GET http://169.254.169.254/metadata/v1/
GET http://169.254.169.254/metadata/v1/user-data
```

**Features**:

- Supports floating IPs
- DNS configuration
- User-data and metadata via API

### VMware

**Multiple datasources available**:

- **VMware Tools**: Uses `vmware-rpctool`
- **OVF**: Reads OVF environment from CD-ROM
- **vSphere Guest API**: Modern API-based approach

**OVF Transport**: Reads from mounted CD-ROM with OVF environment data

## Instance Data Access

All datasource metadata is available via instance-data:

```bash
# View all instance data
cloud-init query --all

# Check specific values
cloud-init query v1.cloud_name      # "aws", "azure", "gce", etc.
cloud-init query v1.instance_id     # Instance identifier
cloud-init query v1.region          # Cloud region
cloud-init query ds.meta_data       # Raw metadata from datasource
```

**Instance data location**: `/run/cloud-init/instance-data.json`

## Manual Datasource Configuration

### Force specific datasource

```yaml
# /etc/cloud/cloud.cfg.d/90_datasource.cfg
datasource_list: ["Ec2", "None"]
```

### Kernel command line override

```bash
# Force EC2 datasource
ds=ec2

# Disable cloud-init entirely
cloud-init=disabled
```

### Debug datasource detection

```bash
# Test datasource detection
sudo /usr/lib/cloud-init/ds-identify --force

# Check what was detected
cat /run/cloud-init/cloud-init-generator.log
```

## Network Configuration Priority

Datasources provide network config with this precedence:

1. **Kernel command line**: `ip=` or `network-config=<base64>`
2. **System config**: `network:` in `/etc/cloud/cloud.cfg.d/`
3. **Datasource**: Network config from cloud metadata
4. **Fallback**: DHCP on first available interface

## Common Patterns

### Hybrid cloud setup

```yaml
# Support multiple datasources for hybrid deployments
datasource_list: ["Ec2", "Azure", "ConfigDrive", "None"]
```

### Local development/testing

```yaml
# Use NoCloud datasource for local testing
datasource:
  NoCloud:
    # Provide seed directory or ISO
    seedfrom: /var/lib/cloud/seed/nocloud-net/
```

### Bare metal with ConfigDrive

```yaml
# ConfigDrive for bare metal with network config
datasource_list: ["ConfigDrive", "None"]
datasource:
  ConfigDrive:
    dsmode: local # Don't require network
```

## Troubleshooting

### Check datasource detection

```bash
# What datasource was used?
cloud-init query ds_name

# View raw metadata
cloud-init query ds.meta_data

# Check detection logs
grep -i datasource /var/log/cloud-init.log
```

### Force datasource re-detection

```bash
# Clean and retry
sudo cloud-init clean
sudo cloud-init init --local
```

### Test with specific datasource

```bash
# Test EC2 datasource specifically
sudo cloud-init --debug single --name cc_set_hostname --frequency once
```

## Security Considerations

### Metadata service access

- EC2/Azure metadata services are accessible to all processes on instance
- Some services support IMDSv2 with token-based authentication
- Network ACLs can restrict metadata service access

### User-data sensitivity

- User-data may contain secrets, SSH keys, passwords
- Visible in cloud console, logs, and metadata service
- Use secrets management systems for sensitive data

---

## 📚 More Information

- **Datasources reference**: [doc/rtd/reference/datasources.rst](../doc/rtd/reference/datasources.rst)
- **Individual datasource docs**: [doc/rtd/reference/datasources/](../doc/rtd/reference/datasources/)
- **Instance data**: [doc/rtd/explanation/instancedata.rst](../doc/rtd/explanation/instancedata.rst)
- **Network configuration**: [doc/rtd/reference/network-config.rst](../doc/rtd/reference/network-config.rst)
- **EC2 datasource**: [doc/rtd/reference/datasources/ec2.rst](../doc/rtd/reference/datasources/ec2.rst)
- **Azure datasource**: [doc/rtd/reference/datasources/azure.rst](../doc/rtd/reference/datasources/azure.rst)
- **ConfigDrive**: [doc/rtd/reference/datasources/configdrive.rst](../doc/rtd/reference/datasources/configdrive.rst)
