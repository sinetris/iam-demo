local config = import 'config.libsonnet';
assert std.isObject(config);

local admin_user =
  local use_ssh_authorized_keys =
    std.objectHas(config, 'admin_ssh_authorized_keys')
    && std.isArray(config.admin_ssh_authorized_keys)
    && std.length(config.admin_ssh_authorized_keys) > 0;
  local use_ssh_import_ids =
    std.objectHas(config, 'admin_ssh_import_ids')
    && std.isArray(config.admin_ssh_import_ids)
    && std.length(config.admin_ssh_import_ids) > 0;
  {
    username: config.admin_username,
    is_admin: true,
    password: config.admin_password,
    [if use_ssh_authorized_keys then 'ssh_authorized_keys']:
      config.admin_ssh_authorized_keys,
    [if use_ssh_import_ids then 'ssh_import_ids']:
      config.admin_ssh_import_ids,
  };
local ansible_user =
  local use_ssh_authorized_keys =
    std.objectHas(config, 'ansible_ssh_authorized_keys')
    && std.isArray(config.ansible_ssh_authorized_keys)
    && std.length(config.ansible_ssh_authorized_keys) > 0;
  local use_ssh_import_ids =
    std.objectHas(config, 'ansible_ssh_import_ids')
    && std.isArray(config.ansible_ssh_import_ids)
    && std.length(config.ansible_ssh_import_ids) > 0;
  {
    username: 'ansible',
    is_admin: true,
    [if use_ssh_authorized_keys then 'ssh_authorized_keys']:
      config.ansible_ssh_authorized_keys,
    [if use_ssh_import_ids then 'ssh_import_ids']:
      config.ansible_ssh_import_ids,
  };

local add_default_machine_data(setup, vm) =
  assert std.isObject(setup);
  assert std.objectHas(vm, 'hostname');
  assert std.isObject(vm);
  assert std.objectHas(vm, 'hostname');
  {
    project_host_path: setup.project_dir + '/instances/' + vm.hostname,
    cpus: 1,
    architecture: std.extVar('prefix'),
    memory: '1024',
    timeout: 15 * 60,
    storage_space: '10240',
    admin_username: config.admin_username,
    users: [admin_user],
    mounts: [
      {
        host_path: $.project_host_path + '/shared',
        guest_path: '/var/local/data',
      },
    ],
    provisionings: [
      {
        type: 'inline-shell',
        script:
          |||
            set -Eeuo pipefail
            cloud-init status --wait --long
          |||,
      },
    ],
  } + vm;

{
  local setup = self,
  project_name: config.project_name,
  project_dir: '$HOME/.local/projects/' + config.project_name,
  ansible_inventory_path:
    if std.objectHas(config, 'ansible_inventory_path') then
      config.ansible_inventory_path
    else '.',
  base_domain: 'iam-demo.test',
  virtual_machines: [
    add_default_machine_data(setup, {
      hostname: 'ansible-controller',
      memory: '2048',
      mounts+: [
        {
          host_path: '${generated_files_path}/' + config.ansible_files_path,
          guest_path: '/ansible',
        },
        {
          host_path: '${generated_files_path}/' + config.kubernetes_files_path,
          guest_path: '/kubernetes',
        },
      ],
      tags: [
        'ansible-controller',
      ],
      base_provisionings: [
        {
          type: 'file',
          source_host: 'localhost',
          source: './assets/.ssh/id_ed25519.pub',
          destination: '/home/ubuntu/.ssh/id_ed25519.pub',
          create_parents_dir: true,
        },
        {
          type: 'file',
          source_host: 'localhost',
          source: './assets/.ssh/id_ed25519',
          destination: '/home/ubuntu/.ssh/id_ed25519',
          create_parents_dir: true,
        },
        {
          type: 'inline-shell',
          script:
            |||
              set -Eeuo pipefail
              sudo chown ubuntu /home/ubuntu/.ssh/id_*
              sudo chmod u=rw,go= /home/ubuntu/.ssh/id_*
              sudo apt-get install -y ansible
            |||,
        },
        {
          type: 'inline-shell',
          working_directory: '/ansible',
          script:
            |||
              set -Eeuo pipefail
              source $HOME/.profile
              cat inventory/machines_config.json \
                | jq '.list | {all: {hosts: map({(.name|tostring): {ansible_host: .ipv4[0]}}) | add}}' \
                | yq -P > inventory/machines_ips
              cat inventory/machines_config.json \
                | jq '.list | {named_hosts: map({(.name|tostring): .ipv4[0]}) | add}' \
                | yq -P > inventory/group_vars/all/10-hosts
              cat inventory/machines_config.json \
                | jq '.network_interface as $n | {network_interface_name: $n}' \
                | yq -P > inventory/group_vars/all/90-config
              ansible 'all' -m ping
            |||,
        },
      ],
    }),
    add_default_machine_data(setup, {
      hostname: 'iam-control-plane',
      cpus: 8,
      memory: '16384',
      storage_space: '25600',
      tags: [
        'kubernetes',
        'nested-hw-virtualization',
      ],
      users+: [ansible_user],
    }),
    add_default_machine_data(setup, {
      hostname: 'linux-desktop',
      cpus: 2,
      memory: '4096',
      tags: [
        'rdpserver',
        'desktop',
      ],
      users+: [ansible_user],
    }),
  ],
  provisionings: [
    {
      type: 'inline-shell',
      destination_host: 'ansible-controller',
      working_directory: '/ansible',
      script:
        |||
          set -Eeuo pipefail
          source $HOME/.profile
          ansible-playbook playbooks/bootstrap-ansible-controller
          ansible-playbook playbooks/bootstrap-bind
          ansible-playbook playbooks/basic-bootstrap
        |||,
    },
    {
      type: 'inline-shell',
      destination_host: 'ansible-controller',
      working_directory: '/ansible',
      script:
        |||
          set -Eeuo pipefail
          [ -f /var/run/reboot-required ] && exit 1 || exit 0
        |||,
      reboot_on_error: true,
    },
    {
      type: 'inline-shell',
      destination_host: 'ansible-controller',
      working_directory: '/ansible',
      script:
        |||
          set -Eeuo pipefail
          source $HOME/.profile
          ansible-playbook playbooks/all-setup
        |||,
    },
  ],
  network: config.network,
  dns_servers: config.dns_servers,
}
