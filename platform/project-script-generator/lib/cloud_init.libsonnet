local addArrayIf(condition, array, elseArray=[]) = if condition then array else elseArray;

{
  cloud_config(setup, instance)::
    assert std.isObject(setup);
    assert std.objectHas(setup, 'base_domain');
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
    local install_recommends = std.get(instance, 'install_recommends', false);
    local is_rdp_server = std.member(tags, 'rdpserver');
    local is_ansible_controller = std.member(tags, 'ansible-controller');
    local is_vbox = setup.orchestrator_name == 'vbox';
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
    ]);

    local manifest = {
      hostname: instance.hostname,
      fqdn: '%(hostname)s.%(base_domain)s' % {
        hostname: instance.hostname,
        base_domain: setup.base_domain,
      },
      prefer_fqdn_over_hostname: true,
      manage_etc_hosts: true,
      chpasswd: { expire: false },
      growpart: {
        mode: 'auto',
        devices: ['/'],
        ignore_growroot_disabled: false,
      },
      users: [user_mapping(user) for user in instance_users],
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
        ||| % { install_recommends: install_recommends },
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
        'lightdm',
        'xclip',
        'xfce4-clipman-plugin',
        'xfce4-goodies',
        'xfce4',
      ]) + addArrayIf(is_rdp_server, [
        'xrdp',
      ]) + addArrayIf(is_vbox, [
        'linux-headers-generic',
        'perl',
        'make',
      ]),
      runcmd: addArrayIf(is_vbox, [
        ['mkdir', '-p', '/mnt/additions'],
        ['mount', '-t', 'iso9660', '-o', 'ro', '/dev/sr1', '/mnt/additions'],
        // ['/mnt/additions/${_additions_file}'],
        ['/mnt/additions/VBoxLinuxAdditions-arm64.run'],
      ]) + addArrayIf(is_rdp_server, [
        ['systemctl', 'enable', 'xrdp'],
        ['service', 'xrdp', 'restart'],
      ]) + addArrayIf(is_desktop, [
        ['sed -i', 's/^#\\?AllowSuspend=.*/AllowSuspend=no/', '/etc/systemd/sleep.conf'],
        ['sed -i', 's/^#\\?AllowHibernation=.*/AllowHibernation=no/', '/etc/systemd/sleep.conf'],
        ['sed -i', 's/^#\\?AllowSuspendThenHibernate=.*/AllowSuspendThenHibernate=no/', '/etc/systemd/sleep.conf'],
        ['sed -i', 's/^#\\?AllowHybridSleep=.*/AllowHybridSleep=no/', '/etc/systemd/sleep.conf'],
        ['glib-compile-schemas', '/usr/share/glib-2.0/schemas'],
        ['systemctl', 'disable', 'systemd-networkd.service'],
      ]) + std.flatMap(
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
