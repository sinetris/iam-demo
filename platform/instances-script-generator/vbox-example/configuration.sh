#!/usr/bin/env bash
set -Eeuo pipefail

# - Generic Project Settings -
project_name=iam-demo-test
project_domain="${project_name:?}.test"
projects_folder="$HOME/.local/projects/"
project_basefolder="${projects_folder:?}${project_name:?}"
os_release_codename=noble
host_public_key_file=~/.ssh/id_ed25519.pub
host_architecture=$(uname -m)

# - VirtualBox Project Settings -
os_images_url=https://cloud-images.ubuntu.com
os_images_path="$HOME/.cache/os-images"
project_network_name=${project_name:?}-HON
project_network_netmask=255.255.255.0
project_network_lower_ip=192.168.102.1
project_network_upper_ip=192.168.102.100

# Serial Port mode:
#   file = log boot sequence to file
vbox_instance_uart_mode=file
vbox_basefolder=~/"VirtualBox VMs"
# Start type: gui | headless | sdl | separate
vbox_instance_start_type=headless

# - Instance settings -
instance_name=testing-instance
instance_username=iamadmin
instance_password=iamadmin
# Disk size in MB
instance_storage_space=5120
instance_cpus=1
instance_memory=1024
instance_vram=64

instance_check_timeout_seconds=300
instance_check_sleep_time_seconds=2
instance_check_ssh_retries=5

instance_basefolder="${project_basefolder:?}/${instance_name:?}"
instance_cidata_files_path=${instance_basefolder:?}/cidata
instance_cidata_iso_file="${instance_basefolder:?}/disks/${instance_name:?}-cidata.iso"
instance_password_file="${instance_basefolder:?}/assets/admin-password-plain"
instance_password_hash_file="${instance_basefolder:?}/assets/admin-password-hash"
vbox_instance_disk_file="${instance_basefolder:?}/disks/${instance_name:?}-boot-disk.vdi"

case "${host_architecture:?}" in
	arm64|aarch64)
		vbox_architecture=arm
		guest_architecture=arm64
		vbox_additions_installer_file=VBoxLinuxAdditions-arm64.run
		;;
	amd64|x86_64)
		vbox_architecture=x86
		guest_architecture=amd64
		vbox_additions_installer_file=VBoxLinuxAdditions.run
		;;
	*)
		echo "❌ Unsupported 'host_architecture' value: '${host_architecture:?}'!" >&2
		exit 1
		;;
esac
