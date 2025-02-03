#cloud-config
chpasswd:
  expire: false
fqdn: "${_hostname}.${_domain}"
hostname: "${_hostname}"
manage_etc_hosts: true
package_reboot_if_required: true
package_update: true
package_upgrade: true
packages:
  - "apt-transport-https"
  - "build-essential"
  - "ca-certificates"
  - "curl"
  - "git"
  - "gnupg2"
  - "jq"
  - "linux-headers-generic"
  - "make"
  - "openssh-server"
  - "perl"
  - "python3-pip"
  - "python3-venv"
  - "python3"
  - "snapd"
  - "vim"
  - "wget"
prefer_fqdn_over_hostname: true
snap:
  commands:
    - ["install", "yq"]
users:
  - "default"
  - name: "${_username}"
    groups:
      - "adm"
      - "audio"
      - "cdrom"
      - "dialout"
      - "dip"
      - "floppy"
      - "lxd"
      - "netdev"
      - "plugdev"
      - "ssl-cert"
      - "staff"
      - "sudo"
      - "users"
      - "video"
      - "rdptest"
      - "vboxsf"
    lock_passwd: false
    passwd: "${_password_hash}"
    shell: "/bin/bash"
    ssh_import_id: [gh:sinetris]
    ssh_authorized_keys:
      - "${_public_key}"
    sudo: "ALL=(ALL) NOPASSWD:ALL"
write_files:
  - content: |
      File created!
    path: "/var/local/.test"
    permissions: "0o640"
runcmd:
  - mkdir -p /mnt/additions
  - mount -t iso9660 -o ro /dev/sr1 /mnt/additions
  - /mnt/additions/${_additions_file}
power_state:
  mode: reboot
  timeout: 30
  condition: true
final_message: |
  ## template: jinja
  cloud-init final message
  version: {{version}}
  timestamp: {{timestamp}}
  datasource: {{datasource}}
  uptime: {{uptime}}
