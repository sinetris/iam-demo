// start: jsonnet-utils
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
// end: jsonnet-utils

// start: bash-utils
local bash_mac_address_functions() =
  |||
    ### Generate MAC Address - Locally Administered Address (LAA) ###
    # Description:
    #   - IEEE 802c standard
    #   - six octects (one octect is represented by two hexadecimal digits)
    #   - YANG type: mac-address from RFC-699 (lowercase and separated by colon `:`)
    #   - unicast Administratively Assigned Identifier (AAI) local identifier type
    #     from Structured Local Address Plan (SLAP)
    #     Essentially: second hexadecimal digit is `2`
    # Input:
    #   - first parameter
    #     description: MAC address prefix
    #     format: "X2:XX"
    #     default: "42:12"
    # Output: "X2:XX:XX:XX:XX:XX"
    # Note for Input and Output: `X` is a lowercase hexadecimal digit
    # Return:
    #   0 on success
    #   1 on invalid MAC address prefix
    #   2 on invalid generated MAC address
    function generate_mac_address {
      _mac_address_prefix=${1:-"42:12"}
      if ! [[ "${_mac_address_prefix}" =~ ^[0-9a-f]2:[0-9a-f]{2}$ ]]; then
        echo "Invalid MAC address prefix: '${_mac_address_prefix}'" >&2
        return 1
      fi
      local _generated_mac_address=$(dd bs=1 count=4 if=/dev/random 2>/dev/null \
        | hexdump -v \
          -n 4 \
          -e '/2 "'"${_mac_address_prefix}"'" 4/1 ":%02x"')
      if [[ "${_generated_mac_address}" =~ ^[0-9a-f]2(:[0-9a-f]{2}){5}$ ]]; then
        echo "${_generated_mac_address}"
      else
        echo "Generated invalid MAC address: '${_generated_mac_address}'" >&2
        return 2
      fi
      return 0
    }

    ### Convert MAC Address in VirtualBox format ###
    # Input:
    #   - first parameter
    #     description: MAC address
    #     format: "X2:XX:XX:XX:XX:XX"
    #     note: `X` is an hexadecimal digit (case insensitive)
    # Output:
    #   format: "X2XXXXXXXXXX"
    #   note: `X` is an uppercase hexadecimal digit
    # Return:
    #   0 on success
    #   1 on invalid MAC address input
    function convert_mac_address_to_vbox {
      _mac_address=${1:?}
      if ! [[ "${_mac_address}" =~ ^[0-9a-fA-F]2(:[0-9a-fA-F]{2}){5}$ ]]; then
        echo "Invalid MAC address: '${_mac_address}'" >&2
        return 1
      fi
      awk -v mac_address="${_mac_address}" 'BEGIN { gsub(/:/, "", mac_address); print toupper(mac_address) }'
      return 0
    }

    ### Convert MAC Address from VirtualBox format ###
    # Input:
    #   - first parameter
    #     description: MAC address
    #     format: "X2:XX:XX:XX:XX:XX"
    #     note: `X` is an hexadecimal digit (case insensitive)
    # Output:
    #   format: "X2XXXXXXXXXX"
    #   note: `X` is an uppercase hexadecimal digit
    # Return:
    #   0 on success
    #   1 on invalid MAC address input
    function convert_mac_address_from_vbox {
      _mac_address=${1:?}
      if ! [[ "${_mac_address}" =~ ^[0-9a-fA-F]{12}$ ]]; then
        echo "Invalid MAC address: '${_mac_address}'" >&2
        return 1
      fi
      echo "${_mac_address}" | xxd -r -p | hexdump -v -n6 -e '/1 "%02x" 5/1 ":%02x"'
      return 0
    }
  |||;

