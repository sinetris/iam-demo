# Forgejo

## Configuration

### Environment variables

Mandatory:

- `FORGEJO_APP_INI`
- `FORGEJO_CUSTOM`
- `FORGEJO_TEMP`
- `FORGEJO_WORK_DIR`

All values in [app.ini](https://codeberg.org/forgejo/forgejo/src/branch/forgejo/custom/conf/app.example.ini)
can be set as environment variables in the format (all uppercase): `FORGEJO__{section}__{config_key}`

Each `section` in the `app.ini` file is wrapped by square brackets (`[]`).\
The sections are ecaped as following: `_0X2E_` for `.` and `_0X2D_` for `-`.

#### Environment Variables Examples

- `FORGEJO____APP_NAME="My GIT server"`
  - set `APP_NAME` from the "General Settings" (no section) to `My GIT server`
- `FORGEJO__LOG_0X2E_FILE__FILE_NAME=/var/log/forgejo.log`
  - set `FILE_NAME` from the `[log.file]` section to `/var/log/forgejo.log`
