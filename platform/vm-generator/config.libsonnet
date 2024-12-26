{
  project_name: 'iam-demo',
  architecture: 'arm64',
  ansible_ssh_authorized_keys: [
    std.stripChars(importstr 'generated/.ssh/id_ed25519.pub', '\n'),
  ],
  ansible_files_path: '../../ansible',
  ansible_inventory_path: self.ansible_files_path + '/inventory',
  kubernetes_files_path: '../../../kubernetes',
  admin_user: 'iamadmin',
  // admin_password: iamadmin
  admin_password: '$6$rounds=4096$.GbV2RZ47jEOvD9b$IBMMXMXlnsL7mZ25fc6PJ4as4.w48e6p9nsuvLXr8HJH8F2aHJbAEF6uaB4VWIXWYzu5MvLdnjhlzv7zd6sPQ0',
  admin_ssh_authorized_keys: self.ansible_ssh_authorized_keys,
  ansible_ssh_import_ids: [
    // "gh:octocat",
  ],
  admin_ssh_import_ids: self.ansible_ssh_import_ids,
  network: {
    name: 'HON',
    netmask: '255.255.255.0',
    lower_ip: '192.168.100.1',
    upper_ip: '192.168.100.100',
  },
  dns_servers: [
    '1.1.1.1',
  ],
}