local generic_project_config(config) =
  assert std.isObject(config);
  assert std.objectHas(config, 'project_name');
  assert std.objectHas(config, 'project_domain');
  assert std.objectHas(config, 'projects_folder');
  assert std.objectHas(config, 'project_basefolder');
  assert std.objectHas(config, 'os_release_codename');
  assert std.objectHas(config, 'host_architecture');
  |||
    # -- start: generic-project-config
    project_name=%(project_name)s
    project_domain="${project_name:?}.test"
    projects_folder=%(projects_folder)s
    project_basefolder="%(project_basefolder)s"
    os_release_codename=%(os_release_codename)s
    host_architecture=%(host_architecture)s
    host_public_key_file=~/.ssh/id_ed25519.pub
    cidata_network_config_template_file="${generated_files_path:?}/assets/cidata-network-config.yaml.tpl"
    instances_catalog_file="${generated_files_path:?}/assets/machines_config.json"
    # -- end: generic-project-config
  ||| % {
    project_name: config.project_name,
    project_domain: config.project_domain,
    projects_folder: config.projects_folder,
    project_basefolder: config.project_basefolder,
    os_release_codename: config.os_release_codename,
    host_architecture: config.host_architecture,
  };
// end: bash-utils

local cidata_network_config_template(config) =
  |||
    tee "${cidata_network_config_template_file:?}" > /dev/null <<-'EOT'
    network:
      version: 2
      ethernets:
        ethnat:
          dhcp4: true
          dhcp6: false
          dhcp-identifier: mac
          match:
            macaddress: ${_mac_address_nat}
          set-name: ethnat
          nameservers:
            addresses: [%(dns_servers)s]
        ethlab:
          dhcp4: true
          dhcp4-overrides:
            use-dns: false
            use-domains: false
          dhcp6: false
          dhcp-identifier: mac
          match:
            macaddress: ${_mac_address_lab}
          set-name: ethlab
          nameservers:
            search:
              - '${_domain}'
            addresses: [127.0.0.53]
    EOT
  ||| % {
    dns_servers: std.join(',', config.dns_servers),
  };

// start: vbox-bash-utils
local vbox_bash_architecture_configs() =
  |||
    case "${host_architecture:?}" in
      arm64|aarch64)
        vbox_architecture=arm
        guest_architecture=arm64
        vbox_additions_installer_file=VBoxLinuxAdditions-arm64.run
        ;;
      amd64|x86_64)
        vbox_architecture=x86
        guest_architecture=amd64
        vbox_additions_installer_file=VBoxLinuxAdditions.run
        ;;
      *)
        echo "❌ Unsupported 'host_architecture' value: '${host_architecture:?}'!" >&2
        exit 1
        ;;
    esac
  |||;

local vbox_project_config(config) =
  assert std.isObject(config);
  assert std.objectHas(config, 'network');
  local network = std.get(config, 'network', {});
  assert std.objectHas(network, 'name_suffix');
  assert std.objectHas(network, 'netmask');
  assert std.objectHas(network, 'lower_ip');
  assert std.objectHas(network, 'upper_ip');
  |||
    # -- start: vbox-project-config
    project_network_name_suffix=%(network_name_suffix)s
    project_network_netmask=%(network_netmask)s
    project_network_lower_ip=%(network_lower_ip)s
    project_network_upper_ip=%(network_upper_ip)s
    project_network_name=${project_name:?}-${project_network_name_suffix:?}
    os_images_path="$HOME/.cache/os-images"
    os_images_url=https://cloud-images.ubuntu.com
    # Serial Port mode:
    #   file = log boot sequence to file
    vbox_instance_uart_mode=file
    vbox_basefolder=~/"VirtualBox VMs"
    # Start type: gui | headless | sdl | separate
    vbox_instance_start_type=headless
    # -- end: vbox-project-config
  ||| % {
    network_name_suffix: config.network.name_suffix,
    network_netmask: config.network.netmask,
    network_lower_ip: config.network.lower_ip,
    network_upper_ip: config.network.upper_ip,
  };
// end: vbox-bash-utils

local project_config(config) =
  |||
    # - start: config
    %(generic_project_config)s
    %(vbox_project_config)s
    # - end: config
  ||| % {
    generic_project_config: generic_project_config(config),
    vbox_project_config: vbox_project_config(config),
  };

