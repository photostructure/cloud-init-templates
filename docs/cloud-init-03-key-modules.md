# Key Modules - TL;DR

## What are Modules?

Cloud-init modules are individual components that handle specific configuration tasks. There are ~50 modules that run at different stages of the boot process, controlled by configuration in `/etc/cloud/cloud.cfg`.

**Key concept**: Modules are organized by boot stage and run frequency. Each module has a schema defining its configuration options.

## Module Organization by Boot Stage

### Cloud-init Modules (Network Stage)

**Run after network is available, before user login**

- `disk_setup` - Partition and format disks
- `mounts` - Configure filesystem mounts
- `bootcmd` - Run commands early in boot

### Cloud-config Modules (Config Stage)

**Main configuration modules, run in parallel**

- Most user-facing modules (users, packages, files, etc.)
- Non-blocking operations
- SSH and login available during this stage

### Cloud-final Modules (Final Stage)

**Run at end of boot process**

- `scripts_user` - Execute user-data scripts
- `final_message` - Display completion message
- `power_state_change` - Reboot/shutdown actions

## Essential Modules

### Users and Groups (`cc_users_groups`)

**Configure system users and groups**

```yaml
#cloud-config

# Create groups first
groups:
  - docker
  - admingroup: [root, sys]

# Configure users
users:
  - default # Creates default user for distro
  - name: admin
    gecos: Administrator
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: [sudo, docker]
    shell: /bin/bash
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2E... user@host
    lock_passwd: true # Disable password login
  - name: app
    system: true # System user
    home: /opt/app
    shell: /usr/sbin/nologin
```

**Key options**:

- `default`: Creates distro's default user (ubuntu, ec2-user, etc.)
- `sudo`/`doas`: Configure privilege escalation
- `ssh_authorized_keys`: Add SSH public keys
- `lock_passwd`: Disable password authentication
- `system`: Create system user (UID < 1000)

### Package Management (`cc_package_update_upgrade_install`)

**Install and update packages**

```yaml
#cloud-config

# Update package lists
package_update: true

# Upgrade all packages
package_upgrade: true

# Install specific packages
packages:
  - nginx
  - docker.io
  - python3-pip
  - git
  - htop

# APT-specific configuration
apt:
  sources:
    docker:
      source: "deb https://download.docker.com/linux/ubuntu $RELEASE stable"
      keyid: 9DC858229FC7DD38854AE2D88D81803C0EBFCD88
```

**Distro support**:

- `apt` (Debian/Ubuntu)
- `yum`/`dnf` (RHEL/CentOS/Fedora)
- `zypper` (SUSE)
- `apk` (Alpine)

### File Operations (`cc_write_files`)

**Write files to the filesystem**

```yaml
#cloud-config

write_files:
  # Simple text file
  - path: /etc/motd
    content: |
      Welcome to the server!
      Managed by cloud-init

  # Binary file with encoding
  - path: /etc/ssl/private/server.key
    content: LS0tLS1CRUdJTi... # base64 encoded
    encoding: base64
    permissions: "0600"
    owner: root:root

  # Configuration file
  - path: /etc/nginx/sites-available/mysite
    content: |
      server {
          listen 80;
          server_name example.com;
          root /var/www/html;
      }
    permissions: "0644"

  # Deferred write (after package installation)
  - path: /etc/docker/daemon.json
    content: |
      {
        "log-driver": "json-file",
        "log-opts": {"max-size": "10m"}
      }
    defer: true # Wait until later in boot process
```

**Options**:

- `encoding`: `base64`, `gzip`, `gz+base64`
- `permissions`: Octal file permissions
- `owner`: `user:group` ownership
- `append`: Add to existing file instead of overwriting
- `defer`: Wait until packages are installed

### Command Execution

#### Bootcmd (`cc_bootcmd`)

**Run commands early in boot (Network stage)**

