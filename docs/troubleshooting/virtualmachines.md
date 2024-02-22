# Troubleshooting Virtual Machines

[Back to README](README.md)

- [Time sync](#time-sync)
- [Mouse scrolling in Firefox](#mouse-scrolling-in-firefox)

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
