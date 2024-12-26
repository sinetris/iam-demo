local shell_lines(lines) =
  std.stripChars(
    std.join('', lines),
    '\n'
  );

local indent(string, pre) =
  std.join(
    '\n' + pre,
    std.split(std.rstripChars(string, '\n'), '\n')
  );

local check_vm_exist_do(config, vm, action_code) =
  |||
    vm_name=%(hostname)s
    echo "Checking '${vm_name}'..."
    vm_status=$(VBoxManage showvminfo "${vm_name}" --machinereadable 2>&1) && exit_code=$? || exit_code=$?
    if [ $exit_code -eq 0 ] && [[ $vm_status =~ 'VMState="started"' ]]; then
      echo "✅ VM '${vm_name}' found!"
    elif [ $exit_code -eq 0 ] && [[ $vm_status =~ 'VMState="poweroff"' ]]; then
      echo "✅ VM '%(hostname)s' already exist but the state us 'poweroff'!"
    elif [ $exit_code -eq 0 ]; then
      echo "❌ VM '%(hostname)s' already exist but in UNMANAGED state!"
    elif  [ $exit_code -eq 1 ] && [[ $vm_status =~ 'Could not find a registered machine' ]]; then
      %(action_code)s
    else
      echo "❌ VM '${vm_name}' - exit code '${exit_code}'"
      echo ${vm_status}
      exit 2
    fi
  ||| % {
    hostname: vm.hostname,
    action_code: action_code,
  };

local create_network(config) =
  assert std.isObject(config);
  assert std.objectHas(config, 'project_name');
  assert std.objectHas(config, 'network');
  local network = std.get(config, 'network', {});
  assert std.objectHas(network, 'name');
  assert std.objectHas(network, 'netmask');
  assert std.objectHas(network, 'lower_ip');
  assert std.objectHas(network, 'upper_ip');
  |||
    echo "Checking Network '%(network_name)s'..."
    vm_network_status=$(VBoxManage hostonlynet modify \
      --name %(network_name)s --enable 2>&1) && exit_code=$? || exit_code=$?
    if [ $exit_code -eq 0 ]; then
      echo "✅ VM Network '%(network_name)s' already exist!"
    elif [ $exit_code -eq 1 ] && [[ $vm_network_status =~ 'does not exist' ]]; then
      echo "Creating Network '%(network_name)s'..."
      VBoxManage hostonlynet add \
        --name %(network_name)s \
        --netmask %(network_netmask)s \
        --lower-ip %(network_lower_ip)s \
        --upper-ip %(network_upper_ip)s \
        --enable
    else
      echo "❌ VM Network '%(network_name)s' - exit code '${exit_code}'"
      echo ${vm_network_status}
      exit 2
    fi
  ||| % {
    network_name: config.project_name + '-' + config.network.name,
    network_netmask: config.network.netmask,
    network_lower_ip: config.network.lower_ip,
    network_upper_ip: config.network.upper_ip,
  };