```yaml
#cloud-config

bootcmd:
  # Run before most other modules
  - echo 'Early boot command' >> /var/log/bootcmd.log
  - mount /dev/xvdb1 /mnt/data
  - sysctl -w net.ipv4.ip_forward=1
```

#### Runcmd (`cc_runcmd`)

**Run commands late in boot (Final stage)**

```yaml
#cloud-config

runcmd:
  # String format - interpreted by shell
  - "echo 'Hello World' > /tmp/hello.txt"

  # List format - executed directly (safer)
  - [systemctl, enable, nginx]
  - [systemctl, start, nginx]

  # Multi-line commands
  - |
    if ! systemctl is-active docker; then
      systemctl enable docker
      systemctl start docker
    fi

  # Set environment variables
  - DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server
```

**Key differences**:

- `bootcmd`: Runs early, before most modules
- `runcmd`: Runs late, after packages/users/files are set up

### SSH Configuration (`cc_ssh`)

**Configure SSH daemon and keys**

```yaml
#cloud-config

# SSH daemon configuration
ssh_pwauth: false # Disable password authentication
ssh_deletekeys: true # Remove default host keys

# Generate new host keys
ssh_genkeytypes: [rsa, ecdsa, ed25519]

# Custom sshd_config options
ssh_config:
  - "Protocol 2"
  - "PermitRootLogin no"
  - "PasswordAuthentication no"
  - "ChallengeResponseAuthentication no"

# Import SSH keys from services
ssh_import_id:
  - gh:username # GitHub
  - lp:username # Launchpad
```

### Disk and Mount Configuration

#### Disk Setup (`cc_disk_setup`)

**Partition and format disks**

```yaml
#cloud-config

disk_setup:
  /dev/xvdb:
    table_type: gpt
    layout:
      - [33, 82] # 33% swap
      - [66, 83] # 66% ext4
      - [1, 83] # remaining ext4
    overwrite: true
```

#### Mounts (`cc_mounts`)

**Configure filesystem mounts**

```yaml
#cloud-config

mounts:
  # Format: [device, mountpoint, filesystem, options, dump, pass]
  - [/dev/xvdb1, /mnt/data, ext4, "defaults,noatime", 0, 0]
  - [/dev/xvdb2, none, swap, sw, 0, 0]

# Swap configuration
swap:
  filename: /swapfile
  size: 2G
  maxsize: 2G
```

### System Configuration

#### Hostname (`cc_set_hostname`)

**Set system hostname**

```yaml
#cloud-config

hostname: webserver-01
fqdn: webserver-01.example.com

# Update /etc/hosts
manage_etc_hosts: true
```

#### Timezone (`cc_timezone`)

**Configure system timezone**

```yaml
#cloud-config

timezone: America/New_York
```

#### Locale (`cc_locale`)

**Set system locale**

```yaml
#cloud-config

locale: en_US.UTF-8
locale_configfile: /etc/default/locale
```

## Advanced Modules

### NTP (`cc_ntp`)

**Configure time synchronization**

```yaml
#cloud-config

ntp:
  enabled: true
  ntp_client: chrony # or systemd-timesyncd, ntp
  config:
    confpath: /etc/chrony/chrony.conf
    packages: [chrony]
    service_name: chrony
  servers:
    - 0.pool.ntp.org
    - 1.pool.ntp.org
```

### CA Certificates (`cc_ca_certs`)

**Install custom certificate authorities**

```yaml
#cloud-config

ca_certs:
  remove_defaults: false
  trusted:
    - |
      -----BEGIN CERTIFICATE-----
      MIIEBjCCAu6gAwIBAgIJAMc0ZzaSUK51MA0GCSqGSIb3DQEBBQUAMIGYMQswCQ...
      -----END CERTIFICATE-----
```

### Snap Packages (`cc_snap`)

**Install and configure snap packages**

```yaml
#cloud-config

snap:
  commands:
    - snap install docker
    - snap install code --classic
    - snap install kubectl --channel=1.28/stable
```

