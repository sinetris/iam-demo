module {
  name: "iam-demo/utils",
  version: "0.1.0",
  description: "iam-demo JQ utility functions",
  license: "SPDX-License-Identifier: Apache-2.0 OR MIT",
};

def select_from_arg_name(arg_name):
  $ARGS.named."\(arg_name)" as $arg_value |
  if $arg_value == null then (
    {
      error: "arg value is null",
      arg_name: "\(arg_name)",
      arg_value: "\($arg_value)",
      description: "Set the proper value using '--arg \(arg_name) <arg_value>'",
    } |  halt_error(1)
  ) else . end |
  if .[$arg_value] != null then
    .[$arg_value]
  else
    ({
      error: "Key not found in selection",
      arg_name: "\(arg_name)",
      arg_value: "\($arg_value)",
      description: "Could not found key '\($arg_value)' in selection.\\nSet the proper value using '--arg \(arg_name) <arg_value>'.",
      selected_input: .,
    } |  halt_error(1))
  end
;
