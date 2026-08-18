# omarchy-airpods

AirPods noise control and battery in the [Omarchy](https://omarchy.org/) bar.

Standard Bluetooth profiles carry audio and the media keys, but they do not
carry noise control mode or per-pod battery. Apple sends these
over a vendor protocol (AAP) on L2CAP PSM `0x1001`. This plugin speaks that
protocol directly.

![the panel](docs/panel.png)

The panel shows:

- The device name and the model number
- The battery level of each pod and of the case
- Buttons for Off, Transparency, Adaptive, and ANC, with the current mode
  selected

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
~/.config/omarchy/plugins/soup.airpods/bin/airpods watch
~/.config/omarchy/plugins/soup.airpods/bin/airpods status
~/.config/omarchy/plugins/soup.airpods/bin/airpods selftest
```

`status` prints one JSON line and exits. `watch` holds the channel open and
prints a line for each change, which is what the panel runs:

```json
{"connected": true, "address": "…", "name": "AirPods Pro", "model": "A3047",
 "mode": "adaptive", "battery": {"left": 90, "right": 85, "case": null}}
```

The AirPods report the mode and the model one time for each Bluetooth
connection, to the client that holds the channel at that moment. A client
that connects later reads almost nothing. While the panel runs, `status`
therefore returns nulls, and it is useful only on a machine where the panel
is not running. `watch` also takes mode names on stdin, because a write must
go out on the channel that the AirPods are listening to.

A `null` battery level means the component did not report one, which is normal
for the case while the pods are in your ears.

## Settings

Set these in `~/.config/omarchy/shell.json`, in the widget's entry:

| Key | Default | What it does |
|---|---|---|
| `showBattery` | `true` | Show the battery percent next to the bar icon |

## Tested with

AirPods Pro (model A3047) on Omarchy 4, BlueZ 5.87. Other AirPods models use
the same protocol, but they are not tested. Reports are welcome.

## Development

The shell watches the plugin directory, but a bar widget that is already on
the bar keeps the QML it loaded. After an edit, run:

```bash
omarchy restart shell
```

## How it works

`bin/airpods` connects to L2CAP PSM `0x1001`, sends the AAP handshake, then
asks for the feature flags and the notification stream. The AirPods answer
with metadata, battery, and mode packets. Writing a mode is one control
command packet on the same channel, which is why `watch` reads mode names
from stdin.

The packet format was worked out by the LibrePods project. This plugin
implements a small part of it.

## License

MIT