local bash_utils(config) =
  |||
    # - start: utils
    %(mac_address_functions)s
    %(get_architecture_configs)s
    %(cidata_network_config_template)s
    # - end: utils
  ||| % {
    mac_address_functions: bash_mac_address_functions(),
    get_architecture_configs: vbox_bash_architecture_configs(),
    cidata_network_config_template: std.stripChars(cidata_network_config_template(config), '\n'),
  };


local check_instance_exist_do(config, instance, action_code) =
  |||
    instance_name=%(hostname)s
    echo "Checking '${instance_name:?}'..."
    _instance_status=$(VBoxManage showvminfo "${instance_name:?}" --machinereadable 2>&1) && _exit_code=$? || _exit_code=$?
    if [[ $_exit_code -eq 0 ]] && ( \
      [[ $_instance_status =~ 'VMState="started"' ]] \
      || [[ $_instance_status =~ 'VMState="running"' ]] \
    ); then
      echo "✅ Instance '${instance_name:?}' found!"
    elif [[ $_exit_code -eq 0 ]] && [[ $_instance_status =~ 'VMState="poweroff"' ]]; then
      echo "⚠️ Skipping instance '${instance_name:?}' - Already exist but in state 'poweroff'!"
    elif [[ $_exit_code -eq 0 ]]; then
      echo "❌ Instance '${instance_name:?}' already exist but in UNMANAGED state!" >&2
      echo ${_instance_status} >&2
      exit 1
    elif [[ $_exit_code -eq 1 ]] && [[ $_instance_status =~ 'Could not find a registered machine' ]]; then
      %(action_code)s
    else
      echo "❌ Instance '${instance_name:?}' - exit code '${_exit_code}'"
      echo ${_instance_status}
      exit 2
    fi
  ||| % {
    hostname: instance.hostname,
    action_code: action_code,
  };

local create_network(config) =
  |||
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
  ||| % {
  };

local instance_config(config, instance) =
  assert std.isObject(config);
  assert std.isObject(instance);
  assert std.objectHas(instance, 'hostname');
  local cpus = std.get(instance, 'cpus', '1');
  local storage_space = std.get(instance, 'storage_space', '5000');
  local memory = std.get(instance, 'memory', '1024');
  local vram = std.get(instance, 'vram', '64');
  |||
    # - Instance settings -
    instance_name=%(hostname)s
    instance_username=iamadmin
    instance_password=iamadmin
    # Disk size in MB
    instance_disk_size=%(storage_space)s
    instance_cpus=%(cpus)s
    instance_memory=%(memory)s
    instance_vram=%(vram)s

    instance_check_timeout_seconds=%(timeout)s
    instance_check_sleep_time_seconds=2
    instance_check_ssh_retries=5

    instance_basefolder="%(instance_basefolder)s"
    instance_cidata_files_path=${instance_basefolder:?}/cidata
    instance_cidata_iso_file="${instance_basefolder:?}/disks/${instance_name:?}-cidata.iso"
    instance_password_file="${instance_basefolder:?}/assets/admin-password-plain"
    instance_password_hash_file="${instance_basefolder:?}/assets/admin-password-hash"
    vbox_instance_disk_file="${instance_basefolder:?}/disks/${instance_name:?}-boot-disk.vdi"
    instance_config=${instance_basefolder:?}/assets/instance_config.json
  ||| % {
    hostname: instance.hostname,
    instance_basefolder: instance.basefolder,
    cpus: cpus,
    storage_space: storage_space,
    timeout: instance.timeout,
    memory: memory,
    vram: vram,
  };