local create_vm(config, vm) =
  assert std.isObject(config);
  assert std.objectHas(config, 'project_name');
  assert std.objectHas(config, 'base_domain');
  assert std.isObject(vm);
  assert std.objectHas(vm, 'hostname');
  local cpus = std.get(vm, 'cpus', '1');
  local storage_space = std.get(vm, 'storage_space', '5000');
  local memory = std.get(vm, 'memory', '1024');
  local vram = std.get(vm, 'vram', '64');
  local mount_opt(host_path, guest_path) =
    |||
      VBoxManage sharedfolder add \
        "${vbox_machine_name:?}" \
        --name "${vbox_machine_name:?}-%(name)s" \
        --hostpath "%(host_path)s" \
        --auto-mount-point="%(guest_path)s" \
        --automount
    ||| % {
      name: std.strReplace(guest_path, '/', '-'),
      host_path: host_path,
      guest_path: guest_path,
    };
  local mounts =
    if std.objectHas(vm, 'mounts') then
      assert std.isArray(vm.mounts);
      [
        assert std.isObject(mount);
        assert std.objectHas(mount, 'host_path');
        assert std.objectHas(mount, 'guest_path');
        mount_opt(mount.host_path, mount.guest_path)
        for mount in vm.mounts
      ]
    else [];
  |||
    vbox_architecture=arm
    vbox_vm_ostype=Ubuntu24_LTS_arm64
    vbox_basefolder=%(host_path)s
    vbox_machine_name=%(hostname)s
    vbox_vm_cidata_iso="${vbox_basefolder:?}/disks/seed.iso"
    vbox_vm_disk_file="${vbox_basefolder:?}/disks/boot-disk.vdi"
    vbox_iso_installer_file=~/virtualization/iso/ubuntu-24.04.1-live-server-arm64.iso
    vbox_guest_additions_iso=/Applications/VirtualBox.app/Contents/MacOS/VBoxGuestAdditions.iso
    vbox_vm_cidata_origin_path=${vbox_basefolder:?}/cidata
    mkdir -p "${vbox_basefolder:?}"/{cidata,disks,shared}
    _generated_vm_mac_address=$(dd bs=1 count=3 if=/dev/random 2>/dev/null |  hexdump -vn3 -e '/3 "02:42:00"' -e '/1 ":%%02X"')
    # MAC Address in cloud-init network config is lowercase separated by colon
    vbox_vm_mac_address_cloud_init=$(awk -v mac_address="${_generated_vm_mac_address}" 'BEGIN {print tolower(mac_address)}')
    # MAC Address in VirtualBox configuration is uppercase and without colon separator
    vbox_vm_mac_address=$(awk -v mac_address="${_generated_vm_mac_address}" 'BEGIN { gsub(/:/, "", mac_address); print toupper(mac_address) }')
    cp "cloud-init-%(hostname)s.yaml" "${vbox_vm_cidata_origin_path:?}/user-data"
    # Create cloud-init network configuration
    tee "${vbox_vm_cidata_origin_path:?}/network-config" > /dev/null <<-EOT
    version: 2
    ethernets:
      lab:
        dhcp4: true
        dhcp6: false
        match:
          macaddress: ${vbox_vm_mac_address_cloud_init}
        set-name: lab
        nameservers:
          search:
            - '%(base_domain)s'
          addresses: [%(dns_servers)s]
    EOT
    # Create VirtualMachine
    VBoxManage createvm \
      --name "%(hostname)s" \
      --platform-architecture ${vbox_architecture:?} \
      --basefolder ${vbox_basefolder:?} \
      --ostype ${vbox_vm_ostype:?} \
      --register
    # Configure network
    VBoxManage modifyvm \
      "%(hostname)s" \
      --groups "/%(project_name)s" \
      --nic1 nat \
      --nic-type1 82540EM \
      --cable-connected1 on \
      --nic2 hostonlynet \
      --host-only-net2 %(network_name)s \
      --mac-address2=${vbox_vm_mac_address} \
      --nic-type2 82540EM \
      --cable-connected2 on \
      --nic-promisc2 allow-all
    # Create storage controllers
    _vbox_vm_scsi_controller_name="SCSI Controller"
    VBoxManage storagectl \
      "%(hostname)s" \
      --name "${_vbox_vm_scsi_controller_name:?}" \
      --add virtio \
      --controller VirtIO \
      --bootable on
    # Configure the VM
    VBoxManage modifyvm \
      "%(hostname)s" \
      --cpus "%(cpus)s" \
      --memory "%(memory)s" \
      --vram "%(vram)s" \
      --graphicscontroller vmsvga \
      --audio-driver none \
      --ioapic on \
      --usbohci on \
      --cpu-profile host
    # Create VM main disk
    VBoxManage createmedium disk \
      --filename "${vbox_vm_disk_file:?}" \
      --size %(storage_space)s
    # Create cloud-init iso
    hdiutil makehybrid \
      -o "${vbox_vm_cidata_iso:?}" \
      -default-volume-name cidata \
      -hfs \
      -iso \
      -joliet \
      "${vbox_vm_cidata_origin_path:?}"
    # Attach main disk
    VBoxManage storageattach \
      "%(hostname)s" \
      --storagectl "${_vbox_vm_scsi_controller_name:?}" \
      --port 0 \
      --device 0 \
      --type hdd \
      --medium "${vbox_vm_disk_file:?}"
    # Attach cloud-init iso to VM
    VBoxManage storageattach \
      "%(hostname)s" \
      --storagectl "${_vbox_vm_scsi_controller_name:?}" \
      --port 1 \
      --device 0 \
      --type dvddrive \
      --medium "${vbox_vm_cidata_iso:?}" \
      --comment "cloud-init data for %(hostname)s"
    # Attach Ubuntu iso installer
    VBoxManage storageattach  \
      "%(hostname)s" \
      --storagectl "${_vbox_vm_scsi_controller_name:?}" \
      --port 2 \
      --device 0 \
      --type dvddrive \
      --medium "${vbox_iso_installer_file:?}"
    # Attach Guest Addition iso installer
    VBoxManage storageattach  \
      "%(hostname)s" \
      --storagectl "${_vbox_vm_scsi_controller_name:?}" \
      --port 3 \
      --device 0 \
      --type dvddrive \
      --medium "${vbox_guest_additions_iso:?}"
    # Configure the VM boot order
    VBoxManage modifyvm \
      "%(hostname)s" \
      --boot1 disk \
      --boot2 dvd
    # Ensure COM port is available
    # VBoxManage modifyvm \
    #  "%(hostname)s" \
    #  --uart1 0x3F8 4 --uartmode1 server /tmp/tty0
    %(mounts)s
  ||| % {
    base_domain: config.base_domain,
    project_name: config.project_name,
    hostname: vm.hostname,
    host_path: vm.host_path,
    cpus: vm.cpus,
    storage_space: vm.storage_space,
    timeout: vm.timeout,
    memory: memory,
    vram: vram,
    mounts: shell_lines(mounts),
    network_name: config.project_name + '-' + config.network.name,
    dns_servers: std.join(',', config.dns_servers),
  };

