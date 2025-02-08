local config = import 'config.libsonnet';
assert std.isObject(config);

local admin_user =
  local use_ssh_authorized_keys =
    std.objectHas(config, 'admin_ssh_authorized_keys')
    && std.isArray(config.admin_ssh_authorized_keys)
    && std.length(config.admin_ssh_authorized_keys) > 0;
  local use_ssh_import_id =
    std.objectHas(config, 'admin_ssh_import_id')
    && std.isArray(config.admin_ssh_import_id)
    && std.length(config.admin_ssh_import_id) > 0;
  {
    username: config.admin_username,
    is_admin: true,
    password: config.admin_password,
    [if use_ssh_authorized_keys then 'ssh_authorized_keys']:
      config.admin_ssh_authorized_keys,
    [if use_ssh_import_id then 'ssh_import_id']:
      config.admin_ssh_import_id,
  };
local ansible_user =
  local use_ssh_authorized_keys =
    std.objectHas(config, 'ansible_ssh_authorized_keys')
    && std.isArray(config.ansible_ssh_authorized_keys)
    && std.length(config.ansible_ssh_authorized_keys) > 0;
  local use_ssh_import_id =
    std.objectHas(config, 'ansible_ssh_import_id')
    && std.isArray(config.ansible_ssh_import_id)
    && std.length(config.ansible_ssh_import_id) > 0;
  {
    username: 'ansible',
    is_admin: true,
    [if use_ssh_authorized_keys then 'ssh_authorized_keys']:
      config.ansible_ssh_authorized_keys,
    [if use_ssh_import_id then 'ssh_import_id']:
      config.ansible_ssh_import_id,
  };

local add_default_machine_data(setup, instance) =
  assert std.isObject(setup);
  assert std.objectHas(instance, 'hostname');
  assert std.isObject(instance);
  assert std.objectHas(instance, 'hostname');
  {
    basefolder: setup.project_basefolder + '/instances/' + instance.hostname,
    cpus: 1,
    architecture: setup.host_architecture,
    memory: '1024',
    timeout: 15 * 60,
    storage_space: '10240',
    admin_username: config.admin_username,
    users: [admin_user],
    mounts: [
      {
        host_path: $.basefolder + '/shared',
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
  } + instance;

// Exported
{
  local setup = self,
  project_name: config.project_name,
  project_domain: config.base_domain,
  host_architecture: std.extVar('host_architecture'),
  orchestrator_name: std.extVar('orchestrator_name'),
  projects_folder: '$HOME/.local/projects',
  project_basefolder: self.projects_folder + '/' + self.project_name,
  os_release_codename: 'noble',
  ansible_inventory_path:
    if std.objectHas(config, 'ansible_inventory_path') then
      config.ansible_inventory_path
    else '.',
  base_domain: config.base_domain,
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
              echo '# Generated file' > inventory/machines_ips
              cat inventory/machines_config.json \
                | jq '.list | {all: {hosts: map({(.name|tostring): {ansible_host: .ipv4[0]}}) | add}}' \
                | yq -P >> inventory/machines_ips
              echo '# Generated file' > inventory/group_vars/all/10-hosts
              cat inventory/machines_config.json \
                | jq '.list | {named_hosts: map({(.name|tostring): .ipv4[0]}) | add}' \
                | yq -P >> inventory/group_vars/all/10-hosts
              echo '# Generated file' > inventory/group_vars/all/90-config
              cat inventory/machines_config.json \
                | jq '.network_interface as $n | {network_interface_name: $n}' \
                | yq -P >> inventory/group_vars/all/90-config
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
