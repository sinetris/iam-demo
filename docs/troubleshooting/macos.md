# Troubleshooting on macOS

[Back to README](README.md)

- [General considerations](#general-considerations)
  - [Networking on macOS](#networking-on-macos)
  - [Remote Desktop](#remote-desktop)
- [Troubleshoot Multipass on macOS](#troubleshoot-multipass-on-macos)
  - [Files locations](#files-locations)
  - [Uninstall Multipass](#uninstall-multipass)
  - [Networking errors](#networking-errors)
    - [Errors connecting to instances](#errors-connecting-to-instances)
    - [Check that there is traffic on the network interface](#check-that-there-is-traffic-on-the-network-interface)
    - [Get the interface used for DHCP](#get-the-interface-used-for-dhcp)
    - [Capture DHCP traffic](#capture-dhcp-traffic)
    - [Fivewall](#fivewall)
  - [Instances](#instances)
    - [QEMU](#qemu)
      - [Apple Silicon CPUs (aarch64)](#apple-silicon-cpus-aarch64)
      - [Intel CPUs (x86\_64)](#intel-cpus-x86_64)

## General considerations

This troubleshooting documentation is specific to **macOS**.

### Networking on macOS

Apple tends to change the behavior of macOS internal systems (firewalls,
other network systems, security authorisations, and essentially all the systems
that manage the underlying virtualization infrastructure) in every update,
often without documenting the changes made and without taking into account
applications developed by third parties that rely on these internal systems.

This inevitably leads to unannounced disruptions in the operation of many
applications, especially those related to virtualization, and delays in
identifying and resolving related problems.

### Remote Desktop

When connecting using RDP to the Linux Desktop instance, it can happen
that scrolling in Firefox is too fast. To change the scrolling speed, follow
the instructions in [Mouse scrolling in Firefox](instances.md#mouse-scrolling-in-firefox).

## Troubleshoot Multipass on macOS

### Files locations

- Multipass CLI and configuration files: `/Library/Application\ Support/com.canonical.multipass/`
- Generated instancess and ssh keys: `/var/root/Library/Application\ Support/multipassd/`
- Logs: `/Library/Logs/Multipass/multipassd.log`

```shell
tail -f /Library/Logs/Multipass/multipassd.log
```

### Uninstall Multipass

```sh
sudo sh "/Library/Application Support/com.canonical.multipass/uninstall.sh"
```

### Networking errors

The first place to check is the Multipass official documentation page on
[troubleshoot networking][multipass-troubleshoot-networking].

When Multipass is configured to use QEMU, it will make use of
`Hypervisor.framework` and will provide DHCP and DNS resolution using the
services `bootpd` and `mDNSResponder`. \
The configuration for `bootpd` can be found in `/etc/bootpd.plist` and
`/System/Library/LaunchDaemons/bootps.plist`.\
The subnet used by `bootpd` (DHCP server) can be found in
`/Library/Preferences/SystemConfiguration/com.apple.vmnet.plist`.
> **Note:** Multipass requires the subnet to be part of the `192.168/16` CIDR.

Make sure that the `/var/db/dhcpd_leases` file does not contain duplicate
entries otherwise you may experience strange behaviors.

To check for duplicate entries in `/var/db/dhcpd_leases`, run:

```shell
cat /var/db/dhcpd_leases | grep -E -o 'name=.+' | sort | uniq -c
```

#### Errors connecting to instances

If there are dupicates in `/var/db/dhcpd_leases`, remove them keeping the ones
with the mac address from the following command.

```sh
# Get the Multipass instances MAC Address
sudo cat /var/root/Library/Application\ Support/multipassd/qemu/multipassd-vm-instances.json | grep -F 'mac_addr'
```

If you want to destroy and recreate all instances, you need to remove
the existing dhcp leases for `ansible-controller`, `iam-control-plane`,
and `linux-desktop`.

Run the following command:

```shell
cat /var/db/dhcpd_leases | grep -E -o 'name=.+' | sort | uniq
```

If it shows **only** the following output, you can delete the entire file content.

```text
name=ansible-controller
name=iam-control-plane
name=linux-desktop
```

To delete all the `/var/db/dhcpd_leases` file content, use:

```shell
sudo sh -c 'echo "" > /var/db/dhcpd_leases'
```

Otherwise edit the file and remove all occurrences of `ansible-controller`,
`iam-control-plane`, and `linux-desktop`.

#### Check that there is traffic on the network interface

> **Note:** When you create an instance, Multipass will create a bridge interface
> named `bridge100` (if it doesn't exist) and will remove the bridge interface if
> there are no running instances.

You can use `tcpdump` to check if there is any traffic on the network interface
used by Multipass.

```sh
# Multipass default is 'bridge100'
network_interface=bridge100
# Ensure that the interface exists
# (remember that you need at least one running instance or Multipass will remove the interface)
ifconfig ${network_interface:?}
# Capture all traffic
sudo tcpdump -n -i ${network_interface:?}
```

#### Get the interface used for DHCP

```sh
# Get the IP address and netmask used in the DHCP server
dhcp_server_ip=$(sudo defaults read /Library/Preferences/SystemConfiguration/com.apple.vmnet.plist Shared_Net_Address)
dhcp_server_netmask=$(sudo defaults read /Library/Preferences/SystemConfiguration/com.apple.vmnet.plist Shared_Net_Mask)
# Get the route for the IP addresses
dhcp_server_route=$(route -n get "${dhcp_server_ip:?}")
# Ensure that the route destination for DHCP server IP is not 'default'
if [[ "${dhcp_server_route:?}" =~ "destination: default" ]]; then
  (echo "Error: ${dhcp_server_ip:?} routing to destination default." >&2; false);
else
  network_interface=$(echo "${dhcp_server_route:?}" | grep -F "interface:" | cut -c 14-)
  echo "Using '${network_interface:?}' for DHCP on '${dhcp_server_ip:?}/${dhcp_server_netmask:?}'"
fi
```

#### Capture DHCP traffic

```shell
network_interface=bridge100
# Ensure that the interface exists
# (remember that you need at least one running instance or Multipass will remove the interface)
ifconfig ${network_interface:?}
# Sow DHCP traffic on the interface
sudo tcpdump -nvvi ${network_interface:?} 'port 67 and port 68'
```

Start a new instance in Multipass and check the previous command output.

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
  -m 1024M \
  -qmp stdio \
  -machine virt,gic-version=3 \
  -cdrom /var/root/Library/Application\ Support/multipassd/qemu/vault/instances/nrmdev/cloud-init-config.iso
```

##### Intel CPUs (x86_64)

```shell
sudo /Library/Application\ Support/com.canonical.multipass/bin/qemu-system-x86_64 \
  -accel hvf \
  -drive file=/Library/Application\ Support/com.canonical.multipass/Resources/qemu/edk2-x86_64-code.fd,if=pflash,format=raw,readonly=on \
  -cpu host \
  -nic vmnet-shared,model=virtio-net-pci,mac=52:54:00:44:26:6e \
  -device virtio-scsi-pci,id=scsi0 \
  -drive file=/var/root/Library/Application\ Support/multipassd/qemu/vault/instances/primary/ubuntu-22.04-server-cloudimg-amd64.img,if=none,format=qcow2,discard=unmap,id=hda \
  -device scsi-hd,drive=hda,bus=scsi0.0 \
  -smp 1 \
  -m 1024M \
  -qmp stdio \
  -cdrom /var/root/Library/Application\ Support/multipassd/qemu/vault/instances/primary/cloud-init-config.iso
```

[multipass-troubleshoot-networking]: <https://multipass.run/docs/troubleshoot-networking> "How to troubleshoot networking in Multipass"
