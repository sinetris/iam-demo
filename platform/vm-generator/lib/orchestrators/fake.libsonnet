{
  fake_script(config, action)::
    |||
      #!/usr/bin/env bash

      echo "- VMs %(action)s -"
      %(vms)s
    ||| % {
      action: action,
      vms: std.join('\n', [
        'echo ' + std.escapeStringBash(vm.hostname)
        for vm in config.virtual_machines
      ]),
    },
  virtualmachines_bootstrap(config)::
    self.fake_script(config, 'bootstrap'),
  virtualmachines_provisioning(config)::
    self.fake_script(config, 'bootstrap'),
  virtualmachines_destroy(config)::
    self.fake_script(config, 'destroy'),
  virtualmachines_list(config)::
    self.fake_script(config, 'list'),
  virtualmachine_shell(config)::
    self.fake_script(config, 'shell'),
}
