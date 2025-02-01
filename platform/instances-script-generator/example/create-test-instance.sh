#!/usr/bin/env bash
set -Eeuox pipefail

this_file_path=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

project_name=iam-demo
instances_network_name=${project_name:?}-HON
echo "Checking Network '${instances_network_name}'..."
instances_network_status=$(VBoxManage hostonlynet modify \
  --name ${instances_network_name} --enable 2>&1) && exit_code=$? || exit_code=$?
if [ $exit_code -eq 0 ]; then
  echo "✅ Instances Network '${instances_network_name}' already exist!"
elif [ $exit_code -eq 1 ] && [[ $instances_network_status =~ 'does not exist' ]]; then
  echo "Creating Network '${instances_network_name}'..."
  VBoxManage hostonlynet add \
    --name ${instances_network_name} \
    --netmask 255.255.255.0 \
    --lower-ip 192.168.100.1 \
    --upper-ip 192.168.100.100 \
    --enable
else
  echo "❌ Instances Network '${instances_network_name}' - exit code '${exit_code}'"
  echo ${instances_network_status}
  exit 2
fi

echo "Creating instances"
vbox_instance_name=testing-instance
echo "Checking '${vbox_instance_name:?}'..."
instance_status=$(VBoxManage showvminfo "${vbox_instance_name:?}" --machinereadable 2>&1) && exit_code=$? || exit_code=$?
if [ $exit_code -eq 0 ] && [[ $instance_status =~ 'VMState="started"' ]]; then
  echo "✅ Instance '${vbox_instance_name:?}' found!"
elif [ $exit_code -eq 0 ] && [[ $instance_status =~ 'VMState="poweroff"' ]]; then
  echo "✅ Instance '${vbox_instance_name:?}' already exist but the state us 'poweroff'!"
elif [ $exit_code -eq 0 ]; then
  echo "❌ Instance '${vbox_instance_name:?}' already exist but in UNMANAGED state!"
