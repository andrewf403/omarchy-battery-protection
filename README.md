# Omarchy Battery Protection

A small Omarchy Quattro bar widget that enables or disables the battery charge
limit configured by UPower. Click the icon to switch between protected charging
and normal full-capacity charging.

## Features

- Uses UPower's standard D-Bus API.
- Shows `battery-lock` while protection is enabled.
- Shows `battery-lock-open` while protection is disabled.
- Provides a tooltip with the current state and configured limit.
- Hides itself when UPower reports that charge limiting is unsupported.

## Requirements

- Omarchy Quattro.
- UPower with `EnableChargeThreshold` support.
- A battery and Linux driver for which UPower reports
  `ChargeThresholdSupported: true`.
- A charge threshold configured by the system hardware database or firmware.

Check support and the configured threshold:

```sh
upower --battery | grep -E 'charge-threshold|charge-end-threshold'
```

UPower exposes the configured threshold as an on/off feature. This plugin does
not choose the percentage: enabling protection selects the limit configured by
the system, while disabling it restores full charging. The icon tooltip shows
the configured limit reported by UPower.

## Install

Install and enable the plugin from GitHub:

```sh
omarchy plugin add https://github.com/andrewf403/omarchy-battery-protection.git --enable
```

The widget is added to the bar's right section by default. Its visibility and
position can be managed with Omarchy's normal bar commands.

## Usage

Click the bar icon:

- `battery-lock` — protection is enabled; clicking disables it.
- `battery-lock-open` — protection is disabled; clicking enables it.

The bundled unprivileged helper can also query or change the standard UPower
state directly:

```sh
~/.config/omarchy/plugins/andrewf.battery-protection/battery-protection status
~/.config/omarchy/plugins/andrewf.battery-protection/battery-protection enable
~/.config/omarchy/plugins/andrewf.battery-protection/battery-protection disable
~/.config/omarchy/plugins/andrewf.battery-protection/battery-protection toggle
```

## Remove

If protection is enabled and you want to restore normal full-capacity charging,
click the icon once before removal. Then remove the plugin through Omarchy:

```sh
omarchy plugin remove andrewf.battery-protection
```

No separate uninstaller is needed. Removing the plugin deletes the widget and
its bundled helper.

## License

MIT
