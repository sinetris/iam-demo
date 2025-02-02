#!/usr/bin/env bash
set -Eeuo pipefail

this_file_path=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "${this_file_path}/configuration.sh"

echo "Checking Network '${project_network_name}'..."
project_network_status=$(VBoxManage hostonlynet modify \
  --name ${project_network_name} --enable 2>&1) && exit_code=$? || exit_code=$?
if [[ $exit_code -eq 0 ]]; then
	echo " ✅ Project Network '${project_network_name}' already exist!"
elif [[ $exit_code -eq 1 ]] && [[ $project_network_status =~ 'does not exist' ]]; then
	echo " ⚙️ Creating Project Network '${project_network_name}'..."
	VBoxManage hostonlynet add \
	  --name ${project_network_name} \
	  --netmask ${project_network_netmask:?} \
	  --lower-ip ${project_network_lower_ip:?} \
	  --upper-ip ${project_network_upper_ip:?} \
	  --enable
else
	echo " ❌ Project Network '${project_network_name}' - exit code '${exit_code}'"
	echo ${project_network_status}
	exit 2
fi

echo "Creating instances"
echo "Checking '${vbox_instance_name:?}'..."
instance_status=$(VBoxManage showvminfo "${vbox_instance_name:?}" --machinereadable 2>&1) && exit_code=$? || exit_code=$?
_create_instance=false
if [[ $exit_code -eq 0 ]] && ( \
	[[ $instance_status =~ 'VMState="started"' ]] \
	|| [[ $instance_status =~ 'VMState="running"' ]] \
); then
	echo "✅ Instance '${vbox_instance_name:?}' found!"
elif [[ $exit_code -eq 0 ]] && [[ $instance_status =~ 'VMState="poweroff"' ]]; then
	echo "✅ Instance '${vbox_instance_name:?}' already exist but the state us 'poweroff'!"
elif [[ $exit_code -eq 0 ]]; then
	echo "❌ Instance '${vbox_instance_name:?}' already exist but in UNMANAGED state!" >&2
	echo ${instance_status} >&2
	exit 1
elif [[ $exit_code -eq 1 ]] && [[ $instance_status =~ 'Could not find a registered machine' ]]; then
	echo "⚙️ Instance '${vbox_instance_name:?}' will be created!"
	_create_instance='true'
else
	echo "❌ Instance '${vbox_instance_name:?}' - exit code '${exit_code}'"
	echo ${instance_status}
	exit 2
fi

