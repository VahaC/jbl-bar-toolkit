#!/bin/sh
# Per-session environment for the vendor's native utilities.
BB=/bin/busybox
VENDOR_DIRS='/usr/local/bin /usr/bin /usr/local/sbin /usr/sbin'
FIRMWARE_DIRS='/bin /sbin'
# Private per-boot cache in RAM. Symlinks must stay out of the SSH store:
# toolkit updates refuse a component store that contains any.
APPLETS=/tmp/jbl-local-ssh-applets
LD_LIBRARY_PATH=/system/bdplib:/system/usr/lib:/system/usr/local/lib
LD_PRELOAD=

# In this SSH namespace the default ELF interpreter is the vendor 2.18 loader
# (namespace.sh), and the library path above is the vendor runtime. Firmware
# executables in /bin and /sbin (Android toolbox applets and others) belong
# to another C runtime and crash here, while BusyBox works. A command that
# would otherwise reach /bin or /sbin, directly or through a vendor-directory
# symlink, therefore runs as a BusyBox applet. Real vendor utilities keep
# precedence and their library environment.
vendor_command() {
    for dir in $VENDOR_DIRS; do
        file=$dir/$1
        [ -f "$file" ] && [ -x "$file" ] || continue
        [ -L "$file" ] || return 0
        real=$("$BB" readlink -f "$file") || return 1
        [ "$real" != "$busybox_real" ] || return 0
        for top in $firmware_real; do
            case "$real" in "$top"/*) return 1;; esac
        done
        return 0
    done
    return 1
}
fill_applets() {
    list=$("$BB" --list) && [ -n "$list" ] || return 1
    busybox_real=$("$BB" readlink -f "$BB") || return 1
    firmware_real=
    for top in $FIRMWARE_DIRS; do
        real=$("$BB" readlink -f "$top") && firmware_real="$firmware_real $real"
    done
    set -f
    for name in $list; do
        case "$name" in ''|.*|*/*) continue;; esac
        vendor_command "$name" && continue
        "$BB" ln -s "$BB" "$1/$name" || { set +f; return 1; }
    done
    set +f
}
applets_ready() { [ -d "$APPLETS" ] && [ ! -L "$APPLETS" ] && [ -O "$APPLETS" ]; }
build_applets() {
    # Only create a missing cache; never adopt a path made by someone else.
    [ ! -e "$APPLETS" ] && [ ! -L "$APPLETS" ] || return 1
    new=$APPLETS.new.$$
    "$BB" rm -rf "$new" && "$BB" mkdir -m 700 "$new" || return 1
    if fill_applets "$new" && "$BB" mv "$new" "$APPLETS"; then
        # A concurrent session may have published first; mv then nests ours.
        "$BB" rm -rf "$APPLETS/${new##*/}"
    fi
    "$BB" rm -rf "$new"
}
applets_ready || build_applets 2>/dev/null
PATH=
for dir in $VENDOR_DIRS $FIRMWARE_DIRS; do PATH=${PATH:+$PATH:}$dir; done
# Without a usable cache the session still starts with the previous PATH.
! applets_ready || PATH=$APPLETS:$PATH
export LD_LIBRARY_PATH LD_PRELOAD PATH
case "${SSH_ORIGINAL_COMMAND-}" in
    internal-sftp) exec /usr/local/libexec/sftp-server;;
    '') exec "$BB" sh -i;;
    *) exec "$BB" sh -c "$SSH_ORIGINAL_COMMAND";;
esac
