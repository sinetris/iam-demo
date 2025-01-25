# Troubleshooting on macOS

[Back to README](README.md)

- [General considerations](#general-considerations)
  - [Networking](#networking)
  - [Remote Desktop](#remote-desktop)
- [Troubleshoot Multipass on macOS](#troubleshoot-multipass-on-macos)
  - [Files locations](#files-locations)
  - [Uninstall Multipass](#uninstall-multipass)
  - [Networking](#networking-1)
    - [Fivewall](#fivewall)
  - [Instances](#instances)
    - [QEMU](#qemu)
      - [Apple Silicon CPUs (aarch64)](#apple-silicon-cpus-aarch64)
      - [Intel CPUs (x86\_64)](#intel-cpus-x86_64)

## General considerations

### Networking

Apple tends to change the behaviour of macOS internal systems (firewalls,
other network systems, security authorisations and, essentially, all systems
that manage the underlying virtualisation infrastructure) in every update,
often without documenting the changes made and without taking into account
applications developed by third parties that rely on these internal systems.

This inevitably leads to unannounced interruptions in the operation of many
applications, especially those related to virtualisation, and delays in
identifying and resolving related problems.

### Remote Desktop

When connecting using RDP to the Linux Desktop virtual machine, it can happen
that scrolling in Firefox is too fast. To change the scrolling speed, follow
the instructions in [Mouse scrolling in Firefox](virtualmachines.md#mouse-scrolling-in-firefox).

## Troubleshoot Multipass on macOS

### Files locations

- Multipass CLI and configuration files: `/Library/Application\ Support/com.canonical.multipass/`
- Generated virtual machines and ssh keys: `/var/root/Library/Application\ Support/multipassd/`
- Logs: `/Library/Logs/Multipass/multipassd.log`

```shell
tail -f /Library/Logs/Multipass/multipassd.log
```

### Uninstall Multipass

```sh
sudo sh "/Library/Application Support/com.canonical.multipass/uninstall.sh"
```

### Networking

The first place to check is the Multipass official documentation page on
[troubleshoot networking][multipass-troubleshoot-networking].

When configured to use QEMU on macOS, Multipass will make use of
`Hypervisor.framework` and will provide DHCP and DNS resolution using the
services `bootpd` and `mDNSResponder`. \
The auto-genereted configuration can be found in `/etc/bootpd.plist`.

Make sure that the `/var/db/dhcpd_leases` file does not contain duplicate
entries otherwise you may experience strange behaviors.

To check for duplicate entries in `/var/db/dhcpd_leases`, run:

```shell
cat /var/db/dhcpd_leases | grep -E -o 'name=.+' | sort | uniq -c
```

If there are dupicates, edit `/var/db/dhcpd_leases` and remove them.

To remove all the dhcp leases you can delete the file content using:

```shell
sudo sh -c 'echo "" > /var/db/dhcpd_leases'
```

#### Fivewall

> Note: this shouldn't be needed anymore in recent versions.

Another problematic part is the firewall.

```shell
# Check if the firewall is enabled
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
# If the firewall is enabled, check that bootpd is allowed
/usr/libexec/ApplicationFirewall/socketfilterfw --listapps
# You can add bootpd to the allowed apps from the command line (requires admin privileges)
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /usr/libexec/bootpd
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblock /usr/libexec/bootpd
```

```shell
sudo tcpdump -i bridge100 udp port 67 and port 68
```

### Instances

#### QEMU

To list all running instances:

```shell
ps -ef | grep -i multipass | grep qemu
```

To terminate all running instances:

```shell
ps -ef | grep -i multipass | grep qemu | awk '{print "sudo kill -9 "$2}' | sh
```

##### Apple Silicon CPUs (aarch64)

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

##### Intel CPUs (x86_64)

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

[multipass-troubleshoot-networking]: <https://multipass.run/docs/troubleshoot-networking> "How to troubleshoot networking in Multipass"
