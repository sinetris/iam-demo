# Multipass

## Setup

```sh
brew install multipass
multipass get local.driver
multipass set local.driver=qemu
```

> On macOS, enable `Full Disk Access` for `multipassd` in `Provacy & Security`

## Generate configuration files

```sh
mkdir -p generated/.ssh
ssh-keygen -t ed25519 -C "automator@iam-demo.test" -f generated/.ssh/id_ed25519 -q -N ""
jsonnet --create-output-dirs \
  --multi ./generated \
  --tla-str orchestrator_name="multipass" \
  --string virtual-machines.jsonnet
cd generated
chmod u+x *.sh
./vms-bootstrap.sh
```

## Remove all Multipass instances

```sh
# Do NOT run if you have other multipass instances you want to keep
multipass delete --all
multipass purge
multipass list
```

## Get info

```sh
multipass info --format yaml 'linux-desktop'
multipass get --keys
multipass get local.linux-desktop.cpus
multipass get local.linux-desktop.memory
multipass get local.linux-desktop.disk
```

## Modify instances

```sh
multipass stop linux-desktop
multipass set local.linux-desktop.cpus=2
multipass set local.linux-desktop.memory=4.0GiB
multipass set local.linux-desktop.disk=10.0GiB
multipass start linux-desktop
```
