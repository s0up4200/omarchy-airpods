# omarchy-airpods

AirPods noise control and battery in the [Omarchy](https://omarchy.org/) bar.

Standard Bluetooth profiles carry audio and the media keys, but they do not
carry noise control mode, per-pod battery, or in-ear status. Apple sends these
over a vendor protocol (AAP) on L2CAP PSM `0x1001`. This plugin speaks that
protocol directly.

![the panel](docs/panel.png)

The panel shows:

- The battery level of each pod and of the case
- The current noise control mode
- Buttons for Off, Transparency, Adaptive, and ANC

The bar shows a headphone icon with the battery level of the lowest pod. The
icon is dim when no AirPods are connected.

## Install

```bash
omarchy plugin add https://github.com/s0up4200/omarchy-airpods.git
omarchy plugin enable soup.airpods
```

Then tell BlueZ to identify itself as an Apple device, or the AirPods refuse
the AAP channel. Add this line to `/etc/bluetooth/main.conf`:

```ini
DeviceID = bluetooth:004C:0000:0000
```

Restart Bluetooth and reconnect the AirPods:

```bash
sudo systemctl restart bluetooth
```

There are no other dependencies. The backend is one Python script that uses
the standard library only.

## Do not run LibrePods at the same time

The AirPods accept one AAP client. If [LibrePods](https://github.com/librepods-org/librepods)
holds the channel, this plugin reads stale data and its commands are ignored.
Use one or the other.

LibrePods does more than this plugin: ear-detection auto-pause, conversational
awareness, and hearing aid settings. This plugin does less, from the bar.

## Command line

The backend works on its own:

```bash
~/.config/omarchy/plugins/soup.airpods/bin/airpods status
~/.config/omarchy/plugins/soup.airpods/bin/airpods set transparency
~/.config/omarchy/plugins/soup.airpods/bin/airpods selftest
```

`status` prints JSON:

```json
{"connected": true, "address": "…", "mode": "adaptive",
 "battery": {"left": 90, "right": 85, "case": null}}
```

A `null` battery level means the component did not report one, which is normal
for the case while the pods are in your ears.

To bind a mode to a key, call `set` from your Hyprland config.

## Settings

Set these in `~/.config/omarchy/shell.json`, in the widget's entry:

| Key | Default | What it does |
|---|---|---|
| `refreshIntervalSec` | `60` | Seconds between reads while the panel is closed |
| `showBattery` | `true` | Show the battery percent next to the bar icon |

Each read opens a short Bluetooth channel, so a small interval costs more
radio time. The panel polls every 10 seconds while it is open.

## Tested with

AirPods Pro (model A3048) on Omarchy 4, BlueZ 5.87. Other AirPods models use
the same protocol, but they are not tested. Reports are welcome.

## Development

The shell watches the plugin directory, but a bar widget that is already on
the bar keeps the QML it loaded. After an edit, run:

```bash
omarchy restart shell
```

## How it works

`bin/airpods` connects to L2CAP PSM `0x1001`, sends the AAP handshake, then
asks for the feature flags and the notification stream. The AirPods answer with
battery, ear, and mode packets. Writing a mode is one control command packet.

The packet format was worked out by the LibrePods project. This plugin
implements a small part of it.

## License

MIT
