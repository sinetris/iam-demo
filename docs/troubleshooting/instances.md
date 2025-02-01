# Troubleshooting Instances

[Back to README](README.md)

- [Check networking](#check-networking)
- [Refresh SHH hosts heys](#refresh-shh-hosts-heys)
- [Time sync](#time-sync)
- [Mouse scrolling in Firefox](#mouse-scrolling-in-firefox)

## Check networking

```sh
# Check DNS resolver
resolvectl status
# Check DNS resolver for interface
network_interface=enp0s1
resolvectl status ${network_interface:?}
# Check DNS resolution
dig iam-control-plane.iam-demo.test
# Check network routing
ip route
```

## Refresh SHH hosts heys

If you recreate any instance, the host keys are also recreated.

When connecting to the new instance, an error may be displayed containing:

```txt
WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!
```

You need to remove the old keys and add the new ones.

```sh
# Select the problematic target
target_host=iam-control-plane

# Remove old keys
ssh-keygen -R ${target_host}

# Add the new keys
ssh-keyscan ${target_host} >> ~/.ssh/known_hosts
```

## Time sync

If you get time syncronization related problems, you can force the sync using:

```shell
sudo chronyc -a makestep
```

## Mouse scrolling in Firefox

If page scrolling is too fast or too slow in Firefox (usually too fast when
connecting via RDP and using the Apple Magic Trackpad/Mouse), you can change
the sensitivity from the Firefox Advanced Preferences page.

> **Note:**\
> This operation is now automated using Ansible and the `firefox_preferences`
> variable to create the `/etc/firefox/defaults/pref/config-prefs.js` file in
> the `linux-desktop` instance.\
> After changing the value in `firefox_preferences` and replaying the playbook,
> you need to restart Firefox.\
> You can still use the following method to find the value that best suits your
> needs, but changes will be lost when you restart Firefox because the `user.js`
> entry will override it.

- open a new tab in Firefox and enter `about:config` into the address bar to
  access Advanced Preferences
- search for `mousewheel.default.delta_multiplier_y` and edit the value (default
  is `100`)
  - lower value to go slower (`25` is usually fine for the Apple Magic Mouse)
  - higher value to go faster
