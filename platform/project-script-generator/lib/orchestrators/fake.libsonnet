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
  project_utils(setup)::
    self.fake_script(setup, 'utils'),
  project_bootstrap(setup)::
    self.fake_script(setup, 'bootstrap'),
  project_wrap_up(setup)::
    self.fake_script(setup, 'wrap-up'),
  project_provisioning(setup)::
    self.fake_script(setup, 'provisioning'),
  project_delete(setup)::
    self.fake_script(setup, 'destroy'),
  instances_status(setup)::
    self.fake_script(setup, 'list'),
  virtualmachine_shell(setup)::
    self.fake_script(setup, 'shell'),
  instance_info(setup)::
    self.fake_script(setup, 'info'),
}
