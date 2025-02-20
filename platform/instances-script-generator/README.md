# Instances creation

- [Multipass](#multipass)
  - [Setup](#setup)
  - [Remove all Multipass instances](#remove-all-multipass-instances)
  - [Get info](#get-info)
  - [Modify instances](#modify-instances)
- [Generate instances configuration files](#generate-instances-configuration-files)
- [Manage instances](#manage-instances)
- [Ubuntu ISO](#ubuntu-iso)
- [Development](#development)
  - [Troubleshooting](#troubleshooting)

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
instance_admin_password=ubuntu
openssl passwd -6 -salt $(openssl rand -base64 8) "${instance_admin_password}" > generated/assets/admin_password
# Generate SSH keys for ansible
ssh-keygen -t ed25519 -C "automator@iam-demo.test" -f generated/assets/.ssh/id_ed25519 -q -N ""
```

Generate instances management scripts:

```sh
# Set the project root path
project_root_path="$(cd ../../ && pwd)"
# Set the project generator path
project_generator_path="$(pwd)"
# Set the path for the generated files
generated_files_path="${project_root_path:?}/generated"
# Set the Orchestrator to be used in the Instances Generator script
generator_orchestrator=multipass
# Use 'arm64' for Apple silicon processors or 'amd64' for Intel and AMD 64bit CPUs
host_architecture=arm64
cp config/config.libsonnet.${generator_orchestrator}.example config/config.libsonnet
jsonnet --create-output-dirs \
  --multi "${generated_files_path}" \
  --ext-str project_root_path="${project_root_path}" \
  --ext-str orchestrator_name="${generator_orchestrator}" \
  --ext-str host_architecture="${host_architecture}" \
  --jpath "${project_root_path}" \
  --jpath "${project_generator_path}" \
  --jpath "${project_generator_path}/config" \
  --string "${project_generator_path}/instances.jsonnet"
chmod u+x "${generated_files_path}"/*.sh
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

## Development

### Troubleshooting

This script uses jsonnet.

Remember to check the correct use of `%` when using with string formatting or
interpolation (e.g. escape `%` using `%%`).

Examples:

```jsonnet
{
  my_float: 5.432,
  my_string: "something",
  string1: "my_float truncated is %(my_float)0.2f, my_string is %(my_string)s, and %% is escaped" % self,
  string2: "Concatenate to " + self.my_string + " without templates, and no need to escape %.",
  string3: |||
    When using templates in text blocks, like for %s or %d, we need to escape %%.
  ||| % ["some text", 5+10],
  string4: |||
    Text block and no templates?
    No need to escape %!
  |||,
}
```

```json
{
  "my_float": 5.432,
  "my_string": "something",
  "string1": "my_float truncated is 5.43, my_string is something, and % is escaped",
  "string2": "Concatenate to something without templates, and no need to escape %.",
  "string3": "When using templates in text blocks, like for some text or 15, we need to escape %.\n",
  "string4": "Text block and no templates?\nNo need to escape %!\n"
}
```

If you see a message like `RUNTIME ERROR: Unrecognised conversion type` and a stack
trace hard to debug, it's likely that you're missing a conversion type specifier
for `%` (see Python documentation for [printf-style String Formatting][python-printf-style]).

To reduce the number of lines to check, we can use `awk` to get all the lines
containing `%` and filter out those that should be correct.

```sh
file_to_check=lib/orchestrators/vbox.libsonnet
awk '/%/ && !/\|\|\| %|%(\([a-zA-Z0-9_]+\)){0,1}(0| |-|\+){0,1}[0-9]*(\.[0-9]+){0,1}(h|l|L){0,1}[diouxXeEfFgGcrs]/ {print NR, $0}' "${file_to_check:?}
```

[python-printf-style]: <https://docs.python.org/3/library/stdtypes.html#printf-style-string-formatting> "printf-style String Formatting"
