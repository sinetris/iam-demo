local addArrayIf(condition, array, elseArray=[]) = if condition then array else elseArray;

{
  cloud_config(config, vm)::
    assert std.isObject(config);
    assert std.objectHas(config, 'base_domain');
    assert std.isObject(vm);
    assert std.objectHas(vm, 'hostname');
    assert std.objectHas(vm, 'architecture');
    local tags =
      if std.objectHas(vm, 'tags') then
        assert std.isArray(vm.tags);
        vm.tags
      else [];
    local is_desktop = std.member(tags, 'desktop');
    local is_vnc_server = std.member(tags, 'vnc-server');
    local is_rdp_server = std.member(tags, 'rdpserver');
    local is_ansible_controller = std.member(tags, 'ansible-controller');
    local code_pkg = 'https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-' + vm.architecture;
    local user_mapping(user) =
      assert std.isObject(user);
      assert std.objectHas(user, 'username');
      local is_admin = std.objectHas(user, 'is_admin') && user.is_admin;
      {
        name: user.username,
        shell: '/bin/bash',
        groups: addArrayIf(is_admin, [
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
          'rdptest',
        ], [
          'staff',
          'users',
        ]) + addArrayIf(is_rdp_server, [
          'xrdp',
        ]),
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
    local write_files() = [
      {
        path: '/var/local/.test',
        content: |||
          File created!
        |||,
        permissions: '0o640',
      },
    ] + if is_desktop then [
      {
        path: '/etc/skel/.xsession',
        content: |||
          xfce4-session
        |||,
        permissions: '0o640',
      },
    ] else [] + if is_vnc_server then [
      {
        path: '/lib/systemd/system/x11vnc.service',
        content: |||
          [Unit]
          Description=VNC service
          Requires=display-manager.service
          After=display-manager.service

          [Service]
          Type=forking
          ExecStart=/usr/bin/x11vnc -forever -noxrecord -auth guess -rfbauth /etc/x11vnc.passwd
          # /usr/bin/x11vnc -display :0 -noxrecord -noxfixes -noxdamage -auth guess -rfbauth /etc/x11vnc.passwd
          ExecStop=/usr/bin/killall x11vnc
          Restart=on-failure
          RestartSec=10

          [Install]
          WantedBy=multi-user.target
        |||,
        permissions: '0o644',
      },
    ] else [];

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
        // APT config
        conf: |||
          APT {
            Install-Recommends "%(install_recommends)s";
            Install-Suggests "false";
            Get {
              Fix-Broken "true";
            };
          };
        ||| % { install_recommends: is_desktop },
      },
      package_update: true,
      package_upgrade: true,
      packages: [
        'ca-certificates',
        'build-essential',
        'python3',
        'python3-pip',
        'git',
        'curl',
        'wget',
        'snapd',
        'openssh-server',
        'vim',
        'apt-transport-https',
        'gnupg2',
        'jq',
      ] + addArrayIf(is_desktop, [
        'xfce4',
        'xfce4-session',
        'xfce4-goodies',
        'xfce4-panel',
        'xfce4-terminal',
        'xfce4-clipman-plugin',
        'xclip',
      ]) + addArrayIf(is_rdp_server, [
        'xrdp',
      ]) + addArrayIf(is_vnc_server, [
        'lightdm',
        'xvfb',
        'novnc',
        'x11vnc',
      ]),
      runcmd: addArrayIf(is_rdp_server, [
        ['systemctl', 'enable', 'xrdp'],
        ['service', 'xrdp', 'restart'],
      ]) + addArrayIf(is_vnc_server, [
        ['x11vnc', '-storepasswd', 'iamdemo', '/etc/x11vnc.passwd'],
        ['systemctl', 'enable', 'x11vnc'],
        ['service', 'x11vnc', 'restart'],
      ]) + std.flatMap(
        runcmd_for_user,
        ['ubuntu'] + [user.username for user in vm.users]
      ),
      write_files: write_files(),
      final_message: |||
        ## template: jinja
        cloud-init final message
        version: {{version}}
        timestamp: {{timestamp}}
        datasource: {{datasource}}
        uptime: {{uptime}}
      |||,
      snap: {
        commands: [
          ['install', 'yq'],
        ],
      },
    } + if is_ansible_controller then {
      ansible: {
        package_name: 'ansible-core',
        install_method: 'distro',
        run_user: vm.admin_username,
      },
    } else {};

    '#cloud-config\n'
    + std.manifestYamlDoc(
      manifest,
      quote_keys=false,
    ) + '\n',
}
