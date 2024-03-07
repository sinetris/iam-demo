# Troubleshooting Virtual Machines

[Back to README](README.md)

- [Refresh SHH hosts heys](#refresh-shh-hosts-heys)
- [Time sync](#time-sync)
- [Mouse scrolling in Firefox](#mouse-scrolling-in-firefox)

## Refresh SHH hosts heys

If you re-create virtual machines, it will also re-create the host keys.

When connecting to the new machine, you should get an error starting with:

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

- open a new tab in Firefox and enter `about:config` into the address bar to
  access Advanced Preferences
- search for `mousewheel.default.delta_multiplier_y` and edit the value
  (default is `100`)
  - lower value to go slower (`25` is usually fine for the Apple Magic Mouse)
  - higher value to go faster
