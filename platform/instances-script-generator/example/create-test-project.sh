#!/usr/bin/env bash
set -Eeuo pipefail

_this_file_path=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

. "${_this_file_path}/configuration.sh"

echo "Checking Network '${project_network_name}'..."
_project_network_status=$(VBoxManage hostonlynet modify \
  --name ${project_network_name} --enable 2>&1) && _exit_code=$? || _exit_code=$?
if [[ $_exit_code -eq 0 ]]; then
	echo " ✅ Project Network '${project_network_name}' already exist!"
elif [[ $_exit_code -eq 1 ]] && [[ $_project_network_status =~ 'does not exist' ]]; then
	echo " ⚙️ Creating Project Network '${project_network_name}'..."
	VBoxManage hostonlynet add \
	  --name ${project_network_name} \
	  --netmask ${project_network_netmask:?} \
	  --lower-ip ${project_network_lower_ip:?} \
	  --upper-ip ${project_network_upper_ip:?} \
	  --enable
else
	echo " ❌ Project Network '${project_network_name}' - exit code '${_exit_code}'"
	echo ${_project_network_status}
	exit 2
fi

echo "Creating instances"
echo "Checking '${vbox_instance_name:?}'..."
_instance_status=$(VBoxManage showvminfo "${vbox_instance_name:?}" --machinereadable 2>&1) && _exit_code=$? || _exit_code=$?
_create_instance=false
if [[ $_exit_code -eq 0 ]] && ( \
	[[ $_instance_status =~ 'VMState="started"' ]] \
	|| [[ $_instance_status =~ 'VMState="running"' ]] \
); then
	echo "✅ Instance '${vbox_instance_name:?}' found!"
elif [[ $_exit_code -eq 0 ]] && [[ $_instance_status =~ 'VMState="poweroff"' ]]; then
	echo "✅ Instance '${vbox_instance_name:?}' already exist but the state us 'poweroff'!"
elif [[ $_exit_code -eq 0 ]]; then
	echo "❌ Instance '${vbox_instance_name:?}' already exist but in UNMANAGED state!" >&2
	echo ${_instance_status} >&2
	exit 1
elif [[ $_exit_code -eq 1 ]] && [[ $_instance_status =~ 'Could not find a registered machine' ]]; then
	echo "⚙️ Instance '${vbox_instance_name:?}' will be created!"
	_create_instance='true'
else
	echo "❌ Instance '${vbox_instance_name:?}' - exit code '${_exit_code}'"
	echo ${_instance_status}
	exit 2
fi

