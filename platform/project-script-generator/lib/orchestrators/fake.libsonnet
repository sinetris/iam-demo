{
  fake_script(setup, action)::
    |||
      #!/usr/bin/env bash

      echo "- Instances %(action)s -"
      %(instances)s
    ||| % {
      action: action,
      instances: std.join('\n', [
        'echo ' + std.escapeStringBash(instance.hostname)
        for instance in setup.virtual_machines
      ]),
    },
  virtualmachines_bootstrap(setup)::
    self.fake_script(setup, 'bootstrap'),
  virtualmachines_setup(setup)::
    self.fake_script(setup, 'setup'),
  virtualmachines_provisioning(setup)::
    self.fake_script(setup, 'provisioning'),
  virtualmachines_destroy(setup)::
    self.fake_script(setup, 'destroy'),
  virtualmachines_list(setup)::
    self.fake_script(setup, 'list'),
  virtualmachine_shell(setup)::
    self.fake_script(setup, 'shell'),
  virtualmachines_info(setup)::
    self.fake_script(setup, 'info'),
}
