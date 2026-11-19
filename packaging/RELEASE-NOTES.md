Single-USB JBL Bar Toolkit with automatic hardware selection.

1. Download **jbl-setup-OS-ARCH** for your computer (`.exe` on Windows) and run it.
   No installation or Go runtime is required. Allow execution if your OS asks.
2. The local interface downloads verified toolkit files. Select a USB, choose
   settings and **Check compatibility first**, then **Prepare selected USB**.
   Optional formatting erases that drive and requires administrator permission.
3. Safely eject it, insert it into the powered-on bar and wait five minutes.
   Reconnect it to your computer and refresh drives to read its check results.
4. Install only after checks pass. Save the recovery ZIP on your computer.

For offline use, download **…-setup-OS-ARCH.zip**, extract it outside the USB and
run its included executable. **Check for updates** refreshes toolkit files;
**Update this setup app** replaces the executable itself and requires a restart.
The raw USB/recovery ZIPs remain available for advanced use.

The current package contains Bar 9.1 only, selected by exact executable identity.
Bar 800/1000/1300/1300X and MK2 installation is not implemented. Their USB startup
routes still need research. Model-specific ZIPs are also provided by CI.

Full combined installation, USB-free restart and recovery qualification remains
pending. Recovery is independent of the remote and config. Keep an existing
installation's original USB/recovery. Choose **Install / update everything**
to install or update a managed toolkit. Older standalone setups use an explicit
clean replacement with new settings, not an in-place upgrade. Toolkit
updates retain installed settings, SSH credentials/host keys and sound settings.
Unknown or modified installations stop before replacement. This updates toolkit
software, not JBL firmware.
Setup recommends Remote admin access with a chosen password for future network
updates without USB.

Windows USB formatting and wired/Wi-Fi LAN selection fixes follow @VahaC's
diagnoses and suggested approaches in [#58](https://github.com/kisinga/jbl-bar-toolkit/issues/58)
and [#59](https://github.com/kisinga/jbl-bar-toolkit/issues/59). LAN selection also
skips disconnected interfaces that retain an address.

Public ZIPs contain no owner credentials. Configured USBs must stay private.
