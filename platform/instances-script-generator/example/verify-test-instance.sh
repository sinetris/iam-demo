#!/usr/bin/env bash
set -Eeuo pipefail

this_file_path=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "${this_file_path}/configuration.sh"

VBoxManage guestproperty get "${vbox_instance_name:?}" "/VirtualBox/GuestInfo/Net/1/V4/IP"

vbox_instance_command='sudo cloud-init status --wait --long'
vbox_instance_status=$(VBoxManage guestcontrol \
	${vbox_instance_name:?} run \
	--username ${vbox_instance_username:?} \
	--passwordfile ${vbox_instance_password_file:?} \
	--exe "/bin/bash" \
	--wait-stdout --wait-stderr \
	-- -c "whoami" 2>&1) && exit_code=$? || exit_code=$?

if [[ $exit_code -eq 0 ]]; then
	echo " ✅ Command '${vbox_instance_command}' run on instance '${vbox_instance_name}'!"
	echo "======"
	VBoxManage guestcontrol \
		${vbox_instance_name:?} run \
		--username ${vbox_instance_username:?} \
		--passwordfile ${vbox_instance_password_file:?} \
		--exe "/bin/bash" \
		--wait-stdout --wait-stderr \
		-- -c "${vbox_instance_command:?}"
	echo "======"
elif [[ $exit_code -eq 1 ]] && [[ "${vbox_instance_status}" =~ 'Guest Additions are not installed' ]]; then
	echo " ⚠️ Guest Additions are not installed or not ready (yet)."
	echo "  Try in few minutes!"
	exit 2
else
	echo " ❌ Error with exit code '${exit_code}'"
	echo ${vbox_instance_status}
	exit 1
fi
