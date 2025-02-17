{
  project_name: 'iam-demo',
  architecture: 'arm64',
  ansible_ssh_authorized_keys: [
    std.stripChars(importstr 'id_ed25519.pub', '\n'),
  ],
  // Files path relative to 'generated' directory
  ansible_files_path: '../../ansible',
  ansible_inventory_path: self.ansible_files_path + '/inventory',
  // Files path relative to 'generated' directory
  kubernetes_files_path: '../../../kubernetes',
  admin_username: 'ubuntu',
  admin_password: std.stripChars(importstr 'admin_password', '\n'),
  admin_ssh_authorized_keys: self.ansible_ssh_authorized_keys,
  admin_ssh_import_id: [
    'gh:octocat',
  ],
}
