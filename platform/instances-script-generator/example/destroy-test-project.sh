#!/usr/bin/env bash
set -Eeuo pipefail

this_file_path=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

. "${this_file_path}/configuration.sh"

instance_status=$(VBoxManage showvminfo "${vbox_instance_name:?}" --machinereadable 2>&1) \
  && exit_code=$? || exit_code=$?
if [[ $exit_code -eq 0 ]]; then
  echo "⚙️ Destroying instance '${vbox_instance_name:?}'!"
  if [[ $instance_status =~ 'VMState="started"' ]] || [[ $instance_status =~ 'VMState="running"' ]]; then
    VBoxManage controlvm "${vbox_instance_name:?}" poweroff
  fi
  VBoxManage unregistervm "${vbox_instance_name:?}" --delete-all
elif [[ $exit_code -eq 1 ]] && [[ $instance_status =~ 'Could not find a registered machine' ]]; then
  echo "✅ Instance '${vbox_instance_name:?}' not found!"
else
  echo "❌ Instance '${vbox_instance_name:?}' - exit code '${exit_code}'"
  echo ${instance_status}
  exit 2
fi

project_network_status=$(VBoxManage hostonlynet modify \
  --name ${project_network_name} --disable 2>&1) && exit_code=$? || exit_code=$?
if [[ $exit_code -eq 0 ]]; then
  echo "⚙️ Project Network '${project_network_name}' will be removed!"
  VBoxManage hostonlynet remove \
    --name ${project_network_name}
elif [[ $exit_code -eq 1 ]] && [[ $project_network_status =~ 'does not exist' ]]; then
  echo "✅ Project Network '${project_network_name}' does not exist!"
else
  echo "❌ Project Network '${project_network_name}' - exit code '${exit_code}'"
  echo ${project_network_status}
  exit 2
fi

VBoxManage closemedium dvd "${vbox_instance_cidata_disk_file:?}" --delete 2>/dev/null \
  || echo "✅ Disk '${vbox_instance_cidata_disk_file}' does not exist!"

if [[ -d "${vbox_project_basefolder:?}" ]]; then
  echo "⚙️ Deleting project data folder '${vbox_project_basefolder:?}'"
  rm -rfv "${vbox_project_basefolder:?}"
else
   echo "✅ Project data folder '${vbox_project_basefolder:?}' does not exist."
fi