if [ "${_create_instance}" == 'true' ]; then
	echo "⚙️ Creating Instance '${vbox_instance_name:?}' ..."
	vbox_os_mapping_file="${_this_file_path}/../assets/vbox_os_mapping.json"
	vbox_instance_ostype=$(jq -L "${_this_file_path}/../lib/jq/modules" \
		--arg architecture "${vbox_architecture:?}" \
		--arg os_release "${os_release_codename:?}" \
		--arg select_field "os_type" \
		--raw-output \
		--from-file "${_this_file_path}/../lib/jq/filrters/get_vbox_mapping_value.jq" \
		"${vbox_os_mapping_file:?}" 2>&1) && _exit_code=$? || _exit_code=$?

	if [[ $_exit_code -ne 0 ]]; then
		echo " ❌ Could not get 'os_type'"
		echo "${vbox_instance_ostype}"
		exit 2
	fi

	os_release_file=$(jq -L "${_this_file_path}/../lib/jq/modules" \
		--arg architecture "${vbox_architecture:?}" \
		--arg os_release "${os_release_codename:?}" \
		--arg select_field "os_release_file" \
		--raw-output \
		--from-file "${_this_file_path}/../lib/jq/filrters/get_vbox_mapping_value.jq" \
		"${vbox_os_mapping_file:?}" 2>&1) && _exit_code=$? || _exit_code=$?

	if [[ $_exit_code -ne 0 ]]; then
		echo " ❌ Could not get 'os_release_file'"
		echo "${os_release_file}"
		exit 2
	fi

	os_image_url="${os_images_url:?}/${os_release_codename:?}/current/${os_release_file:?}"

	os_image_path="${os_images_path}/${os_release_file:?}"
	echo " - Create Project data folder (and required subfolders): '${vbox_project_basefolder:?}'"
	mkdir -p "${vbox_instance_basefolder:?}"/{cidata,disks,shared,tmp,assets}
	if [ -f "${os_image_path:?}" ]; then
		echo "✅ Using existing '${os_release_file:?}' from '${os_image_path:?}'!"
	else
		echo " ⚙️ Downloading '${os_release_file:?}' from '${os_image_url:?}'..."
		mkdir -pv "${os_images_path:?}"
		curl --output "${os_image_path:?}" "${os_image_url:?}"
	fi
	echo "${vbox_instance_password:?}" > "${vbox_instance_password_file:?}"
	openssl passwd -6 -salt $(openssl rand -base64 8) "${vbox_instance_password}" > "${vbox_instance_password_hash_file:?}"
	_instance_password_hash=$(cat "${vbox_instance_password_hash_file:?}")
	_instance_public_key=$(cat "${vbox_instance_public_key_file:?}")
	echo " - Create cloud-init configuration"
	_generated_instance_mac_address_nat=$(dd bs=1 count=3 if=/dev/random 2>/dev/null |  hexdump -vn3 -e '/3 "02:42:00"' -e '/1 ":%02X"')
	_generated_instance_mac_address_lab=$(dd bs=1 count=3 if=/dev/random 2>/dev/null |  hexdump -vn3 -e '/3 "02:42:00"' -e '/1 ":%02X"')
	# MAC Address in cloud-init network config is lowercase separated by colon
	_instance_mac_address_nat_cloud_init=$(awk -v mac_address="${_generated_instance_mac_address_nat}" 'BEGIN {print tolower(mac_address)}')
	_instance_mac_address_lab_cloud_init=$(awk -v mac_address="${_generated_instance_mac_address_lab}" 'BEGIN {print tolower(mac_address)}')
	# MAC Address in VirtualBox configuration is uppercase and without colon separator
	_instance_mac_address_nat=$(awk -v mac_address="${_generated_instance_mac_address_nat}" 'BEGIN { gsub(/:/, "", mac_address); print toupper(mac_address) }')
	_instance_mac_address_lab=$(awk -v mac_address="${_generated_instance_mac_address_lab}" 'BEGIN { gsub(/:/, "", mac_address); print toupper(mac_address) }')
	echo "   - Create cloud-init 'network-config'"
	_domain="${project_domain}" \
	_mac_address_nat_cloud_init="${_instance_mac_address_nat_cloud_init}" \
	_mac_address_lab_cloud_init="${_instance_mac_address_lab_cloud_init}" \
	envsubst '$_domain,$_mac_address_nat_cloud_init,$_mac_address_lab_cloud_init' \
		<"cloud-init-user-network-config.yaml.tpl" | tee "${vbox_instance_cidata_files_path:?}/network-config"
	echo "   - Create cloud-init 'meta-data'"
	tee "${vbox_instance_cidata_files_path:?}/meta-data" > /dev/null <<-EOT
	instance-id: i-${vbox_instance_name:?}
	local-hostname: ${vbox_instance_name:?}
	EOT
	echo "   - Create cloud-init 'user-data'"
	_domain="${project_domain}" \
	_hostname="${vbox_instance_name}" \
	_username=${vbox_instance_username} \
	_password_hash=${_instance_password_hash} \
	_public_key=${_instance_public_key} \
	_additions_file=${vbox_additions_installer_file} \
	envsubst '$_domain,$_hostname,$_username,$_password_hash,$_public_key,$_additions_file' \
		<"cloud-init-user-data.yaml.tpl" | tee "${vbox_instance_cidata_files_path:?}/user-data"
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
	  --mac-address1=${_instance_mac_address_nat} \
	  --nic-type1 82540EM \
	  --cable-connected1 on \
	  --nic2 hostonlynet \
	  --host-only-net2 ${project_network_name} \
	  --mac-address2=${_instance_mac_address_lab} \
	  --nic-type2 82540EM \
	  --cable-connected2 on \
	  --nic-promisc2 allow-all
	echo " - Create storage controllers"
	_scsi_controller_name="SCSI Controller"
	VBoxManage storagectl \
	  "${vbox_instance_name:?}" \
	  --name "${_scsi_controller_name:?}" \
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
	echo " - Create instance main disk cloning ${os_release_file:?}"
	VBoxManage clonemedium disk \
	  "${os_images_path}/${os_release_file:?}" \
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
	  --storagectl "${_scsi_controller_name:?}" \
	  --port 0 \
	  --device 0 \
	  --type hdd \
	  --medium "${vbox_instance_disk_file:?}"
	echo " - Create cloud-init iso (set label as CIDATA)"
	hdiutil makehybrid \
	  -o "${vbox_instance_cidata_disk_file:?}" \
	  -default-volume-name CIDATA \
	  -hfs \
	  -iso \
	  -joliet \
	  "${vbox_instance_cidata_files_path:?}"
	echo " - Attach cloud-init iso to instance"
	VBoxManage storageattach \
	  "${vbox_instance_name:?}" \
	  --storagectl "${_scsi_controller_name:?}" \
	  --port 1 \
	  --device 0 \
	  --type dvddrive \
	  --medium "${vbox_instance_cidata_disk_file:?}" \
	  --comment "cloud-init data for ${vbox_instance_name:?}"
	echo " - Attach Guest Addition iso installer to instance"
	# (Note: need to attach 'emptydrive' before 'additions' becuse VBOX is full of bugs)
	VBoxManage storageattach  \
	  "${vbox_instance_name:?}" \
	  --storagectl "${_scsi_controller_name:?}" \
	  --port 2 \
	  --device 0 \
	  --type dvddrive \
	  --medium emptydrive
	VBoxManage storageattach  \
	  "${vbox_instance_name:?}" \
	  --storagectl "${_scsi_controller_name:?}" \
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
		_uart_file="${vbox_instance_basefolder:?}/tmp/tty0.log"
		echo " - Set Serial Port to log boot sequence"
		touch "${_uart_file:?}"
		echo "   - To see log file:"
		echo "    tail -f -n +1 '${_uart_file:?}'"
		echo
		VBoxManage modifyvm \
		"${vbox_instance_name:?}" \
		  --uart1 0x3F8 4 \
		  --uartmode1 "${vbox_instance_uart_mode}" \
		  "${_uart_file:?}"
	else
		echo " - Ignore Serial Port settings"
	fi
	echo " - Starting instance '${vbox_instance_name:?}' in mode '${vbox_instance_start_type:?}'"
	VBoxManage startvm "${vbox_instance_name:?}" --type "${vbox_instance_start_type:?}"
fi
