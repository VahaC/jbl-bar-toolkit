# Replace an older installation

**Older standalone installations are retired. Setup can remove recognized ones
and install the current toolkit fresh.** Your old settings are not imported.

1. Run setup, choose **USB setup**, and review your new settings. Keep **Remote
   admin access** enabled and choose a password for future updates without USB.
   Prepare **Check compatibility first** and run the USB check on your bar.
2. Return the USB and **Refresh drives**. If setup offers **Replace older
   installation (fresh setup)**, select it and review the reset notice. Choose
   **Prepare selected USB**, then run it on the bar as instructed. The helper
   stops recognized services, backs up their files and installs the new toolkit.
3. Follow the [restart and verification steps](USB-TOOLKIT.md#get-started).
   Keep the original USB backup and matching recovery ZIP private.

Replacement uses your newly selected features, network settings and admin
password. Toolkit sound preferences and the old admin identity are reset. JBL
firmware and the current Wi-Fi connection stay in place unless you change Wi-Fi
setup. Future updates use **Network update** with your admin password.

**No replacement offered?** Unknown or modified files are preserved. Use their
[original removal instructions](STANDALONE.md#remove-or-recover), restart the bar
and run the check again. If retained files still block setup, share the status
and reviewed logs in an issue; do not delete soundbar directories to force it.

<details>
<summary>Supported older setups, backups and failures</summary>

The helper recognizes the pinned rev5 (public v0.1.0) or rev6 Smart Mode
installation, optionally followed by the known standalone SSH and browser
installers. It verifies owners, script hashes and startup-hook snapshots before
changes. Other combinations and custom modifications need their original removal
route; there is no general legacy upgrade framework.

Old files stay inactive in `/var/JBLToolkitLegacy`. Settings, saved sound files,
passwords and host keys are not copied into the new toolkit. Recovery disables
the new toolkit and retains this archive; it does not reactivate the old setup.

A new admin host identity is expected. Review any saved SSH trust against the
new USB's public host key before accepting it.

If replacement stops, retain the exact USB and reports. Refresh the returned USB
and follow its result. A managed installation left disabled needs **Apply
configuration changes** or recovery with the same package. An interrupted
removal can be checked and resumed only while its archive and ownership still
match. Unknown failures require reviewing details before retrying.

Technical action: `action=reinstall`; `reinstall.sh` removes recognized services
from active paths and then the ordinary installer runs. `action=migrate` is
deprecated and performs no replacement. See `REINSTALL_CHECK.txt` and
`REINSTALL.txt` for evidence. These changes are **Unreleased** until included in
a new package; use a matching source build or that release's setup app.

</details>
