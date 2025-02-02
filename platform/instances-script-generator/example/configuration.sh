#!/usr/bin/env bash
set -Eeuo pipefail

this_file_path=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

project_name=iam-demo-test
vbox_instance_name=testing-instance
vbox_instance_username=iamadmin
vbox_instance_password=iamadmin
project_network_netmask=255.255.255.0
project_network_lower_ip=192.168.102.1
project_network_upper_ip=192.168.102.100
# Disk size in MB
vbox_instance_disk_size=5120
origin_images_path=~/virtualization/iso
vbox_instance_public_key_file=~/.ssh/id_ed25519.pub
# VirtualBox platform architecture: x86 | arm
vbox_architecture=arm

# Start type: gui | headless | sdl | separate
vbox_instance_start_type=headless

if [ "${vbox_architecture}" == 'arm' ]; then
	vbox_instance_ostype=Ubuntu24_LTS_arm64
	vbox_img_original_file=noble-server-cloudimg-arm64.img
	vbox_additions_file=VBoxLinuxAdditions-arm64.run
elif [ "${vbox_architecture}" == 'x86' ]; then
	vbox_instance_ostype=Ubuntu24_LTS_64
	vbox_img_original_file=noble-server-cloudimg-amd64.img
	vbox_additions_file=VBoxLinuxAdditions.run
else
	echo "❌ Invalid 'vbox_architecture' value: '${vbox_architecture:?}' - Should be 'x86' or 'arm'!" >&2
	exit 1
fi

project_domain="${project_name:?}.test"
# Serial Port mode:
#   file = log boot sequence to file
vbox_instance_uart_mode=file
project_network_name=${project_name:?}-HON

vbox_basefolder=~/"VirtualBox VMs"
vbox_project_basefolder="$HOME/.local/projects/${project_name:?}"
vbox_instance_basefolder="${vbox_project_basefolder:?}/${vbox_instance_name:?}"
vbox_instance_disk_file="${vbox_instance_basefolder:?}/disks/boot-disk-${vbox_instance_name:?}.vdi"
vbox_instance_cidata_origin_path=${vbox_instance_basefolder:?}/cidata
vbox_instance_cidata_iso="${vbox_instance_basefolder:?}/disks/seed.iso"
vbox_instance_password_file="${vbox_instance_basefolder:?}/assets/admin-password"
vbox_instance_password_hash_file="${vbox_instance_basefolder:?}/assets/admin-password-hash"
