local cloud_init = import 'cloud_init.libsonnet';

{
  file_name(name, opts={})::
    assert std.isObject(opts);
    (if std.objectHas(opts, 'prefix') then
       opts.prefix + '-' + name
     else name) +
    (if std.objectHas(opts, 'postfix') then
       '-' + opts.postfix
     else '') +
    (if std.objectHas(opts, 'extension') then
       '.' + opts.extension
     else ''),
  cloudinit_filename(hostname)::
    'assets/' + self.file_name(hostname, {
      prefix: 'cloud-init',
      extension: 'yaml',
    }),
  cloud_config(config, instance)::
    cloud_init.cloud_config(config, instance),
}
