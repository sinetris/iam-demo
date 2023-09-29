local shell_lines(lines) =
  std.stripChars(
    std.join('', lines),
    '\n'
  );

local create_vm(config, vm) =
  assert std.isObject(config);
  assert std.objectHas(config, 'app_dir');
  assert std.isObject(vm);
  assert std.objectHas(vm, 'hostname');
  local cpus = std.get(vm, 'cpus', '1');
  local storage_space = std.get(vm, 'storage_space', '5G');
  local memory = std.get(vm, 'memory', '1G');

  local mount_opt(host_path, guest_path) =
    '--mount "%(host_path)s":%(guest_path)s' % {
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
    echo "Checking '%(hostname)s'..."
    vm_status=$(multipass info --format yaml %(hostname)s 2>&1) && exit_code=$? || exit_code=$?
    if [ $exit_code -eq 0 ]; then
      echo "VM '%(hostname)s' already exist ✅"
    elif [ $exit_code -eq 2 ] && [[ $vm_status =~ 'does not exist' ]]; then
      echo "Creating %(host_path)s/data"
      mkdir -p "%(host_path)s/data"
      multipass launch --cpus %(cpus)s \
        --disk %(storage_space)s \
        --memory %(memory)s \
        --name "%(hostname)s" \
        --cloud-init "cloud-init-%(hostname)s.yaml" \
        --timeout %(timeout)s \
        %(mounts)s release:jammy
    else
      echo "VM '%(hostname)s' - exit code '${exit_code}'"
      echo ${vm_status}
    fi
  ||| % {
    hostname: vm.hostname,
    host_path: vm.host_path,
    cpus: vm.cpus,
    storage_space: vm.storage_space,
    timeout: vm.timeout,
    memory: vm.memory,
    mounts: std.join(' ', mounts),
    app_dir: config.app_dir,
  };

local destroy_vm(config, vm) =
  assert std.isObject(vm);
  assert std.objectHas(vm, 'hostname');

  |||
    multipass delete --purge "%(hostname)s"
  ||| % {
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
  
      |||
        multipass exec %(destination_host)s \
          %(working_directory)s -- \
          /bin/bash <<-'END'
        %(script)s
        END
      ||| % {
        working_directory: cwd,
        script: std.stripChars(opts.script, '\n'),
        destination_host: opts.destination_host,
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

{
  virtualmachines_bootstrap(config)::
    local provisionings = 
      if std.objectHas(config, 'base_provisionings') then
        config.base_provisionings
      else [];
    |||
      #!/usr/bin/env bash
      set -Eeuo pipefail

      this_file_path=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

      echo "Creating VMs"
      %(vms_creation)s
      echo "Generating machines_config.json for ansible"
      multipass list --format json > %(ansible_inventory_path)s/machines_config.json
      %(vms_provision)s
    ||| % {
      ansible_inventory_path: config.ansible_inventory_path,
      app_dir: config.app_dir,
      vms_creation: shell_lines([
        create_vm(config, vm)
        for vm in config.virtual_machines
      ]),
      vms_provision: provision_vms(config, provisionings),
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
      app_dir: config.app_dir,
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
  virtualmachine_shell(config)::
    assert std.isObject(config);
    assert std.objectHas(config, 'virtual_machines');
    assert std.isArray(config.virtual_machines);

    local vms = [vm.hostname for vm in config.virtual_machines];

    |||
      #!/usr/bin/env bash
      set -Eeuo pipefail

      if [ $# -lt 1 ]; then
        echo $(tput setaf 2)Usage:$(tput sgr0) $(tput bold)$0 [OPTIONS]$(tput sgr0)
        exit 1
      fi

      multipass shell $1
    |||,
}
