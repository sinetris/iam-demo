# Instances creation

- [Multipass](#multipass)
  - [Setup](#setup)
  - [Remove all Multipass instances](#remove-all-multipass-instances)
  - [Get info](#get-info)
  - [Modify instances](#modify-instances)
- [Generate instances configuration files](#generate-instances-configuration-files)
- [Manage instances](#manage-instances)
- [Ubuntu ISO](#ubuntu-iso)

## Multipass

### Setup

```sh
brew install multipass
multipass get local.driver
multipass set local.driver=qemu
```

> On macOS, enable `Full Disk Access` for `multipassd` in `Provacy & Security`

### Remove all Multipass instances

```sh
# Do NOT run if you have other multipass instances you want to keep
multipass delete --all
multipass purge
multipass list
```

### Get info

```sh
multipass info --format yaml 'linux-desktop'
multipass get --keys
multipass get local.linux-desktop.cpus
multipass get local.linux-desktop.memory
multipass get local.linux-desktop.disk
```

### Modify instances

```sh
multipass stop linux-desktop
multipass set local.linux-desktop.cpus=2
multipass set local.linux-desktop.memory=4.0GiB
multipass set local.linux-desktop.disk=10.0GiB
multipass start linux-desktop
```

## Generate instances configuration files

Generate admin password and ansible ssh keys:

```sh
# Create a directory for the generated files
mkdir -p generated/assets/.ssh
# Create password hash
instance_admin_password=iamadmin
openssl passwd -6 -salt $(openssl rand -base64 8) "${instance_admin_password}" > generated/assets/admin_password
# Generate SSH keys for ansible
ssh-keygen -t ed25519 -C "automator@iam-demo.test" -f generated/assets/.ssh/id_ed25519 -q -N ""
```

Generate instances management scripts:

```sh
# Set the Orchestrator to be used in the Instances Generator script
instances_generator_orchestrator=multipass
# Use 'arm64' for Apple silicon processors or 'amd64' for Intel and AMD 64bit CPUs
host_architecture=arm64
cp config.libsonnet.${instances_generator_orchestrator}.example config.libsonnet
jsonnet --create-output-dirs \
--multi ./generated \
--tla-str orchestrator_name="${instances_generator_orchestrator}" \
--ext-str architecture="${host_architecture}" \
--string virtual-machines.jsonnet
```

## Manage instances

```sh
cd generated
chmod u+x *.sh
# Create instances
./instances-create.sh
# Basic setup
./instances-setup.sh
# Automated provisioning
./instances-provisioning.sh
# Get all instances status
./instances-status.sh
# Get status for a specific instance
./instances-status.sh ansible-controller
# Get info for a specific instance
./instance-info.sh ansible-controller
# Get console for a specific instance
./instance-shell.sh ansible-controller
```

To destroy all instances and the generated project folder:

```sh
./instances-destroy.sh
```

## Ubuntu ISO

[Live Server](https://cdimage.ubuntu.com/releases/24.04/release/ubuntu-24.04.1-live-server-arm64.iso)
[Cloud Image](https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-arm64.img)