local create_instance(config, instance) =
  assert std.isObject(config);
  assert std.isObject(instance);
  local mount_opt(host_path, guest_path) =
    |||
      echo "   - name: '${instance_name:?}-%(name)s'"
      echo "     host_path: '%(host_path)s'"
      echo "     guest_path: '%(guest_path)s'"
      VBoxManage sharedfolder add \
        "${instance_name:?}" \
        --name "${instance_name:?}-%(name)s" \
        --hostpath "%(host_path)s" \
        --auto-mount-point="%(guest_path)s" \
        --automount
    ||| % {
      name: std.strReplace(guest_path, '/', '-'),
      host_path: host_path,
      guest_path: guest_path,
    };
  local mounts =
    if std.objectHas(instance, 'mounts') then
      assert std.isArray(instance.mounts);
      [
        assert std.isObject(mount);
        assert std.objectHas(mount, 'host_path');
        assert std.objectHas(mount, 'guest_path');
        mount_opt(mount.host_path, mount.guest_path)
        for mount in instance.mounts
      ]
    else [];
  |||
    %(instance_config)s
    echo "⚙️ Creating Instance '${instance_name:?}' ..."
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
    echo " - Create Project data folder and subfolders: '${project_basefolder:?}'"
    mkdir -p "${instance_basefolder:?}"/{cidata,disks,shared,tmp,assets}
    if [ -f "${os_image_path:?}" ]; then
      echo "✅ Using existing '${os_release_file:?}' from '${os_image_path:?}'!"
    else
      echo " ⚙️ Downloading '${os_release_file:?}' from '${os_image_url:?}'..."
      mkdir -pv "${os_images_path:?}"
      curl --output "${os_image_path:?}" "${os_image_url:?}"
    fi
    echo "${instance_password:?}" > "${instance_password_file:?}"
    openssl passwd -6 -salt $(openssl rand -base64 8) "${instance_password}" > "${instance_password_hash_file:?}"
    _instance_password_hash=$(cat "${instance_password_hash_file:?}")
    _instance_public_key=$(cat "${host_public_key_file:?}")
    echo " - Create cloud-init configuration"
    # MAC Addresses in cloud-init network config (six octects, lowercase, separated by colon)
    _instance_mac_address_nat_cloud_init=$(generate_mac_address)
    _instance_mac_address_lab_cloud_init=$(generate_mac_address)
    # MAC Addresses in VirtualBox configuration (six octects, uppercase, no separators)
    _instance_mac_address_nat_vbox=$(convert_mac_address_to_vbox "${_instance_mac_address_nat_cloud_init}")
    _instance_mac_address_lab_vbox=$(convert_mac_address_to_vbox "${_instance_mac_address_lab_cloud_init}")
    echo "   - Create cloud-init 'network-config'"
    _domain="${project_domain}" \
    _mac_address_nat="${_instance_mac_address_nat_cloud_init}" \
    _mac_address_lab="${_instance_mac_address_lab_cloud_init}" \
    envsubst '$_domain,$_mac_address_nat,$_mac_address_lab' \
      <"${cidata_network_config_template_file:?}" | tee "${instance_cidata_files_path:?}/network-config" >/dev/null
    echo "   - Create cloud-init 'meta-data'"
    tee "${instance_cidata_files_path:?}/meta-data" > /dev/null <<-EOT
    instance-id: i-${instance_name:?}
    local-hostname: ${instance_name:?}
    EOT
    echo "   - Create cloud-init 'user-data'"
    # _domain="${project_domain}" \
    # _hostname="${instance_name}" \
    # _username=${instance_username} \
    # _password_hash=${_instance_password_hash} \
    # _public_key=${_instance_public_key} \
    # _additions_file=${vbox_additions_installer_file} \
    # envsubst '$_domain,$_hostname,$_username,$_password_hash,$_public_key,$_additions_file' \
    #   <"cloud-init-user-data.yaml.tpl" | tee "${instance_cidata_files_path:?}/user-data" >/dev/null
    cat "assets/cloud-init-${instance_name}.yaml" > "${instance_cidata_files_path:?}/user-data"
    echo " - Create VirtualMachine"
    VBoxManage createvm \
      --name "${instance_name:?}" \
      --platform-architecture ${vbox_architecture:?} \
      --basefolder "${vbox_basefolder:?}" \
      --ostype ${vbox_instance_ostype:?} \
      --register
    echo " - Set Screen scale to 200%%"
    VBoxManage setextradata \
      "${instance_name:?}" \
      'GUI/ScaleFactor' 2
    echo " - Configure network for instance"
    VBoxManage modifyvm \
      "${instance_name:?}" \
      --groups "/${project_name:?}" \
      --nic1 nat \
      --mac-address1=${_instance_mac_address_nat_vbox} \
      --nic-type1 82540EM \
      --cable-connected1 on \
      --nic2 hostonlynet \
      --host-only-net2 ${project_network_name} \
      --mac-address2=${_instance_mac_address_lab_vbox} \
      --nic-type2 82540EM \
      --cable-connected2 on \
      --nic-promisc2 allow-all
    echo " - Create storage controllers"
    _scsi_controller_name="SCSI Controller"
    VBoxManage storagectl \
      "${instance_name:?}" \
      --name "${_scsi_controller_name:?}" \
      --add virtio \
      --controller VirtIO \
      --bootable on
    echo " - Configure the instance"
    VBoxManage modifyvm \
      "${instance_name:?}" \
      --cpus "${instance_cpus:?}" \
      --memory "${instance_memory:?}" \
      --vram "${instance_vram:?}" \
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
    echo " - Resize instance main disk to '${instance_disk_size:?} MB'"
    VBoxManage modifymedium disk \
      "${vbox_instance_disk_file:?}" \
      --resize ${instance_disk_size:?}
    echo " - Attach main disk to instance"
    VBoxManage storageattach \
      "${instance_name:?}" \
      --storagectl "${_scsi_controller_name:?}" \
      --port 0 \
      --device 0 \
      --type hdd \
      --medium "${vbox_instance_disk_file:?}"
    echo ' - Create cloud-init iso (set label as CIDATA)'
    hdiutil makehybrid \
      -o "${instance_cidata_iso_file:?}" \
      -default-volume-name CIDATA \
      -hfs \
      -iso \
      -joliet \
      "${instance_cidata_files_path:?}"
    echo " - Attach cloud-init iso to instance"
    VBoxManage storageattach \
      "${instance_name:?}" \
      --storagectl "${_scsi_controller_name:?}" \
      --port 1 \
      --device 0 \
      --type dvddrive \
      --medium "${instance_cidata_iso_file:?}" \
      --comment "cloud-init data for ${instance_name:?}"
    echo " - Attach Guest Addition iso installer to instance"
    # (Note: need to attach 'emptydrive' before 'additions' becuse VBOX is full of bugs)
    VBoxManage storageattach  \
      "${instance_name:?}" \
      --storagectl "${_scsi_controller_name:?}" \
      --port 2 \
      --device 0 \
      --type dvddrive \
      --medium emptydrive
    VBoxManage storageattach  \
      "${instance_name:?}" \
      --storagectl "${_scsi_controller_name:?}" \
      --port 2 \
      --device 0 \
      --type dvddrive \
      --medium additions
    echo " - Configure the VM boot order"
    VBoxManage modifyvm \
      "${instance_name:?}" \
      --boot1 disk \
      --boot2 dvd
    if [ "${vbox_instance_uart_mode}" == "file" ]; then
      _uart_file="${instance_basefolder:?}/tmp/tty0.log"
      echo " - Set Serial Port to log boot sequence"
      touch "${_uart_file:?}"
      echo "   - To see log file:"
      echo "    tail -f -n +1 '${_uart_file:?}'"
      echo
      VBoxManage modifyvm \
      "${instance_name:?}" \
        --uart1 0x3F8 4 \
        --uartmode1 "${vbox_instance_uart_mode}" \
        "${_uart_file:?}"
    else
      echo " - Ignore Serial Port settings"
    fi
    echo " - Add shared folders"
    %(mounts)s
    echo " - Starting instance '${instance_name:?}' in mode '${vbox_instance_start_type:?}'"
    VBoxManage startvm "${instance_name:?}" --type "${vbox_instance_start_type:?}"

    _ipv4_regex='[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'
    # Note: GuestInfo Net properies start from 0 while 'modifyvm --nicN' start from 1.
    #       So '--nic2' is 'Net/1'.
    _vbox_lab_nic_id=1
    _vbox_lab_nic_ipv4_property="/VirtualBox/GuestInfo/Net/${_vbox_lab_nic_id:?}/V4/IP"

    echo "Wait for instance IPv4 or error on timeout after ${instance_check_timeout_seconds} seconds..."

    _start_time=$SECONDS
    _instance_ipv4=""
    _command_success=false
    until $_command_success; do
      if (( SECONDS >= _start_time + instance_check_timeout_seconds )); then
        echo "⚠️ VirtualBox instance network check timeout!"  >&2
        exit 1
      fi
      _cmd_status=$(VBoxManage guestproperty get "${instance_name:?}" "${_vbox_lab_nic_ipv4_property:?}" 2>&1) && _exit_code=$? || _exit_code=$?
      if [[ $_exit_code -ne 0 ]]; then
        echo "Error in VBoxManage for 'guestproperty get'!"  >&2
        exit 2
      fi
      _cmd_status=$(echo "${_cmd_status}" | grep --extended-regexp "${_ipv4_regex}" --only-matching --color=never 2>&1) && _exit_code=$? || _exit_code=$?
      if [[ $_exit_code -eq 0 ]]; then
        _command_success=true
        _instance_ipv4="${_cmd_status}"
      else
        echo "💤 Not ready yet!"
        echo " - retry in: ${instance_check_sleep_time_seconds} seconds"
        echo " - passed time: $SECONDS seconds"
        echo " - will timeout in: ${seconds_to_timeout} seconds"
        sleep ${instance_check_sleep_time_seconds}
      fi
      (( seconds_to_timeout = instance_check_timeout_seconds - SECONDS))
    done

    echo "Instance IPv4: ${_instance_ipv4:?}"
    instance_config=${instance_basefolder:?}/assets/instance_config.json

    _vbox_lab_nic_name_property="/VirtualBox/GuestInfo/Net/${_vbox_lab_nic_id:?}/Name"
    _instance_nic_name=$(VBoxManage guestproperty get "${instance_name:?}" "${_vbox_lab_nic_ipv4_property:?}" 2>&1)

    PROJECT_TMP_FILE="$(mktemp)"
    jq --indent 2 \
      --arg host "${instance_name:?}" \
      --arg ip "${_instance_ipv4:?}" \
      --arg nic "${_instance_nic_name:?}" \
      --arg macaddr "${_instance_mac_address_lab_cloud_init:?}" \
      '.list += {($host): {ipv4: $ip, mac_address: $macaddr, network_interface: $nic}}' \
      "${instances_catalog_file:?}" \
      > "$PROJECT_TMP_FILE" && mv "$PROJECT_TMP_FILE" "${instances_catalog_file:?}"
    echo "Wait for cloud-init to complete..."

    _instance_command='sudo cloud-init status --wait --long'
    _instance_check_ssh_success=false
    for retry_counter in $(seq $instance_check_ssh_retries 1); do
      ssh \
        -o UserKnownHostsFile=/dev/null \
        -o StrictHostKeyChecking=no \
        -o IdentitiesOnly=yes \
        -i "${generated_files_path}/assets/.ssh/id_ed25519" \
        -t ${instance_username:?}@${_instance_ipv4:?} \
        "${_instance_command:?}" && _exit_code=$? || _exit_code=$?
      if [[ $_exit_code -eq 0 ]]; then
        echo "✅ SSH command ran successfully!"
        _instance_check_ssh_success=true
        break
      else
        echo "💤 Will retry command in ${instance_check_sleep_time_seconds} seconds. Retry left: ${retry_counter}"
        sleep ${instance_check_sleep_time_seconds}
      fi
    done
    if ${_instance_check_ssh_success}; then
      echo "✅ Instance is ready!"
    else
      echo "⚠️ Instance not ready. - Skipping!"
    fi
  ||| % {
    instance_config: instance_config(config, instance),
    mounts: shell_lines(mounts),
  };

