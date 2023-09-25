// Run the following command to generate files:
// jsonnet --create-output-dirs --multi ./generated --string virtual-machines.jsonnet
local setup = import 'setup.jsonnet';

local orchestrator = import 'lib/orchestrator.libsonnet';

local utils = import 'lib/utils.libsonnet';

function(orchestrator_name='multipass') {
  // jsonnet doesn't allow dynamic import paths
  local orchestrator_implementation = orchestrator.get(orchestrator_name),
  'vms-status.sh': orchestrator_implementation.use.virtualmachines_list(setup),
  'vms-bootstrap.sh': orchestrator_implementation.use.virtualmachines_bootstrap(setup),
  'vms-provisioning.sh': orchestrator_implementation.use.virtualmachines_provisioning(setup),
  'vm-shell.sh': orchestrator_implementation.use.virtualmachine_shell(setup),
  'vms-destroy.sh': orchestrator_implementation.use.virtualmachines_destroy(setup),
} + {
  [utils.cloudinit_filename(entry.hostname)]: utils.cloud_config(setup, entry)
  for entry in setup.virtual_machines
}
