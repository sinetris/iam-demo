#!/usr/bin/env bash
set -Eeuo pipefail

project_name=iam-demo
vbox_instance_name=testing-instance
vbox_basefolder=$HOME/.local/projects-data/${project_name:?}/${vbox_instance_name:?}
vbox_instance_cidata_iso="${vbox_basefolder:?}/disks/seed.iso"
echo "Destroying ${vbox_instance_name:?}"
VBoxManage unregistervm "testing-instance" --delete-all
VBoxManage closemedium dvd "${vbox_instance_cidata_iso:?}" --delete
rm -rf "${vbox_basefolder:?}"
