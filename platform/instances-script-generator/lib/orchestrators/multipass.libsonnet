local guest_os_release = 'lts';

// TODO: Move 'Utilities functions' in external libsonnet file
// Start - Utilities functions
local shell_lines(lines) =
  std.stripChars(
    std.join('', lines),
    '\n'
  );

local indent(string, pre) =
  pre + std.join(
    '\n' + pre,
    std.split(std.rstripChars(string, '\n'), '\n')
  );
// END - Utilities functions

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

local multipass_project_config(config) =
  assert std.isObject(config);
  assert std.objectHas(config, 'project_name');
  assert std.objectHas(config, 'project_domain');
  assert std.objectHas(config, 'projects_folder');
  assert std.objectHas(config, 'project_basefolder');
  assert std.objectHas(config, 'os_release_codename');
  assert std.objectHas(config, 'host_architecture');
  |||
    # -- start: multipass-project-config
    netplan_nic_name='default'
    # -- end: multipass-project-config
  ||| % {
    project_name: config.project_name,
    project_domain: config.project_domain,
    projects_folder: config.projects_folder,
    project_basefolder: config.project_basefolder,
    os_release_codename: config.os_release_codename,
    host_architecture: config.host_architecture,
  };

local project_config(config) =
  |||
    # - start: config
    %(generic_project_config)s
    %(multipass_project_config)s
    # - end: config
  ||| % {
    generic_project_config: generic_project_config(config),
    multipass_project_config: multipass_project_config(config),
  };

local instance_config(config, instance) =
  assert std.isObject(config);
  assert std.isObject(instance);
  assert std.objectHas(instance, 'hostname');
  local cpus = std.get(instance, 'cpus', '1');
  local storage_space = std.get(instance, 'storage_space', '5000');
  local instance_username = std.get(instance, 'admin_username', 'ubuntu');
  local instance_password = std.get(instance, 'admin_password_plain', 'password');
  local memory = std.get(instance, 'memory', '1024');
  // Note: vram is not used in multipass
  local vram = std.get(instance, 'vram', '64');
  |||
    # - Instance settings -
    instance_name=%(hostname)s
    instance_username=%(instance_username)s
    instance_password=%(instance_password)s
    # Disk size in MB
    instance_storage_space=%(instance_storage_space)s
    instance_cpus=%(instance_cpus)s
    instance_memory=%(instance_memory)s
    instance_vram=%(instance_vram)s

    instance_check_timeout_seconds=%(instance_timeout)s
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
    instance_username: instance_username,
    instance_password: instance_password,
    instance_cpus: cpus,
    instance_storage_space: storage_space,
    instance_timeout: instance.timeout,
    instance_memory: memory,
    instance_vram: vram,
  };

local check_instance(instance) =
  |||
    _instance_name=%(hostname)s
    echo "Checking '${_instance_name}'..."
    _instance_status=$(multipass info --format yaml ${_instance_name} 2>&1) && _exit_code=$? || _exit_code=$?
    if [[ $_exit_code -eq 0 ]]; then
    	echo "✅ Instance '${_instance_name}' found!"
    elif [[ $_exit_code -eq 2 ]] && [[ $_instance_status =~ 'does not exist' ]]; then
    	echo "❌ Instance '${_instance_name}' not found!"
    	exit 1
    else
    	echo "❌ Instance '${_instance_name}' - exit code '${_exit_code}'"
    	echo ${_instance_status}
    	exit 2
    fi
  ||| % {
    hostname: instance.hostname,
  };

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
  else '';

