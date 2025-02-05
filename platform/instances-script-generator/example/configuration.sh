#!/usr/bin/env bash
set -Eeuo pipefail

project_name=iam-demo-test
project_domain="${project_name:?}.test"
vbox_instance_name=testing-instance
vbox_instance_username=iamadmin
vbox_instance_password=iamadmin
project_network_netmask=255.255.255.0
project_network_lower_ip=192.168.102.1
project_network_upper_ip=192.168.102.100
# Disk size in MB
vbox_instance_disk_size=5120
os_images_path="$HOME/.cache/os-images"
os_release_codename=noble
vbox_projects_folder="$HOME/.local/projects/"
vbox_instance_public_key_file=~/.ssh/id_ed25519.pub
# VirtualBox platform architecture: x86 | arm
vbox_architecture=arm

instance_check_timeout_seconds=300
instance_check_sleep_time_seconds=2
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

vbox_project_basefolder="${vbox_projects_folder:?}${project_name:?}"
vbox_instance_basefolder="${vbox_project_basefolder:?}/${vbox_instance_name:?}"
vbox_instance_disk_file="${vbox_instance_basefolder:?}/disks/${vbox_instance_name:?}-boot-disk.vdi"
vbox_instance_cidata_files_path=${vbox_instance_basefolder:?}/cidata
vbox_instance_cidata_disk_file="${vbox_instance_basefolder:?}/disks/${vbox_instance_name:?}-cidata.iso"
vbox_instance_password_file="${vbox_instance_basefolder:?}/assets/admin-password-plain"
vbox_instance_password_hash_file="${vbox_instance_basefolder:?}/assets/admin-password-hash"