if [ "${_create_instance}" == 'true' ]; then
	echo "⚙️ Creating Instance '${vbox_instance_name:?}' ..."
	echo " - Create Project data folder (and required subfolders): '${vbox_project_basefolder:?}'"
	mkdir -p "${vbox_instance_basefolder:?}"/{cidata,disks,shared,tmp,assets}
	echo "${vbox_instance_password:?}" > "${vbox_instance_password_file:?}"
	openssl passwd -6 -salt $(openssl rand -base64 8) "${vbox_instance_password}" > "${vbox_instance_password_hash_file:?}"
	vbox_instance_password_hash=$(cat "${vbox_instance_password_hash_file:?}")
	vbox_instance_public_key=$(cat "${vbox_instance_public_key_file:?}")
	echo " - Create cloud-init configuration"
	_generated_instance_mac_address_nat=$(dd bs=1 count=3 if=/dev/random 2>/dev/null |  hexdump -vn3 -e '/3 "02:42:00"' -e '/1 ":%02X"')
	_generated_instance_mac_address_lab=$(dd bs=1 count=3 if=/dev/random 2>/dev/null |  hexdump -vn3 -e '/3 "02:42:00"' -e '/1 ":%02X"')
	# MAC Address in cloud-init network config is lowercase separated by colon
	vbox_instance_mac_address_nat_cloud_init=$(awk -v mac_address="${_generated_instance_mac_address_nat}" 'BEGIN {print tolower(mac_address)}')
	vbox_instance_mac_address_lab_cloud_init=$(awk -v mac_address="${_generated_instance_mac_address_lab}" 'BEGIN {print tolower(mac_address)}')
	# MAC Address in VirtualBox configuration is uppercase and without colon separator
	vbox_instance_mac_address_nat=$(awk -v mac_address="${_generated_instance_mac_address_nat}" 'BEGIN { gsub(/:/, "", mac_address); print toupper(mac_address) }')
	vbox_instance_mac_address_lab=$(awk -v mac_address="${_generated_instance_mac_address_lab}" 'BEGIN { gsub(/:/, "", mac_address); print toupper(mac_address) }')
	echo "   - Create cloud-init 'network-config'"
	export project_domain
	export vbox_instance_mac_address_nat_cloud_init
	export vbox_instance_mac_address_lab_cloud_init
	envsubst '$project_domain,$vbox_instance_mac_address_nat_cloud_init,$vbox_instance_mac_address_lab_cloud_init' \
		<"cloud-init-user-network-config.yaml.tpl" | tee "${vbox_instance_cidata_origin_path:?}/network-config"
	echo "   - Create cloud-init 'meta-data'"
	tee "${vbox_instance_cidata_origin_path:?}/meta-data" > /dev/null <<-EOT
	instance-id: i-${vbox_instance_name:?}
	local-hostname: ${vbox_instance_name:?}
	EOT
	echo "   - Create cloud-init 'user-data'"
	export project_domain
	export vbox_instance_name
	export vbox_instance_username
	export vbox_instance_password_hash
	export vbox_instance_public_key
	export vbox_additions_file
	envsubst '$project_domain,$vbox_instance_name,$vbox_instance_username,$vbox_instance_password_hash,$vbox_instance_public_key,$vbox_additions_file' \
		<"cloud-init-user-data.yaml.tpl" | tee "${vbox_instance_cidata_origin_path:?}/user-data"
	echo " - Create VirtualMachine"
	VBoxManage createvm \
	  --name "${vbox_instance_name:?}" \
	  --platform-architecture ${vbox_architecture:?} \
	  --basefolder "${vbox_basefolder:?}" \
	  --ostype ${vbox_instance_ostype:?} \
	  --register
	echo " - Set Screen scale to 200%"
	VBoxManage setextradata \
	  "${vbox_instance_name:?}" \
	  'GUI/ScaleFactor' 2
	echo " - Configure network for instance"
	VBoxManage modifyvm \
	  "${vbox_instance_name:?}" \
	  --groups "/${project_name:?}" \
	  --nic1 nat \
	  --mac-address1=${vbox_instance_mac_address_nat} \
	  --nic-type1 82540EM \
	  --cable-connected1 on \
	  --nic2 hostonlynet \
	  --host-only-net2 ${project_network_name} \
	  --mac-address2=${vbox_instance_mac_address_lab} \
	  --nic-type2 82540EM \
	  --cable-connected2 on \
	  --nic-promisc2 allow-all
	echo " - Create storage controllers"
	_vbox_instance_scsi_controller_name="SCSI Controller"
	VBoxManage storagectl \
	  "${vbox_instance_name:?}" \
	  --name "${_vbox_instance_scsi_controller_name:?}" \
	  --add virtio \
	  --controller VirtIO \
	  --bootable on
	echo " - Configure the instance"
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
	echo " - Create instance main disk cloning ${vbox_img_original_file:?}"
	VBoxManage clonemedium disk \
	  "${origin_images_path}/${vbox_img_original_file:?}" \
	  "${vbox_instance_disk_file:?}" \
	  --format VDI \
	  --variant Standard
	echo " - Resize instance main disk to '${vbox_instance_disk_size:?} MB'"
	VBoxManage modifymedium disk \
	  "${vbox_instance_disk_file:?}" \
	  --resize ${vbox_instance_disk_size:?}
	echo " - Attach main disk to instance"
	VBoxManage storageattach \
	  "${vbox_instance_name:?}" \
	  --storagectl "${_vbox_instance_scsi_controller_name:?}" \
	  --port 0 \
	  --device 0 \
	  --type hdd \
	  --medium "${vbox_instance_disk_file:?}"
	echo " - Create cloud-init iso (set label as CIDATA)"
	hdiutil makehybrid \
	  -o "${vbox_instance_cidata_iso:?}" \
	  -default-volume-name CIDATA \
	  -hfs \
	  -iso \
	  -joliet \
	  "${vbox_instance_cidata_origin_path:?}"
	echo " - Attach cloud-init iso to instance"
	VBoxManage storageattach \
	  "${vbox_instance_name:?}" \
	  --storagectl "${_vbox_instance_scsi_controller_name:?}" \
	  --port 1 \
	  --device 0 \
	  --type dvddrive \
	  --medium "${vbox_instance_cidata_iso:?}" \
	  --comment "cloud-init data for ${vbox_instance_name:?}"
	echo " - Attach Guest Addition iso installer to instance"
	# (Note: need to attach 'emptydrive' before 'additions' becuse VBOX is full of bugs)
	VBoxManage storageattach  \
	  "${vbox_instance_name:?}" \
	  --storagectl "${_vbox_instance_scsi_controller_name:?}" \
	  --port 2 \
	  --device 0 \
	  --type dvddrive \
	  --medium emptydrive
	VBoxManage storageattach  \
	  "${vbox_instance_name:?}" \
	  --storagectl "${_vbox_instance_scsi_controller_name:?}" \
	  --port 2 \
	  --device 0 \
	  --type dvddrive \
	  --medium additions
	echo " - Configure the VM boot order"
	VBoxManage modifyvm \
	  "${vbox_instance_name:?}" \
	  --boot1 disk \
	  --boot2 dvd
	if [ "${vbox_instance_uart_mode}" == "file" ]; then
		vbox_instance_uart_file="${vbox_instance_basefolder:?}/tmp/tty0.log"
		echo " - Set Serial Port to log boot sequence"
		touch "${vbox_instance_uart_file:?}"
		echo "   - To see log file:"
		echo "    tail -f -n +1 '${vbox_instance_uart_file:?}'"
		echo
		VBoxManage modifyvm \
		"${vbox_instance_name:?}" \
		  --uart1 0x3F8 4 \
		  --uartmode1 "${vbox_instance_uart_mode}" \
		  "${vbox_instance_uart_file:?}"
	else
		echo " - Ignore Serial Port settings"
		vbox_instance_uart_mode=file
		vbox_instance_uart_file=/dev/null
	fi
	echo " - Starting instance '${vbox_instance_name:?}' in mode '${vbox_instance_start_type:?}'"
	VBoxManage startvm "${vbox_instance_name:?}" --type "${vbox_instance_start_type:?}"
fi