local destroy_instance(config, instance) =
  assert std.isObject(instance);
  assert std.objectHas(instance, 'hostname');
  |||
    %(instance_config)s
    _instance_status=$(VBoxManage showvminfo "${instance_name:?}" --machinereadable 2>&1) \
      && _exit_code=$? || _exit_code=$?
    if [[ $_exit_code -eq 0 ]]; then
      echo "⚙️ Destroying instance '${instance_name:?}'!"
      if [[ $_instance_status =~ 'VMState="started"' ]] || [[ $_instance_status =~ 'VMState="running"' ]]; then
        VBoxManage controlvm "${instance_name:?}" poweroff
      fi
      VBoxManage unregistervm "${instance_name:?}" --delete-all
    elif [[ $_exit_code -eq 1 ]] && [[ $_instance_status =~ 'Could not find a registered machine' ]]; then
      echo "✅ Instance '${instance_name:?}' not found!"
    else
      echo "❌ Ignoring instance '${instance_name:?}' - exit code '${_exit_code}'"
      echo ${_instance_status}
    fi
    VBoxManage closemedium dvd "${instance_cidata_iso_file:?}" --delete 2>/dev/null \
      || echo "✅ Disk '${instance_cidata_iso_file}' does not exist!"

  ||| % {
    instance_config: instance_config(config, instance),
    hostname: instance.hostname,
  };

