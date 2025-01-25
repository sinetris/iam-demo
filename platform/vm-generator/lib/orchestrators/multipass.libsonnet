local guest_os_release = 'lts';

// TODO: Move 'Utilities functions' in external libsonnet file
// Start - Utilities functions
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
// END - Utilities functions

local check_vm(vm) =
  |||
    _vm_name=%(hostname)s
    echo "Checking '${_vm_name}'..."
    _vm_status=$(multipass info --format yaml ${_vm_name} 2>&1) && _exit_code=$? || _exit_code=$?
    if [[ $_exit_code -eq 0 ]]; then
      echo "✅ VM '${_vm_name}' found!"
    elif [[ $_exit_code -eq 2 ]] && [[ $_vm_status =~ 'does not exist' ]]; then
      echo "❌ VM '${_vm_name}' not found!"
      exit 1
    else
      echo "❌ VM '${_vm_name}' - exit code '${_exit_code}'"
      echo ${_vm_status}
      exit 2
    fi
  ||| % {
    hostname: vm.hostname,
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
      %(working_directory)s -- \
      /bin/bash <<-'END'
    %(script)s
    END
    %(post_command)s
  ||| % {
    pre_command: std.stripChars(pre_command, '\n'),
    working_directory: cwd,
    script: std.stripChars(opts.script, '\n'),
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

local provision_vm(vm) =
  if std.objectHas(vm, 'base_provisionings') && std.isArray(vm.base_provisionings) then
    local provisionings = [v { destination_host: vm.hostname } for v in vm.base_provisionings];
    shell_lines(std.map(
      func=generate_provisioning,
      arr=provisionings
    ))
  else '';

local create_vm(config, vm) =
  assert std.isObject(config);
  assert std.isObject(vm);
  assert std.objectHas(vm, 'hostname');
  assert std.objectHas(vm, 'project_host_path');
  local cpus = std.get(vm, 'cpus', '1');
  local storage_space = std.get(vm, 'storage_space', '5000');
  local memory = std.get(vm, 'memory', '1024');
  local mount_opt(host_path, guest_path) =
    '--mount "%(host_path)s":"%(guest_path)s"' % {
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
    _vm_name=%(hostname)s
    echo "Checking '${_vm_name}'..."
    _vm_status=$(multipass info --format yaml ${_vm_name} 2>&1) && _exit_code=$? || _exit_code=$?
    if [[ $_exit_code -eq 0 ]]; then
      echo "✅ VM '${_vm_name}' already exist!"
    elif [[ $_exit_code -eq 2 ]] && [[ $_vm_status =~ 'does not exist' ]]; then
      echo 'Creating "%(project_host_path)s"'
      mkdir -p "%(project_host_path)s/shared"
      multipass launch --cpus %(cpus)s \
        --disk %(storage_space)sM \
        --memory %(memory)sM \
        --name "${_vm_name}" \
        --cloud-init "assets/cloud-init-${_vm_name}.yaml" \
        --timeout %(timeout)s \
        %(mounts)s release:%(guest_os_release)s
    else
      echo "❌ VM '${_vm_name}' - exit code '${_exit_code}'"
      echo ${_vm_status}
      exit 2
    fi
  ||| % {
    hostname: vm.hostname,
    project_host_path: vm.project_host_path,
    cpus: vm.cpus,
    storage_space: vm.storage_space,
    timeout: vm.timeout,
    memory: vm.memory,
    mounts: indent(std.join(' \\\n', mounts), '    '),
    guest_os_release: guest_os_release,
  };

local destroy_vm(config, vm) =
  assert std.isObject(vm);
  assert std.objectHas(vm, 'hostname');

  |||
    _vm_name=%(hostname)s
    multipass delete --purge "${_vm_name}"
  ||| % {
    hostname: vm.hostname,
  };

local snapshot_vm(vm) =
  assert std.isObject(vm);
  assert std.objectHas(vm, 'hostname');
  |||
    _vm_name=%(hostname)s
    echo "Check '${_vm_name}' snapshot"
    _vm_status=$(multipass info ${_vm_name} --snapshots 2>&1) && _exit_code=$? || _exit_code=$?
    if [[ $_exit_code -ne 0 ]]; then
      echo "❌ VM snapshots for '${_vm_name}' - exit code '${_exit_code}'"
      echo ${_vm_status}
      exit 2
    elif [[ $_vm_status =~ 'No snapshots found.' ]]; then
      echo "No snapshots found!"
      echo "Wait for cloud-init..."
      multipass exec ${_vm_name} -- cloud-init status --wait --long
      echo "Stopping '${_vm_name}' to take a snapshot..."
      multipass stop ${_vm_name} -vv
      echo "Create snapshot for '${_vm_name}'..."
      multipass snapshot --name base-snapshot \
        --comment "First snapshot for '${_vm_name}'" \
        ${_vm_name}
      echo "Restarting '${_vm_name}' ..."
      multipass start ${_vm_name} -vv
    else
      echo "✅ Snapshot for '${_vm_name}' already present!"
    fi
  ||| % {
    hostname: vm.hostname,
  };

local provision_vms(config) =
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
  local vms = [vm.hostname for vm in config.virtual_machines];

  |||
    #!/usr/bin/env bash
    set -Eeuo pipefail

    if [[ $# -lt 1 ]]; then
      echo "$(tput setaf 2)Usage:$(tput sgr0) $(tput bold)$0 <name>$(tput sgr0)"
      echo "$(tput setaf 3)  Where <name> is one of:$(tput sgr0) $(tput bold)%(vms)s$(tput sgr0)"
      exit 1
    fi

    multipass %(command)s $1
  ||| % {
    vms: std.join(' ', vms),
    command: command,
  };

// Exported functions
{
  virtualmachines_bootstrap(config)::
    |||
      #!/usr/bin/env bash
      set -Eeuo pipefail

      this_file_path=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
      generated_files_path="${this_file_path}"

      echo "Creating VMs"
      %(vms_creation)s
    ||| % {
      vms_creation: shell_lines([
        create_vm(config, vm)
        for vm in config.virtual_machines
      ]),
    },
  virtualmachines_setup(config)::
    local vms = [vm.hostname for vm in config.virtual_machines];
    |||
      #!/usr/bin/env bash
      set -Eeuo pipefail

      this_file_path=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
      generated_files_path="${this_file_path}"
      vms_names_json=%(vms_names_json)s

      echo "Checking VMs"
      %(vms_check)s
      echo "Generating machines_config.json for ansible"
      multipass list --format json | \
        jq --argjson vms_names_json "${vms_names_json}" \
        '.list | [.[] | select(.name as $n | $vms_names_json | index($n))] as $vms | {list: $vms, nic: "default"}' \
        > "${generated_files_path}/"%(ansible_inventory_path)s/machines_config.json
      echo "VMs basic provisioning"
      %(vms_provision)s
      echo "Check snapshots for VMs"
      %(vms_snapshot)s
    ||| % {
      ansible_inventory_path: config.ansible_inventory_path,
      vms_check: shell_lines([
        check_vm(vm)
        for vm in config.virtual_machines
      ]),
      vms_provision: shell_lines([
        provision_vm(vm)
        for vm in config.virtual_machines
      ]),
      vms_snapshot: shell_lines([
        snapshot_vm(vm)
        for vm in config.virtual_machines
      ]),
      vms_names_json: std.escapeStringBash(
        std.manifestJsonMinified(vms)
      ),
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

      echo "Provisioning VMs"
      %(vms_provision)s
    ||| % {
      vms_provision: provision_vms(config),
    },
  virtualmachines_destroy(config)::
    assert std.isObject(config);
    assert std.objectHas(config, 'project_dir');
    |||
      #!/usr/bin/env bash
      set -Eeuo pipefail
      echo "Destroying VMs and Project data"
      %(vms_destroy)s
      echo "Deleting %(project_dir)s'"
      rm -rfv %(project_dir)s
    ||| % {
      vms_destroy: shell_lines([
        destroy_vm(config, vm)
        for vm in config.virtual_machines
      ]),
      project_dir: config.project_dir,
    },
  virtualmachines_list(config)::
    assert std.isObject(config);
    assert std.objectHas(config, 'virtual_machines');
    assert std.isArray(config.virtual_machines);
    local vms = [vm.hostname for vm in config.virtual_machines];

    |||
      #!/usr/bin/env bash
      set -Eeuo pipefail

      if [[ $# -lt 1 ]]; then
        machine_list="%(vms)s"
      else
        machine_list=$@
      fi
      multipass info \
        --format yaml ${machine_list}
    ||| % {
      vms: std.join(' ', vms),
    },
  virtualmachine_shell(config)::
    virtualmachine_command(config, 'shell'),
  virtualmachines_info(config)::
    virtualmachine_command(config, 'info --format yaml'),
}
