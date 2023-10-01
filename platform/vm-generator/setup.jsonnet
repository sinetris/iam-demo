local config = import 'config.jsonnet';
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
    username: config.admin_user,
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

local add_default_machine_data(vm) = {
  host_path: error 'Must override "host_path"',
  cpus: 1,
  memory: '1G',
  timeout: 15 * 60,
  storage_space: '10G',
  users: [admin_user],
  mounts: [
    {
      host_path: $.host_path + '/data',
      guest_path: '/var/local/data',
    },
  ],
} + vm;

{
  application: 'iam-demo',
  app_dir: '$HOME/.local/projects-data/' + self.application,
  ansible_inventory_path:
    if std.objectHas(config, 'ansible_inventory_path') then
      config.ansible_inventory_path
    else '.',
  base_domain: 'iam-demo.test',
  virtual_machines: [
    add_default_machine_data({
      hostname: 'ansible-controller',
      host_path: $.app_dir + '/' + self.hostname,
      mounts+: [
        {
          host_path: config.ansible_files_path,
          guest_path: '/ansible',
        },
        {
          host_path: config.kubernetes_files_path,
          guest_path: '/kubernetes',
        },
      ],
      tags: [
        'ansible-controller',
      ],
    }),
    add_default_machine_data({
      local vm = self,
      hostname: 'iam-control-plane',
      host_path: $.app_dir + '/' + self.hostname,
      cpus: 4,
      memory: '8G',
      storage_space: '25G',
      tags: [
        'kubernetes',
        'nested-hw-virtualization',
      ],
      users+: [ansible_user],
    }),
    add_default_machine_data({
      hostname: 'linux-desktop',
      host_path: $.app_dir + '/' + self.hostname,

      cpus: 2,
      memory: '4G',
      tags: [
        'desktop',
      ],
      users+: [ansible_user],
    }),
  ],
  base_provisionings: [
    {
      type: 'file',
      destination_host: 'ansible-controller',
      source_host: 'localhost',
      source: './.ssh/id_ed25519.pub',
      destination: '/home/ubuntu/.ssh/id_ed25519.pub',
      create_parents_dir: true,
    },
    {
      type: 'file',
      destination_host: 'ansible-controller',
      source_host: 'localhost',
      source: './.ssh/id_ed25519',
      destination: '/home/ubuntu/.ssh/id_ed25519',
      create_parents_dir: true,
    },
    {
      type: 'inline-shell',
      destination_host: 'ansible-controller',
      script:
        |||
          set -Eeuo pipefail
          cloud-init status --wait --long
          source $HOME/.profile
          sudo snap install yq
          python3 -m pip install --no-input --upgrade pip --user
          python3 -m pip install --no-input --user argcomplete
          [ -f ~/.bash_completion ] || activate-global-python-argcomplete --user
          python3 -m pip install --no-input ansible --user
          python3 -m pip install --no-input ansible-lint --user
          sudo chown ubuntu /home/ubuntu/.ssh/id_*
          sudo chmod u=rw,go= /home/ubuntu/.ssh/id_*
        |||,
    },
    {
      type: 'inline-shell',
      destination_host: 'ansible-controller',
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
          ansible 'all' -m ping
        |||,
    },
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
  ],
  app_provisionings: [
    {
      type: 'inline-shell',
      destination_host: 'ansible-controller',
      working_directory: '/ansible',
      script:
        |||
          set -Eeuo pipefail
          source $HOME/.profile
          ansible-playbook playbooks/k3s-bootstrap
          ansible-playbook playbooks/k3s-provisioning
          ansible-playbook playbooks/k3s-copy-config
        |||,
    },
  ],
}
