# Cloud-init Overview - TL;DR

## What is cloud-init?

Cloud-init is the **industry standard** multi-distribution method for cross-platform cloud instance initialization. It's supported across all major public cloud providers, provisioning systems for private cloud infrastructure, and bare-metal installations.

**Key concept**: Cloud-init takes configuration you provide and automatically applies those settings when an instance is created, ensuring consistent, repeatable results.

## How it works

Cloud-init operates in **5 sequential boot stages**:

```
Detect → Local → Network → Config → Final
```

### Boot Stages Breakdown

| Stage       | When                      | What it does                              | Network |
| ----------- | ------------------------- | ----------------------------------------- | ------- |
| **Detect**  | Very early boot           | Platform identification via `ds-identify` | No      |
| **Local**   | Early boot, `/` mounted   | Find datasource, write network config     | No      |
| **Network** | After network up          | Process user-data, mount disks            | Yes     |
| **Config**  | After network             | Run configuration modules (runcmd, etc.)  | Yes     |
| **Final**   | Late boot (like rc.local) | Install packages, run user scripts        | Yes     |

**Early boot (Local stage)**:

- Identifies the datasource (cloud platform)
- Fetches meta-data, user-data, vendor-data
- Writes network configuration
- Must block network to prevent stale config

**Late boot (Network/Config/Final stages)**:

- Processes configuration modules
- Creates users, installs packages
- Executes custom scripts
- Integrates with config management tools (Puppet, Ansible, Chef)

### Visual Timeline

```
System boot
    ↓
[Detect] Platform identification
    ↓
[Local] Get config data + network setup
    ↓
Network interfaces come up
    ↓
[Network] Process user-data, setup storage
    ↓ (SSH/login available)
[Config] Run configuration modules
    ↓
[Final] Install packages, run user scripts
    ↓
System ready
```

## Core Architecture

### Configuration Sources (priority order)

1. **Hardcoded config** - Built into cloud-init source
2. **Configuration files** - `/etc/cloud/cloud.cfg` and `/etc/cloud/cloud.cfg.d/*.cfg`
3. **Runtime config** - `/run/cloud-init/cloud.cfg`
4. **Kernel command line** - `cc:` to `end_cc` parameters
5. **Vendor-data** - Provided by cloud provider
6. **User-data** - Provided by user (highest priority)

### Key Components

**Datasources**: Sources of configuration data

- EC2 (AWS) - via metadata service at 169.254.169.254
- Azure - via IMDS + OVF CD-ROM
- ConfigDrive - OpenStack-style configuration disk
- GCE, DigitalOcean, VMware, etc.

**Modules**: Specific functionality handlers (~50 modules)

- System setup: users, SSH keys, hostname
- Package management: apt, yum, snap
- File operations: write files, mount disks
- Command execution: bootcmd, runcmd

**User-data formats**: Different ways to provide config

- Cloud-config (YAML) - most common
- Shell scripts
- MIME multi-part archives

## Common Use Cases

### Basic instance setup

```yaml
#cloud-config
hostname: webserver-01
users:
  - name: admin
    ssh_authorized_keys:
      - ssh-rsa AAAAB3...
    sudo: ALL=(ALL) NOPASSWD:ALL
packages:
  - nginx
  - git
runcmd:
  - systemctl enable nginx
  - systemctl start nginx
```

### Package management

```yaml
#cloud-config
package_update: true
package_upgrade: true
packages:
  - docker.io
  - python3-pip
```

### File creation

```yaml
#cloud-config
write_files:
  - path: /etc/motd
    content: |
      Welcome to the server!
  - path: /opt/app/config.json
    content: |
      {"env": "production"}
    permissions: "0644"
```

### Running commands

```yaml
#cloud-config
runcmd:
  - echo "Setup complete" > /tmp/done.txt
  - mkdir -p /opt/app
  - chmod 755 /opt/app
```

## Key Files and Locations

| Location                              | Purpose                          |
| ------------------------------------- | -------------------------------- |
| `/etc/cloud/cloud.cfg`                | Main configuration file          |
| `/etc/cloud/cloud.cfg.d/`             | Additional config files          |
| `/var/lib/cloud/`                     | Cloud-init state/cache directory |
| `/var/log/cloud-init.log`             | Main log file                    |
| `/var/log/cloud-init-output.log`      | Output from commands             |
| `/run/cloud-init/instance-data.json`  | Instance metadata                |
| `/run/cloud-init/network-config.json` | Applied network config           |

## Quick Commands

```bash
# Check cloud-init status
cloud-init status

# Wait for cloud-init to complete
cloud-init status --wait

# View instance data
cloud-init query --all

# Validate cloud-config file
cloud-init schema --config-file myconfig.yaml

# Clean and re-run (testing)
cloud-init clean --reboot

# Analyze performance
cloud-init analyze show
```

## Network Behavior

**Default**: Cloud-init writes network config during Local stage

- Datasource provides network config (preferred)
- Fallback: DHCP on first available interface
- User-data **cannot** change network configuration

**Disabling network management**:

```yaml
# In /etc/cloud/cloud.cfg
network:
  config: disabled
```

## First Boot vs Subsequent Boots

Cloud-init determines "first boot" to decide what to run:

- **First boot**: Runs all applicable modules
- **Subsequent boots**: Only runs modules marked for every boot
- Uses `/var/lib/cloud/instance` files to track state

## Key Design Principles

1. **Idempotent**: Safe to run multiple times
2. **Distribution agnostic**: Works across Linux distros
3. **Cloud agnostic**: Works across cloud providers
4. **Modular**: Pick and choose functionality
5. **Templatable**: Use Jinja2 templates with instance data

---

## 📚 More Information

- **Full documentation**: [doc/rtd/index.rst](../doc/rtd/index.rst)
- **Introduction**: [doc/rtd/explanation/introduction.rst](../doc/rtd/explanation/introduction.rst)
- **Boot stages**: [doc/rtd/explanation/boot.rst](../doc/rtd/explanation/boot.rst)
- **Configuration**: [doc/rtd/explanation/configuration.rst](../doc/rtd/explanation/configuration.rst)
- **Examples**: [doc/examples/](../doc/examples/)
- **Tutorials**: [doc/rtd/tutorial/](../doc/rtd/tutorial/)
- **FAQ**: [doc/rtd/reference/faq.rst](../doc/rtd/reference/faq.rst)
