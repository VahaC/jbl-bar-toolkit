# JBL Bar Toolkit

**Make your JBL Bar 9.1 work the way you want.** Control it from your phone or
computer, adjust the sound, and automatically select Standard Mode after wake.
Everything runs on your home network; no cloud account is needed.

![Browser remote with sample speaker and sound controls](docs/web-remote.png)

**Experimental.** Bar 9.1 is the only installation target. Individual features
have device evidence; complete installation, restart and recovery qualification
remains pending. Other models are [research only](docs/HARDWARE.md).

## Get started

You need a Bar 9.1, a Windows/macOS/Linux computer and a USB stick. Connect your
computer and bar to the same home network, by Ethernet or Wi-Fi.

1. [Download the setup app](https://github.com/kisinga/jbl-bar-toolkit/releases).
   Choose the executable for your computer; no developer tools are needed.
2. Run it and choose **USB setup**. Recommended settings enable the browser
   remote, automatic Standard Mode and **Remote admin access** for future
   updates without USB. Choose an admin password. **Customize settings** and **Show all
   controls** keep the alternatives accessible.
3. Follow the [installation guide](docs/models/bar91/USB-TOOLKIT.md#get-started)
   through compatibility check, installation and restart verification. Keep the
   original USB backup and matching recovery ZIP.

Open **[jbl.local](http://jbl.local)** after installation. If that name is
unavailable, use the bar's IP address from your router.

## Update later

Already installed? Use **Network update** if remote admin access is enabled;
otherwise use **USB setup**. Existing settings and keys are retained.
[Update instructions](docs/models/bar91/USB-TOOLKIT.md#update-your-toolkit) ·
[Replace an older standalone installation](docs/models/bar91/OLDER-INSTALLATIONS.md).

## Everyday use

- Volume, source, playback and speaker levels from a browser.
- Standard/Smart Mode, dialogue boost, Front EQ and experimental bass offset.
- Experimental [timers](docs/TIMERS.md), [display messages and clock](docs/DISPLAY_MESSAGES.md).

Controls explain availability for the current playback route. More details:
[sound and control reference](docs/models/bar91/STANDALONE.md#local-browser-remote) ·
[Home Assistant integration](https://github.com/naonak/jbl-bar-toolkit-ha).

## Need help?

Setup reads returned USB reports and suggests the next step. Technical details
remain available underneath. If a step fails, keep the original files and use
[installation troubleshooting](docs/models/bar91/USB-TOOLKIT.md#if-an-installation-fails)
or [recovery](docs/models/bar91/USB-TOOLKIT.md#recovery).

[Report a problem](https://github.com/kisinga/jbl-bar-toolkit/issues/new/choose)
with your model, toolkit version and relevant status/logs. Review logs before
sharing; configured USBs and recovery backups are private.

## For contributors

With Go 1.25.7+, run setup from this checkout:

```sh
go run ./apps/usbsetup --repo .
```

```sh
./jbl dev             # Remote preview with sample data
./jbl test            # Fast checks
./jbl test --full     # Full checks; requirements in CONTRIBUTING.md
```

[Contributing](CONTRIBUTING.md) · [Experience principle](docs/EXPERIENCE.md) ·
[Architecture](docs/ARCHITECTURE.md) · [Changelog](CHANGELOG.md) ·
[Research](research/README.md).

Independent project; not affiliated with JBL. MIT covers project code and
documentation. Vendor firmware and proprietary libraries are not bundled.
[Credits](docs/models/bar91/STANDALONE.md#credits).
