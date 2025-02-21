// Run the following command to generate files:
// project_root_path=$(cd ../../ && pwd)
// project_generator_path="${project_root_path:?}/platform/project-script-generator"
// jsonnet --create-output-dirs \
//   --multi "${project_root_path:?}/generated" \
//   --ext-str project_root_path="${project_root_path:?}" \
//   --ext-str orchestrator_name="multipass" \
//   --ext-str host_architecture="amd64" \
//   --jpath "${project_root_path:?}" \
//   --jpath "${project_generator_path}" \
//   --string "${project_generator_path}/project-files-generator.jsonnet"
local setup = import 'setup.libsonnet';

local orchestrator = import 'lib/orchestrator.libsonnet';

local utils = import 'lib/utils.libsonnet';

function() {
  local orchestrator_implementation = orchestrator.get(setup.orchestrator_name),
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
