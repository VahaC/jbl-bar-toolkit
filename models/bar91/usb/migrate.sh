#!/bin/sh
# Compatibility stub: old action=migrate configurations receive a clear refusal.
# Never retire files, stop services or install over a standalone installation.
USB=${JBL_TOOLKIT_USB:-/mnt/sda1/JBLToolkit}
. "$USB/common.sh" || exit 1
printf 'LEGACY_INSTALLATION_REQUIRES_FRESH_SETUP\n' > "$USB/STATUS.txt"
printf 'RESULT=LEGACY_INSTALLATION_REQUIRES_FRESH_SETUP EXIT=1\n'
"$BB" sync
exit 1
