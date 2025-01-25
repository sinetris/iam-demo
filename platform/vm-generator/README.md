# VM creation

- [Multipass](#multipass)
  - [Setup](#setup)
  - [Remove all Multipass instances](#remove-all-multipass-instances)
  - [Get info](#get-info)
  - [Modify instances](#modify-instances)
- [Generate VMs configuration files](#generate-vms-configuration-files)
- [Manage VMs](#manage-vms)
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

## Generate VMs configuration files

```sh
# Set the Orchestrator to be used in the VM Generator
vm_generator_orchestrator=multipass
# Create a directory for the generated files
mkdir -p generated/assets/.ssh
# Create password hash
vm_admin_password=iamadmin
openssl passwd -6 -salt $(openssl rand -base64 8) "${vm_admin_password}" > generated/assets/admin_password
# Generate SSH keys for ansible
ssh-keygen -t ed25519 -C "automator@iam-demo.test" -f generated/assets/.ssh/id_ed25519 -q -N ""
# Generate VMs scripts
cp config.libsonnet.${vm_generator_orchestrator}.example config.libsonnet
jsonnet --create-output-dirs \
--multi ./generated \
--tla-str orchestrator_name="${vm_generator_orchestrator}" \
--string virtual-machines.jsonnet
# Generate and provision VMs
cd generated
chmod u+x *.sh
./vms-create.sh
./vms-setup.sh
./vms-provisioning.sh
```

## Manage VMs

```sh
cd generated
chmod u+x *.sh
# Create VMs
./vms-create.sh
# Basic setup
./vms-setup.sh
./vms-provisioning.sh
```

## Ubuntu ISO

[Live Server](https://cdimage.ubuntu.com/releases/24.04/release/ubuntu-24.04.1-live-server-arm64.iso)
[Cloud Image](https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-arm64.img)
