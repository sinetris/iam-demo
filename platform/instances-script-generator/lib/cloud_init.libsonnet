local addArrayIf(condition, array, elseArray=[]) = if condition then array else elseArray;

{
  cloud_config(config, instance)::
    assert std.isObject(config);
    assert std.objectHas(config, 'base_domain');
    assert std.isObject(instance);
    assert std.objectHas(instance, 'hostname');
    assert std.objectHas(instance, 'architecture');
    local tags =
      if std.objectHas(instance, 'tags') then
        assert std.isArray(instance.tags);
        instance.tags
      else [];
    local instance_users = addArrayIf(std.objectHas(instance, 'users'), instance.users);
    local instance_users_usernames = std.uniq(std.sort(['ubuntu'] + [user.username for user in instance_users]));
    local is_desktop = std.member(tags, 'desktop');
    local is_vnc_server = std.member(tags, 'vnc-server');
    local is_rdp_server = std.member(tags, 'rdpserver');
    local is_ansible_controller = std.member(tags, 'ansible-controller');
    local is_vbox = config.orchestrator_name == 'vbox';
    local code_pkg = 'https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-' + instance.architecture;
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
        ]) + addArrayIf(is_vbox, [
          'vboxsf',
        ]),
        [if is_admin then 'sudo']: 'ALL=(ALL) NOPASSWD:ALL',
        [if std.objectHas(user, 'password') then 'passwd']: user.password,
        [if std.objectHas(user, 'plain_text_passwd') then 'plain_text_passwd']: user.plain_text_passwd,
        lock_passwd: if std.objectHas(user, 'password') ||
                        std.objectHas(user, 'plain_text_passwd') then false else true,
        [if std.objectHas(user, 'ssh_import_id')
            && std.isArray(user.ssh_import_id) then 'ssh_import_id']:
          user.ssh_import_id,
        [if std.objectHas(user, 'ssh_authorized_keys')
            && std.isArray(user.ssh_authorized_keys) then 'ssh_authorized_keys']:
          user.ssh_authorized_keys,
      };
    local runcmd_fix_home_for_user(username) =
      local home_path = '/home/' + username;
      local ownership = username + ':' + username;
      [
        ['mkdir', '-p', home_path + '/bin'],
        ['chown', '-R', ownership, home_path + '/bin'],
        ['mkdir', '-p', home_path + '/.local/bin'],
        ['chown', '-R', ownership, home_path + '/.local'],
      ];
    local runcmd_fix_gsettings_for_user(username) =
      [
        ['sudo', '-u', username, '-H', 'gsettings', 'reset-recursively', 'com.canonical.unity.settings-daemon.plugins.power'],
        ['sudo', '-u', username, '-H', 'gsettings', 'reset-recursively', 'org.gnome.settings-daemon.plugins.power'],
        ['sudo', '-u', username, '-H', 'gsettings', 'reset-recursively', 'org.gnome.desktop.session'],
        ['sudo', '-u', username, '-H', 'gsettings', 'reset-recursively', 'org.gnome.desktop.screensaver'],
      ];
    local write_files() = [
      {
        path: '/var/local/.test',
        content: |||
          File created!
        |||,
        permissions: '0o640',
      },
    ] + addArrayIf(is_desktop, [
      {
        path: '/etc/skel/.xsession',
        content: |||
          xfce4-session
        |||,
        permissions: '0o640',
      },
      {
        path: '/usr/share/glib-2.0/schemas/certification.gschema.override',
        content: |||
          [com.canonical.unity.settings-daemon.plugins.power]
          sleep-inactive-ac-timeout=0
          sleep-inactive-battery-timeout=0
          sleep-inactive-battery-type='nothing'
          sleep-inactive-ac-type='nothing'
          idle-dim=false
          [org.gnome.settings-daemon.plugins.power]
          sleep-inactive-ac-timeout=0
          sleep-inactive-battery-timeout=0
          sleep-inactive-battery-type='nothing'
          sleep-inactive-ac-type='nothing'
          idle-dim=false
          [org.gnome.desktop.session]
          idle-delay=0
          [org.gnome.desktop.screensaver]
          ubuntu-lock-on-suspend=false
          lock-enabled=false
          idle-activation-enabled=false
        |||,
      },
    ]) + addArrayIf(is_vnc_server, [
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
    ]);

    local manifest = {
      hostname: instance.hostname,
      fqdn: '%(hostname)s.%(base_domain)s' % {
        hostname: instance.hostname,
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
      users: ['default'] + [user_mapping(user) for user in instance_users],
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
        'libpam-systemd',
        'dbus',
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
      ]) + addArrayIf(is_vbox, [
        'linux-headers-generic',
        'perl',
        'make',
      ]) + addArrayIf(is_vnc_server, [
        'lightdm',
        'xvfb',
        'novnc',
        'x11vnc',
      ]),
      runcmd: addArrayIf(is_vbox, [
        ['mkdir', '-p', '/mnt/additions'],
        ['mount', '-t', 'iso9660', '-o', 'ro', '/dev/sr1', '/mnt/additions'],
        // ['/mnt/additions/${_additions_file}'],
        ['/mnt/additions/VBoxLinuxAdditions-arm64.run'],
      ]) + addArrayIf(is_rdp_server, [
        ['systemctl', 'enable', 'xrdp'],
        ['service', 'xrdp', 'restart'],
      ]) + addArrayIf(is_vnc_server, [
        ['x11vnc', '-storepasswd', 'iamdemo', '/etc/x11vnc.passwd'],
        ['systemctl', 'enable', 'x11vnc'],
        ['service', 'x11vnc', 'restart'],
      ]) + addArrayIf(is_desktop, [
        ['sed -i', 's/^#\\?AllowSuspend=.*/AllowSuspend=no/', '/etc/systemd/sleep.conf'],
        ['sed -i', 's/^#\\?AllowHibernation=.*/AllowHibernation=no/', '/etc/systemd/sleep.conf'],
        ['sed -i', 's/^#\\?AllowSuspendThenHibernate=.*/AllowSuspendThenHibernate=no/', '/etc/systemd/sleep.conf'],
        ['sed -i', 's/^#\\?AllowHybridSleep=.*/AllowHybridSleep=no/', '/etc/systemd/sleep.conf'],
        ['glib-compile-schemas', '/usr/share/glib-2.0/schemas'],
      ] + std.flatMap(
        runcmd_fix_gsettings_for_user,
        ['lightdm'] + instance_users_usernames
      )) + std.flatMap(
        runcmd_fix_home_for_user,
        instance_users_usernames
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
        run_user: instance.admin_username,
      },
    } else {} + if is_vbox then {
      power_state: {
        mode: 'reboot',
        timeout: 30,
        condition: true,
      },
    } else {};

    // Result
    '#cloud-config\n'
    + std.manifestYamlDoc(
      manifest,
      quote_keys=false,
    ) + '\n',
}