local provision_instances(config, provisionings) =
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
          '${instance_username:?}@${_destintion_instance_ipv4:?}:%(file)s' % { host: opts.destination_host, file: opts.destination }
        else opts.destination;
      if std.objectHas(opts, 'source') then
        local source =
          if std.objectHas(opts, 'source_host') && opts.source_host != 'localhost' then
            '${instance_username:?}@${_source_instance_ipv4:?}:%(file)s' % { host: opts.source_host, file: opts.source }
          else opts.source;
        |||
          # create remote destination
          ssh \
          remote-host 'mkdir -p foo/bar/qux'
          scp \
            -o UserKnownHostsFile=/dev/null \
            -o StrictHostKeyChecking=no \
            -o IdentitiesOnly=yes \
            -i "${generated_files_path}/assets/.ssh/id_ed25519" \
            %(source)s \
            %(destination)s
        ||| % {
          source: source,
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
          -i "${generated_files_path}/assets/.ssh/id_ed25519" \
          ${instance_username:?}@${_instance_ipv4:?} \
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
      _this_file_path=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
      generated_files_path="${_this_file_path}"

      %(project_config)s
      %(bash_utils)s

      echo "Creating Network"
      %(network_creation)s

      echo "Creating instances"
      jq --null-input --indent 2 '{list: {}}' > "${instances_catalog_file:?}"
      %(instances_creation)s
      echo "✅ Project instances created!"
    ||| % {
      project_config: project_config(config),
      bash_utils: bash_utils(config),
      network_creation: create_network(config),
      instances_creation: shell_lines([
        check_instance_exist_do(config, instance, indent(create_instance(config, instance), '\t'))
        for instance in config.virtual_machines
      ]),
    },
  virtualmachines_setup(config)::
    local instances = [instance.hostname for instance in config.virtual_machines];
    local provisionings =
      if std.objectHas(config, 'base_provisionings') then
        config.base_provisionings
      else [];
    local action_code = |||
      echo "❌ Instance '${instance_name}' not found!"
      exit 1
    |||;
    |||
      #!/usr/bin/env bash
      set -Eeuo pipefail

      this_file_path=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
      instances_names_json=%(instances_names_json)s

      echo "Checking instances"
      %(instances_check)s
      echo "Generating machines_config.json for ansible"
      cat "${instances_catalog_file:?}" | \
        jq --argjson instances_names_json "${instances_names_json}" \
        '.list | [.[] | select(.name as $n | $instances_names_json | index($n))] as $instances | {list: $instances, network_interface: "default"}' \
        > "${generated_files_path}/"%(ansible_inventory_path)s/machines_config.json
      %(instances_provision)s
    ||| % {
      ansible_inventory_path: config.ansible_inventory_path,
      instances_check: shell_lines([
        check_instance_exist_do(config, instance, indent(action_code, '  '))
        for instance in config.virtual_machines
      ]),
      instances_provision: provision_instances(config, provisionings),
      instances_names_json: std.escapeStringBash(
        std.manifestJsonMinified(instances)
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

      echo "Provisioning instances"
      %(instances_provision)s
    ||| % {
      instances_provision: provision_instances(config, provisionings),
    },
  virtualmachines_destroy(config)::
    assert std.isObject(config);
    assert std.objectHas(config, 'project_basefolder');
    |||
      #!/usr/bin/env bash
      set -Eeuo pipefail

      _this_file_path=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
      generated_files_path="${_this_file_path}"

      echo "Destroying instances"

      %(project_config)s
      %(instances_destroy)s
      echo "Deleting '${project_basefolder:?}'"
      rm -rfv "${project_basefolder:?}"
      echo "✅ Deleting project '${project_name:?}' completed!"
    ||| % {
      project_config: project_config(config),
      instances_destroy: shell_lines([
        destroy_instance(config, instance)
        for instance in config.virtual_machines
      ]),
    },
  virtualmachines_list(config)::
    assert std.isObject(config);
    assert std.objectHas(config, 'virtual_machines');
    assert std.isArray(config.virtual_machines);

    local instances = [instance.hostname for instance in config.virtual_machines];

    |||
      #!/usr/bin/env bash
      set -Eeuo pipefail

      if [ $# -lt 1 ]; then
        instances=( %(instances)s )
        for instance in %(instances)s; do
          VBoxManage showvminfo "${instance:?}" --machinereadable
        done
      else
        VBoxManage showvminfo "${1:?}" --machinereadable
      fi
    ||| % {
      instances: std.join(' ', instances),
    },
  virtualmachine_shell(config)::
    |||
      #!/usr/bin/env bash
      set -Eeuo pipefail

      if [ $# -lt 1 ]; then
        echo $(tput setaf 2)Usage:$(tput sgr0) $(tput bold)$0 VIRTUAL_MACHINE_IP$(tput sgr0)
        exit 1
      fi

      this_file_path=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

      instance_config=${instance_basefolder:?}/assets/instance_config.json
      instance_ipv4=$(jq '.ipv4' --raw-output "${instance_config}")
      instance_username=$(jq '.admin_username' --raw-output "${instance_config}")

      ssh \
        -o UserKnownHostsFile=/dev/null \
        -o StrictHostKeyChecking=no \
        -o IdentitiesOnly=yes \
        -i "${generated_files_path}/assets/.ssh/id_ed25519" \
        ${instance_username:?}@${instance_ipv4:?}
    ||| % {
      project_config: project_config(config),
      bash_utils: bash_utils(config),
    },
  virtualmachines_info(config)::
    assert std.isObject(config);
    assert std.objectHas(config, 'virtual_machines');
    assert std.isArray(config.virtual_machines);

    local instances = [instance.hostname for instance in config.virtual_machines];

    |||
      #!/usr/bin/env bash
      set -Eeuo pipefail

      if [ $# -lt 1 ]; then
        echo $(tput setaf 2)Usage:$(tput sgr0) $(tput bold)$0 VIRTUAL_MACHINE_IP$(tput sgr0)
        exit 1
      fi

      instance_ip_output=$(VBoxManage guestproperty enumerate "$1" --no-flags --no-timestamp '/VirtualBox/GuestInfo/Net/0/V4/IP' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
    ||| % {
      instances: std.join(' ', instances),
    },
}