local inline_shell_provisioning(opts) =
  assert std.objectHas(opts, 'destination_host');
  assert std.objectHas(opts, 'script');
  local working_directory_option =
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
        _exit_code=$? || _exit_code=$?
        if [[ $_exit_code -eq 0 ]]; then
        	echo "No need to reboot"
        else
        	echo "Reboot"
        	multipass stop %(destination_host)s
        	multipass start %(destination_host)s
        fi
        set -e
      ||| % {
        destination_host: opts.destination_host,
      }
    else '';
  |||
    %(pre_command)s
    multipass exec %(destination_host)s \
    	%(working_directory_option)s -- \
    	/bin/bash <<-'END'
    %(script)s
    END
    %(post_command)s
  ||| % {
    pre_command: std.stripChars(pre_command, '\n'),
    working_directory_option: working_directory_option,
    script: indent(std.stripChars(opts.script, '\n'), '\t'),
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

local provision_instance(instance) =
  if std.objectHas(instance, 'base_provisionings') && std.isArray(instance.base_provisionings) then
    local provisionings = [i { destination_host: instance.hostname } for i in instance.base_provisionings];
    shell_lines(std.map(
      func=generate_provisioning,
      arr=provisionings
    ))
  else '';

local create_instance(config, instance) =
  assert std.isObject(config);
  assert std.isObject(instance);
  local mount_opt(host_path, guest_path) =
    '--mount "%(host_path)s":"%(guest_path)s"' % {
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
    echo "Checking '${instance_name}'..."
    _instance_status=$(multipass info --format yaml ${instance_name} 2>&1) && _exit_code=$? || _exit_code=$?
    if [[ $_exit_code -eq 0 ]]; then
    	echo "✅ Instance '${instance_name}' already exist!"
    elif [[ $_exit_code -eq 2 ]] && [[ $_instance_status =~ 'does not exist' ]]; then
    	echo " - Create Project data folder and subfolders: '${project_basefolder:?}'"
    	mkdir -p "${instance_basefolder:?}"/{cidata,disks,shared,tmp,assets}
    	multipass launch --cpus ${instance_cpus} \
    		--disk ${instance_storage_space}M \
    		--memory ${instance_memory}M \
    		--name "${instance_name}" \
    		--cloud-init "assets/cloud-init-${instance_name}.yaml" \
    		--timeout ${instance_check_timeout_seconds} \
    		%(mounts)s release:${os_release_codename}
    	_instance_status=$(multipass info --format json ${instance_name} 2>&1) && _exit_code=$? || _exit_code=$?
    	if [[ $_exit_code -ne 0 ]]; then
    		echo "❌ Could not get instance '${instance_name}' configuration!'"
    		exit 1
    	fi
      _instance_ipv4=$(echo "${_instance_status:?}" | jq --arg host "${instance_name:?}" '.info.[$host].ipv4[0]' --raw-output)
    	_instance_nic_name=$(multipass exec ${instance_name} \
    		-- /bin/bash <<-'END'
    			ip route | awk '/^default/ {print $5; exit}'
    		END
    	2>&1) && _exit_code=$? || _exit_code=$?
    	if [[ $_exit_code -ne 0 ]]; then
    		echo "❌ Could not get instance '${instance_name}' network interface!'"
    		exit 1
    	fi
    	PROJECT_TMP_FILE="$(mktemp)"
    	jq --indent 2 \
    		--arg host "${instance_name:?}" \
    		--arg ip "${_instance_ipv4:?}" \
    		--arg nic "${_instance_nic_name:?}" \
    		--arg netplan_nic "${netplan_nic_name:?}" \
    		'.list += {($host): {ipv4: $ip, network_interface_name: $nic, network_interface_netplan_name: $netplan_nic}}' \
    		"${instances_catalog_file:?}" \
    		> "$PROJECT_TMP_FILE" && mv "$PROJECT_TMP_FILE" "${instances_catalog_file:?}"
    else
    	echo "❌ Instance '${instance_name}' - exit code '${_exit_code}'"
    	echo ${_instance_status}
    	exit 2
    fi
  ||| % {
    instance_config: instance_config(config, instance),
    mounts: indent(std.join(' \\\n', mounts), '\t\t'),
  };

local destroy_instance(config, instance) =
  assert std.isObject(instance);
  assert std.objectHas(instance, 'hostname');

  |||
    _instance_name=%(hostname)s
    if multipass delete --purge "${_instance_name}"; then
    	echo "✅ Instance '${_instance_name}' deleted!"
    else
    	echo "✅ Instance '${_instance_name}' does not exist!"
    fi
  ||| % {
    hostname: instance.hostname,
  };

local snapshot_instance(instance) =
  assert std.isObject(instance);
  assert std.objectHas(instance, 'hostname');
  |||
    _instance_name=%(hostname)s
    echo "Check '${_instance_name}' snapshot"
    _instance_status=$(multipass info ${_instance_name} --snapshots 2>&1) && _exit_code=$? || _exit_code=$?
    if [[ $_exit_code -ne 0 ]]; then
    	echo "❌ Instance snapshots for '${_instance_name}' - exit code '${_exit_code}'"
    	echo ${_instance_status}
    	exit 2
    elif [[ $_instance_status =~ 'No snapshots found.' ]]; then
    	echo "No snapshots found!"
    	echo "Wait for cloud-init..."
    	multipass exec ${_instance_name} -- cloud-init status --wait --long
    	echo "Stopping '${_instance_name}' to take a snapshot..."
    	multipass stop ${_instance_name} -vv
    	echo "Create snapshot for '${_instance_name}'..."
    	multipass snapshot --name base-snapshot \
    		--comment "First snapshot for '${_instance_name}'" \
    		${_instance_name}
    	echo "Restarting '${_instance_name}' ..."
    	multipass start ${_instance_name} -vv
    else
    	echo "✅ Snapshot for '${_instance_name}' already present!"
    fi
  ||| % {
    hostname: instance.hostname,
  };

local provision_instances(config) =
  if std.objectHas(config, 'provisionings') then
    shell_lines(std.map(
      func=generate_provisioning,
      arr=config.provisionings
    ))
  else '';

local virtualmachine_command(config, command) =
  assert std.isObject(config);
  assert std.objectHas(config, 'virtual_machines');
  assert std.isArray(config.virtual_machines);
  local instances = [instance.hostname for instance in config.virtual_machines];

  |||
    #!/usr/bin/env bash
    set -Eeuo pipefail

    if [[ $# -lt 1 ]]; then
    	echo "$(tput setaf 2)Usage:$(tput sgr0) $(tput bold)$0 <name>$(tput sgr0)"
    	echo "$(tput setaf 3)  Where <name> is one of:$(tput sgr0) $(tput bold)%(instances)s$(tput sgr0)"
    	exit 1
    fi

    multipass %(command)s $1
  ||| % {
    instances: std.join(' ', instances),
    command: command,
  };

// Exported functions
{
  virtualmachines_bootstrap(config)::
    |||
      #!/usr/bin/env bash
      set -Eeuo pipefail

      _this_file_path=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
      generated_files_path="${_this_file_path}"

      %(project_config)s

      echo "Creating instances"
      jq --null-input --indent 2 '{list: {}}' > "${instances_catalog_file:?}"
      %(instances_creation)s
    ||| % {
      project_config: project_config(config),
      instances_creation: shell_lines([
        create_instance(config, instance)
        for instance in config.virtual_machines
      ]),
    },
  virtualmachines_setup(config)::
    local instances = [instance.hostname for instance in config.virtual_machines];
    |||
      #!/usr/bin/env bash
      set -Eeuo pipefail

      this_file_path=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
      generated_files_path="${this_file_path}"
      %(project_config)s

      echo "Checking instances"
      %(instances_check)s
      echo "Generating machines_config.json for ansible"
      cat "${instances_catalog_file:?}" > "${generated_files_path}/"%(ansible_inventory_path)s/machines_config.json
      echo "Instances basic provisioning"
      %(instances_provision)s
      echo "Check snapshots for instances"
      %(instances_snapshot)s
    ||| % {
      project_config: project_config(config),
      ansible_inventory_path: config.ansible_inventory_path,
      instances_check: shell_lines([
        check_instance(instance)
        for instance in config.virtual_machines
      ]),
      instances_provision: shell_lines([
        provision_instance(instance)
        for instance in config.virtual_machines
      ]),
      instances_snapshot: shell_lines([
        snapshot_instance(instance)
        for instance in config.virtual_machines
      ]),
    },
  virtualmachines_provisioning(config)::
    local provisionings =
      if std.objectHas(config, 'provisionings') then
        config.provisionings
      else [];
    |||
      #!/usr/bin/env bash
      set -Eeuo pipefail

      this_file_path=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

      echo "Provisioning instances"
      %(instances_provision)s
    ||| % {
      instances_provision: provision_instances(config),
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

      if [[ $# -lt 1 ]]; then
      	machine_list="%(instances)s"
      else
      	machine_list=$@
      fi
      multipass info \
      	--format yaml ${machine_list}
    ||| % {
      instances: std.join(' ', instances),
    },
  virtualmachine_shell(config)::
    virtualmachine_command(config, 'shell'),
  virtualmachines_info(config)::
    virtualmachine_command(config, 'info --format yaml'),
}
