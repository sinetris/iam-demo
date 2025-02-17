{
  fake_script(config, action)::
    |||
      #!/usr/bin/env bash

      echo "- Instances %(action)s -"
      %(instances)s
    ||| % {
      action: action,
      instances: std.join('\n', [
        'echo ' + std.escapeStringBash(instance.hostname)
        for instance in config.virtual_machines
      ]),
    },
  virtualmachines_bootstrap(config)::
    self.fake_script(config, 'bootstrap'),
  virtualmachines_setup(config)::
    self.fake_script(config, 'setup'),
  virtualmachines_provisioning(config)::
    self.fake_script(config, 'provisioning'),
  virtualmachines_destroy(config)::
    self.fake_script(config, 'destroy'),
  virtualmachines_list(config)::
    self.fake_script(config, 'list'),
  virtualmachine_shell(config)::
    self.fake_script(config, 'shell'),
  virtualmachines_info(config)::
    self.fake_script(config, 'info'),
}
