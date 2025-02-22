{
  arrayIf(condition, array, elseArray=[])::
    assert std.isArray(array);
    assert std.isArray(elseArray);
    (if condition then array else elseArray),
  objectIf(condition, object, elseObject={})::
    assert std.isObject(object);
    assert std.isObject(elseObject);
    (if condition then object else elseObject),
  indent(string, pre)::
    pre + std.join(
      '\n' + pre,
      std.split(std.rstripChars(string, '\n'), '\n')
    ),
  shell_lines(lines)::
    std.stripChars(
      std.join('', lines),
      '\n'
    ),
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
  cloudinit_user_data_filename(hostname)::
    'assets/' + self.file_name(hostname, {
      prefix: 'cidata',
      postfix: 'user-data',
      extension: 'yaml',
    }),
}
