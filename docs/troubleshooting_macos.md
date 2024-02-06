# Troubleshoot Multipass on macOS

Apple tends to change the behavior of macOS internal systems (firewalls,
networking, security permissions, and essentially all systems that manage
the underlying virtualization infrastructure) in every update, without
documenting the changes made and without taking into account applications
developed by third parties that rely on these internal systems.

This inevitably leads to compromised operation of many applications,
especially those related to virtualization.

## Files location

`/Library/Application\ Support/com.canonical.multipass`
`/Library/Application\ Support/com.canonical.multipass/bin/`
`/Library/Application\ Support/com.canonical.multipass/Resources/`


### qemu aarch64

```shell
sudo /Library/Application\ Support/com.canonical.multipass/bin/qemu-system-aarch64 \
  -accel hvf \
  -drive file=/Library/Application\ Support/com.canonical.multipass/Resources/qemu/edk2-aarch64-code.fd,if=pflash,format=raw,readonly=on \
  -cpu host \
  -nic vmnet-shared,model=virtio-net-pci,mac=52:54:00:2a:97:15 \
  -device virtio-scsi-pci,id=scsi0 \
  -drive file=/var/root/Library/Application\ Support/multipassd/qemu/vault/instances/nrmdev/ubuntu-20.04-server-cloudimg-arm64.img,if=none,format=qcow2,discard=unmap,id=hda \
  -device scsi-hd,drive=hda,bus=scsi0.0 \
  -smp 1 \
  -m 12288M \
  -qmp stdio \
  -machine virt,gic-version=3 \
  -cdrom /var/root/Library/Application\ Support/multipassd/qemu/vault/instances/nrmdev/cloud-init-config.iso
```

### qemu x86_64

```shell
/Library/Application Support/com.canonical.multipass/bin/qemu-system-x86_64 \
  -accel hvf \
  -drive file=/Library/Application Support/com.canonical.multipass/Resources/qemu/edk2-x86_64-code.fd,if=pflash,format=raw,readonly=on \
  -cpu host \
  -nic vmnet-shared,model=virtio-net-pci,mac=52:54:00:44:26:6e \
  -device virtio-scsi-pci,id=scsi0 \
  -drive file=/var/root/Library/Application Support/multipassd/qemu/vault/instances/primary/ubuntu-22.04-server-cloudimg-amd64.img,if=none,format=qcow2,discard=unmap,id=hda \
  -device scsi-hd,drive=hda,bus=scsi0.0 \
  -smp 1 \
  -m 1024M \
  -qmp stdio \
  -chardev null,id=char0 \
  -serial chardev:char0 \
  -nographic \
  -cdrom /var/root/Library/Application Support/multipassd/qemu/vault/instances/primary/cloud-init-config.iso

```

```shell
/Library/Application\ Support/com.canonical.multipass/Resources/com.canonical.multipassd.plist
/Library/Application\ Support/com.canonical.multipass/Resources/com.canonical.multipass.gui.autostart.plist
```

## Logs

The first place to look in case Multipass starts misbehaving is in the
logs found in `/Library/Logs/Multipass/multipassd.log`.

## Networking

The first place to check is the Multipass official documentation page on
[troubleshoot networking][multipass-troubleshoot-networking].

When configured to use QEMU on macOS, Multipass will make use of
`Hypervisor.framework` and will provide DHCP and DNS resolution using the
services `bootpd` and `mDNSResponder`. \
The auto-genereted configuration can be found in `/etc/bootpd.plist`.

Make sure that the `/var/db/dhcpd_leases` file does not contain duplicate
entries otherwise you may experience strange behavior.

To check for duplicate entries in `/var/db/dhcpd_leases`, run:

```shell
cat /var/db/dhcpd_leases | grep -E -o 'name=.+' | sort | uniq -c
```

[multipass-troubleshoot-networking]: <https://multipass.run/docs/troubleshoot-networking> "How to troubleshoot networking in Multipass"

## Instances

### QEMU

To list all running instances:

```shell
ps -ef | grep -i multipass | grep qemu
```

To terminate all running instances:

```shell
ps -ef | grep -i multipass | grep qemu | awk '{print "sudo kill -9 "$2}' | sh
```