local info_vm(config, vm) =
  assert std.isObject(config);
  assert std.isObject(vm);
  assert std.objectHas(vm, 'hostname');
  |||
    vm_ip_output=$(\
      VBoxManage guestproperty \
      enumerate "%(hostname)s" \
      --no-flags \
      --no-timestamp \
      '/VirtualBox/GuestInfo/Net/0/V4/IP' \
      | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+') && exit_code=$? || exit_code=$?
  ||| % {
    hostname: vm.hostname,
  };

local destroy_vm(config, vm) =
  assert std.isObject(vm);
  assert std.objectHas(vm, 'hostname');

  |||
    vbox_basefolder=%(host_path)s
    vbox_vm_cidata_iso="${vbox_basefolder:?}/disks/seed.iso"
    vbox_vm_disk_file="${vbox_basefolder:?}/disks/boot-disk.vdi"
    VBoxManage unregistervm "%(hostname)s" --delete-all
    VBoxManage closemedium dvd "${vbox_vm_cidata_iso:?}" --delete
    VBoxManage closemedium disk "${vbox_vm_disk_file:?}" --delete
  ||| % {
    host_path: vm.host_path,
    hostname: vm.hostname,
  };

local provision_vms(config, provisionings) =
  if std.isArray(provisionings) then
    local file_provisioning(opts) =
      assert std.objectHas(opts, 'destination');
      local parents =
        if std.objectHas(opts, 'create_parents_dir') then
          assert std.isBoolean(opts.create_parents_dir);
          if opts.create_parents_dir then '--parents' else ''
        else '';
      local destination =
        if std.objectHas(opts, 'destination_host') && opts.destination_host != 'localhost' then
          '%(host)s:%(file)s' % { host: opts.destination_host, file: opts.destination }
        else opts.destination;
      if std.objectHas(opts, 'source') then
        local source =
          if std.objectHas(opts, 'source_host') && opts.source_host != 'localhost' then
            '%(host)s:%(file)s' % { host: opts.source_host, file: opts.source }
          else opts.source;
        |||
          multipass transfer %(parents)s \
            %(source)s \
            %(destination)s
        ||| % {
          source: source,
          destination: destination,
          parents: parents,
        }
      else if std.objectHas(opts, 'source_inline') then
        |||
          content=$(cat <<-'END'
          %(source)s
          END
          )
          echo "${content}" | multipass transfer %(parents)s \
            - %(destination)s
        ||| % {
          source: opts.source_inline,
          destination: destination,
          parents: parents,
        }
      else '';
    local inline_shell_provisioning(opts) =
      assert std.objectHas(opts, 'destination_host');
      assert std.objectHas(opts, 'script');
      local cwd =
        if std.objectHas(opts, 'working_directory') then
          "--working-directory '" + opts.working_directory + "'"
        else '';
      local pre_command =
        if std.objectHas(opts, 'reboot_on_error') then
          'set +e'
        else '';
      local post_command =
        if std.objectHas(opts, 'reboot_on_error') then
          |||
            exit_code=$? || exit_code=$?

            if [ $exit_code -eq 0 ]; then
              echo "No need to reboot"
            else
              echo "Reboot"
              VBoxManage controlvm %(destination_host)s reboot
            fi
            set -e
          ||| % {
            destination_host: opts.destination_host,
          }
        else '';
      |||
        %(pre_command)s
        ssh \
          -o UserKnownHostsFile=/dev/null \
          -o StrictHostKeyChecking=no \
          -o IdentitiesOnly=yes \
          -i "${this_file_path}generated/.ssh/id_ed25519"
          user@remotehost.example.com \
        <<-'EOF'
        	%(script)s
        EOF
        %(post_command)s
      ||| % {
        pre_command: std.stripChars(pre_command, '\n'),
        working_directory: cwd,
        script: indent(opts.script, '\t'),
        destination_host: opts.destination_host,
        post_command: std.stripChars(post_command, '\n'),
      };
    local generate_provisioning(opts) =
      assert std.objectHas(opts, 'type');
      assert std.objectHas(opts, 'destination_host');
      if opts.type == 'file' then
        file_provisioning(opts)
      else if opts.type == 'inline-shell' then
        inline_shell_provisioning(opts)
      else error 'Invalid provisioning: %(opts.type)s';
    shell_lines(std.map(
      func=generate_provisioning,
      arr=provisionings
    ))
  else '';

// Exported functions
{
  virtualmachines_bootstrap(config)::
    |||
      #!/usr/bin/env bash
      set -Eeuo pipefail

      this_file_path=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

      echo "Creating Network"
      %(network_creation)s

      echo "Creating VMs"
      %(vms_creation)s
    ||| % {
      network_creation: create_network(config),
      vms_creation: shell_lines([
        check_vm_exist_do(config, vm, indent(create_vm(config, vm), '\t'))
        for vm in config.virtual_machines
      ]),
    },
  virtualmachines_setup(config)::
    local vms = [vm.hostname for vm in config.virtual_machines];
    local provisionings =
      if std.objectHas(config, 'base_provisionings') then
        config.base_provisionings
      else [];
    local action_code = |||
      echo "❌ VM '${vm_name}' not mamama found!"
      exit 1
    |||;
    |||
      #!/usr/bin/env bash
      set -Eeuo pipefail

      this_file_path=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
      vms_names_json=%(vms_names_json)s

      echo "Checking VMs"
      %(vms_check)s
      echo "Generating machines_config.json for ansible"
      multipass list --format json | \
        jq --argjson vms_names_json "${vms_names_json}" \
        '.list | [.[] | select(.name as $n | $vms_names_json | index($n))] as $vms | {list: $vms}' \
        > %(ansible_inventory_path)s/machines_config.json
      %(vms_provision)s
    ||| % {
      ansible_inventory_path: config.ansible_inventory_path,
      vms_check: shell_lines([
        check_vm_exist_do(config, vm, indent(action_code, '  '))
        for vm in config.virtual_machines
      ]),
      vms_provision: provision_vms(config, provisionings),
      vms_names_json: std.escapeStringBash(
        std.manifestJsonMinified(vms)
      ),
    },
  virtualmachines_provisioning(config)::
    local provisionings =
      if std.objectHas(config, 'app_provisionings') then
        config.app_provisionings
      else [];
    |||
      #!/usr/bin/env bash
      set -Eeuo pipefail

      this_file_path=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

      echo "Provisioning VMs"
      %(vms_provision)s
    ||| % {
      vms_provision: provision_vms(config, provisionings),
    },
  virtualmachines_destroy(config)::
    |||
      #!/usr/bin/env bash
      set -Eeuo pipefail

      echo "Destroying VMs"

      %(vms_destroy)s
    ||| % {
      vms_destroy: shell_lines([
        destroy_vm(config, vm)
        for vm in config.virtual_machines
      ]),
    },
  virtualmachines_list(config)::
    assert std.isObject(config);
    assert std.objectHas(config, 'virtual_machines');
    assert std.isArray(config.virtual_machines);

    local vms = [vm.hostname for vm in config.virtual_machines];

    |||
      #!/usr/bin/env bash
      set -Eeuo pipefail

      if [ $# -lt 1 ]; then
        machine_list="%(vms)s"
      else
        machine_list=$@
      fi
      multipass info \
        --format yaml ${machine_list}
    ||| % {
      vms: std.join(' ', vms),
    },
  virtualmachine_shell(_config)::
    |||
      #!/usr/bin/env bash
      set -Eeuo pipefail

      if [ $# -lt 1 ]; then
        echo $(tput setaf 2)Usage:$(tput sgr0) $(tput bold)$0 VIRTUAL_MACHINE_IP$(tput sgr0)
        exit 1
      fi

      this_file_path=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

      ssh -o "IdentitiesOnly=yes" -i "${this_file_path}generated/.ssh/id_ed25519" $1
    |||,
  virtualmachines_info(config)::
    assert std.isObject(config);
    assert std.objectHas(config, 'virtual_machines');
    assert std.isArray(config.virtual_machines);

    local vms = [vm.hostname for vm in config.virtual_machines];

    |||
      #!/usr/bin/env bash
      set -Eeuo pipefail

      if [ $# -lt 1 ]; then
        echo $(tput setaf 2)Usage:$(tput sgr0) $(tput bold)$0 VIRTUAL_MACHINE_IP$(tput sgr0)
        exit 1
      fi

      vm_ip_output=$(VBoxManage guestproperty enumerate "$1" --no-flags --no-timestamp '/VirtualBox/GuestInfo/Net/0/V4/IP' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
    ||| % {
      vms: std.join(' ', vms),
    },

}
