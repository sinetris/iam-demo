{
  project_name: 'iam-demo',
  architecture: 'arm64',
  ansible_ssh_authorized_keys: [
    std.stripChars(importstr 'id_ed25519.pub', '\n'),
  ],
  // Files path relative to 'virtual-machines.jsonnet'
  ansible_files_path: '../../ansible',
  ansible_inventory_path: self.ansible_files_path + '/inventory',
  // Files path relative to 'virtual-machines.jsonnet'
  kubernetes_files_path: '../../../kubernetes',
  admin_username: 'iamadmin',
  admin_password: std.stripChars(importstr 'admin_password', '\n'),
  admin_ssh_authorized_keys: self.ansible_ssh_authorized_keys,
  ansible_ssh_import_ids: [
    'gh:octocat',
  ],
  admin_ssh_import_ids: self.ansible_ssh_import_ids,
}
