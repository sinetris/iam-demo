{
  cloud_config(config, vm)::
    assert std.isObject(config);
    assert std.objectHas(config, 'base_domain');
    assert std.isObject(vm);
    assert std.objectHas(vm, 'hostname');
    local tags =
      if std.objectHas(vm, 'tags') then
        assert std.isArray(vm.tags);
        vm.tags
      else [];
    local is_desktop = std.member(tags, 'desktop');
    local is_ansible_controller = std.member(tags, 'ansible-controller');
    local user_mapping(user) =
      assert std.isObject(user);
      assert std.objectHas(user, 'username');
      local is_admin = std.objectHas(user, 'is_admin') && user.is_admin;
      {
        name: user.username,
        shell: '/bin/bash',
        groups: if is_admin then [
          'adm',
          'audio',
          'cdrom',
          'dialout',
          'dip',
          'floppy',
          'lxd',
          'netdev',
          'plugdev',
          'ssl-cert',
          'staff',
          'sudo',
          'users',
          'video',
          'xrdp',
        ] else [
          'staff',
          'users',
          'xrdp',
        ],
        [if is_admin then 'sudo']: 'ALL=(ALL) NOPASSWD:ALL',
        [if std.objectHas(user, 'password') then 'passwd']: user.password,
        [if std.objectHas(user, 'plain_text_passwd') then 'plain_text_passwd']: user.plain_text_passwd,
        lock_passwd: if std.objectHas(user, 'password') ||
                        std.objectHas(user, 'plain_text_passwd') then false else true,
        [if std.objectHas(user, 'ssh_import_ids')
            && std.isArray(user.ssh_import_ids) then 'ssh_import_ids']:
          user.ssh_import_ids,
        [if std.objectHas(user, 'ssh_authorized_keys')
            && std.isArray(user.ssh_authorized_keys) then 'ssh_authorized_keys']:
          user.ssh_authorized_keys,
      };
    local runcmd_for_user(username) =
      local home_path = '/home/' + username;
      local ownership = username + ':' + username;
      [
        ['mkdir', '-p', home_path + '/bin'],
        ['chown', '-R', ownership, home_path + '/bin'],
        ['mkdir', '-p', home_path + '/.local/bin'],
        ['chown', '-R', ownership, home_path + '/.local'],
      ];
    local xsession_file() =
      {
        path: '/etc/skel/.xsession',
        content: |||
          xfce4-session
        |||,
        permissions: '0640',
      };

    local manifest = {
      hostname: vm.hostname,
      fqdn: '%(hostname)s.%(base_domain)s' % {
        hostname: vm.hostname,
        base_domain: config.base_domain,
      },
      prefer_fqdn_over_hostname: true,
      manage_etc_hosts: true,
      chpasswd: { expire: false },
      growpart: {
        mode: 'auto',
        devices: ['/'],
        ignore_growroot_disabled: false,
      },
      users: ['default'] + [user_mapping(user) for user in vm.users],
      apt: {
        primary: [
          {
            arches: ['default'],
            search: ['http://archive.ubuntu.com/ubuntu'],
            search_dns: true,
          },
        ],
        security: [
          {
            uri: 'http://security.ubuntu.com/ubuntu',
            arches: ['default'],
          },
        ],
      },
      package_update: true,
      package_upgrade: true,
      package_reboot_if_required: true,
      packages: [
        'ca-certificates',
        'build-essential',
        'python3',
        'python3-pip',
        'git',
        'curl',
        'wget',
        'ntp',
        'vim',
        'apt-transport-https',
        'gnupg2',
        'jq',
      ] + if is_desktop then [
        'xfce4',
        'xfce4-session',
        'xrdp',
        'xclip',
        'xfce4-clipman-plugin',
        'firefox',
      ] else [],
      runcmd: [
        ['apt', 'install', '--fix-broken', '-y'],
        ['apt', 'clean'],
        ['apt', 'auto-clean'],
      ] + if is_desktop then [
        ['snap', 'install', 'code', '--classic'],
        ['systemctl', 'enable', 'xrdp'],
        ['service', 'xrdp', 'restart'],
      ] else [] + std.flatMap(
        runcmd_for_user,
        ['ubuntu'] + [user.username for user in vm.users]
      ),
      write_files: if is_desktop then [
        xsession_file(),
      ] else [],
      final_message: |||
        ## template: jinja
        cloud-init final message
        version: {{version}}
        timestamp: {{timestamp}}
        datasource: {{datasource}}
        uptime: {{uptime}}
      |||,
      snaps: [
        {
          name: 'yq',
        },
      ],
    } + if is_ansible_controller then {
      lxd: {
        init: {
          storage_backend: 'dir',
        },
      },
    } else {};

    '#cloud-config\n'
    + std.manifestYamlDoc(
      manifest,
      quote_keys=false,
    ) + '\n',
}
