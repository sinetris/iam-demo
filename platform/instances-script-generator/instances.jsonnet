// Run the following command to generate files:
// jsonnet --create-output-dirs \
//   --multi ./generated \
//   --tla-str orchestrator_name="multipass" \
//   --string virtual-machines.jsonnet
local setup = import 'setup.libsonnet';

local orchestrator = import 'lib/orchestrator.libsonnet';

local utils = import 'lib/utils.libsonnet';

function(orchestrator_name='fake') {
  local orchestrator_implementation = orchestrator.get(orchestrator_name),
  'instances-status.sh': orchestrator_implementation.use.virtualmachines_list(setup),
  'instances-create.sh': orchestrator_implementation.use.virtualmachines_bootstrap(setup),
  'instances-setup.sh': orchestrator_implementation.use.virtualmachines_setup(setup),
  'instances-provisioning.sh': orchestrator_implementation.use.virtualmachines_provisioning(setup),
  'instance-shell.sh': orchestrator_implementation.use.virtualmachine_shell(setup),
  'instances-destroy.sh': orchestrator_implementation.use.virtualmachines_destroy(setup),
  'instance-info.sh': orchestrator_implementation.use.virtualmachines_info(setup),
} + {
  [utils.cloudinit_filename(entry.hostname)]: utils.cloud_config(setup, entry)
  for entry in setup.virtual_machines
}
