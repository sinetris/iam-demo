#!/usr/bin/env bash
set -Eeuo pipefail

project_name=iam-demo
vbox_vm_name=testing-vm
vbox_basefolder=$HOME/.local/projects-data/${project_name:?}/${vbox_vm_name:?}
vbox_vm_cidata_iso="${vbox_basefolder:?}/disks/seed.iso"
echo "Destroying ${vbox_vm_name:?}"
VBoxManage unregistervm "testing-vm" --delete-all
VBoxManage closemedium dvd "${vbox_vm_cidata_iso:?}" --delete
rm -rf "${vbox_basefolder:?}"