elif  [ $exit_code -eq 1 ] && [[ $instance_status =~ 'Could not find a registered machine' ]]; then
  vbox_architecture=arm
	# Ubuntu_arm64 | Ubuntu24_LTS_arm64
	vbox_instance_ostype=Ubuntu24_LTS_arm64
	vbox_basefolder=~/"VirtualBox VMs"
	vbox_project_basefolder=$HOME/.local/projects-data/${project_name:?}/${vbox_instance_name:?}
	vbox_instance_cidata_iso="${vbox_project_basefolder:?}/disks/seed.iso"
	vbox_instance_disk_file="${vbox_project_basefolder:?}/disks/boot-disk.vdi"
	# ubuntu-22.04.5-live-server-arm64.iso | ubuntu-24.04.1-live-server-arm64.iso
	vbox_iso_installer_file=~/virtualization/iso/ubuntu-24.04.1-live-server-arm64.iso
	vbox_guest_additions_iso=/Applications/VirtualBox.app/Contents/MacOS/VBoxGuestAdditions.iso
	vbox_instance_cidata_origin_path=${vbox_project_basefolder:?}/cidata
	mkdir -p "${vbox_project_basefolder:?}"/{cidata,disks,shared}
	_generated_instance_mac_address_nat=$(dd bs=1 count=3 if=/dev/random 2>/dev/null |  hexdump -vn3 -e '/3 "02:42:00"' -e '/1 ":%02X"')
	_generated_instance_mac_address_lab=$(dd bs=1 count=3 if=/dev/random 2>/dev/null |  hexdump -vn3 -e '/3 "02:42:00"' -e '/1 ":%02X"')
	# MAC Address in cloud-init network config is lowercase separated by colon
	vbox_instance_mac_address_nat_cloud_init=$(awk -v mac_address="${_generated_instance_mac_address_nat}" 'BEGIN {print tolower(mac_address)}')
	vbox_instance_mac_address_lab_cloud_init=$(awk -v mac_address="${_generated_instance_mac_address_lab}" 'BEGIN {print tolower(mac_address)}')
	# MAC Address in VirtualBox configuration is uppercase and without colon separator
	vbox_instance_mac_address_nat=$(awk -v mac_address="${_generated_instance_mac_address_nat}" 'BEGIN { gsub(/:/, "", mac_address); print toupper(mac_address) }')
	vbox_instance_mac_address_lab=$(awk -v mac_address="${_generated_instance_mac_address_lab}" 'BEGIN { gsub(/:/, "", mac_address); print toupper(mac_address) }')
	# Create cloud-init network configuration
	tee "${vbox_instance_cidata_origin_path:?}/network-config" > /dev/null <<-EOT
	  network:
	    version: 2
	    ethernets:
	      internet:
	        dhcp4: true
	        dhcp6: false
	        match:
	          macaddress: ${vbox_instance_mac_address_nat_cloud_init:?}
	        set-name: internet
	        nameservers:
	          addresses: [1.1.1.1]
	      lab:
	        dhcp4: true
	        dhcp6: false
	        match:
	          macaddress: ${vbox_instance_mac_address_lab_cloud_init:?}
	        set-name: lab
	        nameservers:
	          search:
	            - '${project_name:?}.test'
	          addresses: [1.1.1.1]
	EOT
	cat "cloud-init-${vbox_instance_name:?}.yaml" \
	  "${vbox_instance_cidata_origin_path:?}/network-config" \
	  > "${vbox_instance_cidata_origin_path:?}/user-data"
	# Create VirtualMachine
	VBoxManage createvm \
	  --name "${vbox_instance_name:?}" \
	  --platform-architecture ${vbox_architecture:?} \
	  --basefolder "${vbox_basefolder:?}" \
	  --ostype ${vbox_instance_ostype:?} \
	  --register
	# Set Screen scale to 200%
	VBoxManage setextradata \
	  "${vbox_instance_name:?}" \
	  'GUI/ScaleFactor' 2
	# Configure network
	VBoxManage modifyvm \
	  "${vbox_instance_name:?}" \
	  --groups "/${project_name:?}" \
	  --nic1 nat \
	  --mac-address1=${vbox_instance_mac_address_nat} \
	  --nic-type1 82540EM \
	  --cable-connected1 on \
	  --nic2 hostonlynet \
	  --host-only-net2 ${instances_network_name} \
	  --mac-address2=${vbox_instance_mac_address_lab} \
	  --nic-type2 82540EM \
	  --cable-connected2 on \
	  --nic-promisc2 allow-all
	# Create storage controllers
	_vbox_instance_scsi_controller_name="SCSI Controller"
	VBoxManage storagectl \
	  "${vbox_instance_name:?}" \
	  --name "${_vbox_instance_scsi_controller_name:?}" \
	  --add virtio \
		--controller VirtIO \
	  --bootable on
	# Configure the instance
	VBoxManage modifyvm \
	  "${vbox_instance_name:?}" \
	  --cpus "1" \
	  --memory "1024" \
	  --vram "64" \
	  --graphicscontroller vmsvga \
	  --audio-driver none \
	  --ioapic on \
	  --usbohci on \
	  --cpu-profile host
	# Create instance main disk
	VBoxManage createmedium disk \
	  --filename "${vbox_instance_disk_file:?}" \
	  --size 10240
	# Create cloud-init iso (set label as CIDATA)
	hdiutil makehybrid \
	  -o "${vbox_instance_cidata_iso:?}" \
	  -default-volume-name cidata \
	  -hfs \
	  -iso \
	  -joliet \
	  "${vbox_instance_cidata_origin_path:?}"
	# Attach main disk
	VBoxManage storageattach \
	  "${vbox_instance_name:?}" \
	  --storagectl "${_vbox_instance_scsi_controller_name:?}" \
	  --port 0 \
	  --device 0 \
	  --type hdd \
	  --medium "${vbox_instance_disk_file:?}"
	# Configure the instance boot order
	# VBoxManage modifyvm \
	#   "${vbox_instance_name:?}" \
	#   --boot1 disk \
	#   --boot2 dvd
	# Start Ubuntu autoinstall
	# Start type: none | gui | headless
	VBoxManage unattended install \
		"${vbox_instance_name:?}" \
		--iso "${vbox_iso_installer_file:?}" \
		--install-additions \
		--script-template "${vbox_instance_cidata_origin_path:?}/user-data" \
		--start-vm gui
	# VBoxManage startvm "${vbox_instance_name:?}" --type headless
else
  echo "❌ Instance '${vbox_instance_name:?}' - exit code '${exit_code}'"
  echo ${instance_status}
  exit 2
fi
