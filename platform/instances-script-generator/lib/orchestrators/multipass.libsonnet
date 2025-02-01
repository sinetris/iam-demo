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
  assert std.objectHas(instance, 'hostname');
  assert std.objectHas(instance, 'project_host_path');
  local cpus = std.get(instance, 'cpus', '1');
  local storage_space = std.get(instance, 'storage_space', '5000');
  local memory = std.get(instance, 'memory', '1024');
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
    _instance_name=%(hostname)s
    echo "Checking '${_instance_name}'..."
    _instance_status=$(multipass info --format yaml ${_instance_name} 2>&1) && _exit_code=$? || _exit_code=$?
    if [[ $_exit_code -eq 0 ]]; then
      echo "✅ Instance '${_instance_name}' already exist!"
    elif [[ $_exit_code -eq 2 ]] && [[ $_instance_status =~ 'does not exist' ]]; then
      echo 'Creating "%(project_host_path)s"'
      mkdir -p "%(project_host_path)s/shared"
      multipass launch --cpus %(cpus)s \
        --disk %(storage_space)sM \
        --memory %(memory)sM \
        --name "${_instance_name}" \
        --cloud-init "assets/cloud-init-${_instance_name}.yaml" \
        --timeout %(timeout)s \
        %(mounts)s release:%(guest_os_release)s
    else
      echo "❌ Instance '${_instance_name}' - exit code '${_exit_code}'"
      echo ${_instance_status}
      exit 2
    fi
  ||| % {
    hostname: instance.hostname,
    project_host_path: instance.project_host_path,
    cpus: instance.cpus,
    storage_space: instance.storage_space,
    timeout: instance.timeout,
    memory: instance.memory,
    mounts: indent(std.join(' \\\n', mounts), '    '),
    guest_os_release: guest_os_release,
  };

local destroy_instance(config, instance) =
  assert std.isObject(instance);
  assert std.objectHas(instance, 'hostname');

  |||
    _instance_name=%(hostname)s
    multipass delete --purge "${_instance_name}"
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

      this_file_path=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
      generated_files_path="${this_file_path}"

      echo "Creating instances"
      %(instances_creation)s
    ||| % {
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
      instances_names_json=%(instances_names_json)s

      echo "Checking instances"
      %(instances_check)s
      echo "Generating machines_config.json for ansible"
      multipass list --format json | \
        jq --argjson instances_names_json "${instances_names_json}" \
        '.list | [.[] | select(.name as $n | $instances_names_json | index($n))] as $instances | {list: $instances, network_interface: "default"}' \
        > "${generated_files_path}/"%(ansible_inventory_path)s/machines_config.json
      echo "Instances basic provisioning"
      %(instances_provision)s
      echo "Check snapshots for instances"
      %(instances_snapshot)s
    ||| % {
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
      instances_names_json: std.escapeStringBash(
        std.manifestJsonMinified(instances)
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

      echo "Provisioning instances"
      %(instances_provision)s
    ||| % {
      instances_provision: provision_instances(config),
    },
  virtualmachines_destroy(config)::
    assert std.isObject(config);
    assert std.objectHas(config, 'project_dir');
    |||
      #!/usr/bin/env bash
      set -Eeuo pipefail
      echo "Destroying instances and project data"
      %(instances_destroy)s
      echo "Deleting %(project_dir)s'"
      rm -rfv %(project_dir)s
    ||| % {
      instances_destroy: shell_lines([
        destroy_instance(config, instance)
        for instance in config.virtual_machines
      ]),
      project_dir: config.project_dir,
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
