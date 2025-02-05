#!/usr/bin/env bash
set -Eeuo pipefail

project_name=iam-demo-test
project_domain="${project_name:?}.test"
instance_name=testing-instance
instance_username=iamadmin
instance_password=iamadmin
project_network_netmask=255.255.255.0
project_network_lower_ip=192.168.102.1
project_network_upper_ip=192.168.102.100
# Disk size in MB
instance_disk_size=5120
os_images_path="$HOME/.cache/os-images"
os_release_codename=noble
projects_folder="$HOME/.local/projects/"
host_public_key_file=~/.ssh/id_ed25519.pub
# VirtualBox platform architecture: x86 | arm
vbox_architecture=arm

instance_check_timeout_seconds=300
instance_check_sleep_time_seconds=2
instance_check_ssh_retries=5
instance_check_debug=true
# Start type: gui | headless | sdl | separate
vbox_instance_start_type=headless

os_images_url=https://cloud-images.ubuntu.com

if [ "${vbox_architecture}" == 'arm' ]; then
	vbox_additions_installer_file=VBoxLinuxAdditions-arm64.run
elif [ "${vbox_architecture}" == 'x86' ]; then
	vbox_additions_installer_file=VBoxLinuxAdditions.run
else
	echo "❌ Invalid 'vbox_architecture' value: '${vbox_architecture:?}' - Should be 'x86' or 'arm'!" >&2
	exit 1
fi

# Serial Port mode:
#   file = log boot sequence to file
vbox_instance_uart_mode=file
project_network_name=${project_name:?}-HON
vbox_basefolder=~/"VirtualBox VMs"

project_basefolder="${projects_folder:?}${project_name:?}"
instance_basefolder="${project_basefolder:?}/${instance_name:?}"
instance_cidata_files_path=${instance_basefolder:?}/cidata
instance_cidata_iso_file="${instance_basefolder:?}/disks/${instance_name:?}-cidata.iso"
instance_password_file="${instance_basefolder:?}/assets/admin-password-plain"
instance_password_hash_file="${instance_basefolder:?}/assets/admin-password-hash"
vbox_instance_disk_file="${instance_basefolder:?}/disks/${instance_name:?}-boot-disk.vdi"
