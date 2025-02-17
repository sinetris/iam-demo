# Virtualbox

- [Useful commands from the host](#useful-commands-from-the-host)
- [Useful commands from the guest](#useful-commands-from-the-guest)

## Useful commands from the host

Select the instance.

```sh
instance_name=ansible-controller
```

Show configuration information or log file contents for a virtual machine.

```sh
VBoxManage showvminfo "${instance_name:?}"
```

Manage VirtualBox's "guest properties" from the host (the machine on which
instances run) for the specified instance.

```shell {filename="example.sh"}
# Lists guest properties and values
VBoxManage --nologo guestproperty enumerate "${instance_name:?}"
# Lists guest properties and values for network
vbox_guestpropery_pattern='/VirtualBox/GuestInfo/Net/*'
VBoxManage --nologo guestproperty enumerate "${instance_name:?}" \
  --no-timestamp --no-flags \
  "${vbox_guestpropery_pattern:?}"
# Get the name for the second network interface
vbox_guestpropery_pattern='/VirtualBox/GuestInfo/Net/1/Name'
VBoxManage --nologo guestproperty get "${instance_name:?}" \
  "${vbox_guestpropery_pattern:?}" \
  | awk '{print $2}'
```

## Useful commands from the guest

> **Note:** Guest Additions need to be installed in the instance.

Manage VirtualBox's "guest properties" from the guest (the virtual machine instance):

```sh
# Lists guest properties and values
sudo VBoxControl --nologo guestproperty enumerate
# Lists guest properties and values for network
sudo VBoxControl --nologo guestproperty enumerate --patterns '/VirtualBox/GuestInfo/Net/*'
# Get the name for the second network interface
sudo VBoxControl --nologo guestproperty get '/VirtualBox/GuestInfo/Net/1/Name'
```

List shared folders mappings:

```sh
sudo VBoxControl --nologo sharedfolder list
```

Lists guest properties in format `<name>=<value>` for OS:

```sh
vbox_guestpropery_pattern='/VirtualBox/GuestInfo/OS/*'
sudo VBoxControl --nologo \
  guestproperty enumerate \
  --patterns "${vbox_guestpropery_pattern:?}" \
  | awk -F", " '{NF = 2; sub(/^Name: .+\//, "", $1); sub(/^value: /, "", $2); print $1 "=" $2}' -
```