## Module Configuration

### Module Frequency

Modules run at different frequencies:

- `PER_INSTANCE`: Once per instance (first boot only)
- `PER_BOOT`: Every boot
- `PER_ONCE`: Once ever (across all instances from same image)
- `PER_ALWAYS`: Alias for PER_BOOT

### Disable/Enable Modules

```yaml
# /etc/cloud/cloud.cfg.d/90_custom.cfg

# Disable specific modules
cloud_config_modules:
  - [cc_users_groups, always] # Enable with frequency
  - [cc_ssh, once]
  # cc_landscape removed (disabled)

# Or disable in user-data
#cloud-config
cloud_final_modules: [] # Disable all final modules
```

### Custom Module Configuration

```yaml
#cloud-config

# Module-specific configuration
users:
  # This configures cc_users_groups module
  - name: admin

write_files:
  # This configures cc_write_files module
  - path: /tmp/test
    content: hello
```

## Practical Examples

### Web server setup

```yaml
#cloud-config

package_update: true
packages:
  - nginx
  - certbot
  - python3-certbot-nginx

write_files:
  - path: /var/www/html/index.html
    content: |
      <!DOCTYPE html>
      <html><body><h1>Welcome!</h1></body></html>

  - path: /etc/nginx/sites-available/default
    content: |
      server {
          listen 80;
          root /var/www/html;
          index index.html;
      }

runcmd:
  - systemctl enable nginx
  - systemctl start nginx
  - ufw allow 'Nginx Full'
```

### Database server

```yaml
#cloud-config

packages:
  - mysql-server
  - mysql-client

write_files:
  - path: /etc/mysql/mysql.conf.d/custom.cnf
    content: |
      [mysqld]
      bind-address = 0.0.0.0
      innodb_buffer_pool_size = 1G

runcmd:
  - systemctl enable mysql
  - systemctl start mysql
  - mysql -e "CREATE DATABASE myapp;"
  - mysql -e "CREATE USER 'app'@'%' IDENTIFIED BY 'secretpass';"
  - mysql -e "GRANT ALL ON myapp.* TO 'app'@'%';"
```

### Docker host

```yaml
#cloud-config

package_update: true
packages:
  - docker.io
  - docker-compose

users:
  - name: docker-user
    groups: [docker]
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ssh-rsa AAAAB3...

write_files:
  - path: /etc/docker/daemon.json
    content: |
      {
        "log-driver": "json-file",
        "log-opts": {"max-size": "10m", "max-file": "3"}
      }

runcmd:
  - systemctl enable docker
  - systemctl start docker
  - docker run hello-world
```

## Troubleshooting Modules

### Check module status

```bash
# See which modules ran
cloud-init status --long

# Check specific module logs
grep "cc_users_groups" /var/log/cloud-init.log

# Run single module for testing
sudo cloud-init single --name cc_runcmd --frequency once
```

### Module errors

```bash
# Look for module failures
grep -i "failed\|error" /var/log/cloud-init.log

# Check module configuration
cloud-init query --all | jq '.base_config'
```

### Debug mode

```bash
# Run cloud-init with debug output
sudo cloud-init --debug single --name cc_write_files
```

---

## 📚 More Information

- **Module reference**: [doc/rtd/reference/modules.rst](../doc/rtd/reference/modules.rst)
- **Module documentation**: [doc/module-docs/](../doc/module-docs/)
- **Example configurations**: [doc/rtd/reference/yaml_examples/](../doc/rtd/reference/yaml_examples/)
- **User/group examples**: [doc/rtd/reference/yaml_examples/index.rst](../doc/rtd/reference/yaml_examples/index.rst)
- **Base configuration**: [doc/rtd/reference/base_config_reference.rst](../doc/rtd/reference/base_config_reference.rst)
- **Boot stages**: [doc/rtd/explanation/boot.rst](../doc/rtd/explanation/boot.rst)
