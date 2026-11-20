#!/bin/sh
# Called in the background; bounded waits cannot hold the boot command open.
PATH=/bin:/sbin:/usr/bin:/usr/sbin
export PATH
unset LD_LIBRARY_PATH LD_PRELOAD
ulimit -c 0
exec </dev/null >/dev/null 2>&1
. /var/JBLLocalSSH/common.sh || exit 1
release_sockets || exit 1
owned_store || exit 1
[ ! -e "$STORE/BOOT_DISABLED" ] || exit 0
. "$STORE/settings.conf" || exit 1
[ "$AUTOSTART" = 1 ] || exit 0
LOCK=/tmp/jbl-local-ssh-boot-lock
"$BB" mkdir "$LOCK" 2>/dev/null || exit 0
trap '"$BB" rmdir "$LOCK"' EXIT
umask 077
[ ! -f "$STORE/boot.log" ] || "$BB" mv "$STORE/boot.log" "$STORE/boot-previous.log"
exec > "$STORE/boot.log" 2>&1
finish() { printf '%s\n' "$1" > "$STORE/BOOT_STATUS.txt"; printf 'RESULT=%s\n' "$1"; exit "$2"; }
# Bind the daemon to $addr. A failure names its reason; $child is the listener.
start_listener() {
    child=
    "$BB" awk -v ip="$addr" '/^ListenAddress / {print "ListenAddress " ip; n++; next} {print} END {if(n!=1) exit 1}' "$STORE/sshd_config" > "$STORE/sshd_config.new" || { reason=CONFIG_ADDRESS_FAILED; return 1; }
    "$BB" mv "$STORE/sshd_config.new" "$STORE/sshd_config" || { reason=CONFIG_SAVE_FAILED; return 1; }
    printf '%s\n' "$addr" > "$STORE/listen-address"
    prepare_privsep || { reason=PRIVSEP_CHECK_FAILED; return 1; }
    "$BB" unshare -m --propagation private /bin/sh "$STORE/namespace.sh" > "$STORE/start.log" 2>&1 </dev/null &
    child=$!
    wait_listener "$child" || { reason=SSH_LISTENER_NOT_CONFIRMED; return 1; }
    connection_info || { reason=CONNECTION_INFO_FAILED; return 1; }
}
stopped() {
    kill -0 "$1" 2>/dev/null || return 0
    # A listener started by the follower stays a zombie until it is reaped.
    [ "$("$BB" awk '{sub(/^.*\) /, ""); print $1}' "/proc/$1/stat" 2>/dev/null)" = Z ]
}
stop_listener() {
    [ -n "$child" ] || return 0
    kill -TERM "$child" 2>/dev/null
    waited=0
    until stopped "$child"; do
        [ "$waited" -lt 15 ] || return 1
        "$BB" sleep 1
        waited=$((waited + 1))
    done
    child=
}
# Returns 0 after a confirmed move, 1 with $reason, 2 when disabled meanwhile.
move_listener() {
    stop_listener || { reason=SSH_LISTENER_STOP_FAILED; return 1; }
    [ ! -e "$STORE/BOOT_DISABLED" ] || return 2
    addr=$1
    start_listener || return 1
    [ ! -e "$STORE/BOOT_DISABLED" ] || return 2
}
# sshd binds one address, but the bar changes it after startup: Wi-Fi is
# released once a wired link is ready, and a cable can be connected later.
# Follow the selected LAN address, as local discovery already does.
# @VahaC reported and diagnosed the unreachable listener on hardware (#59).
follow_address() {
    trap - EXIT
    current=$addr
    candidate=
    failures=0
    while :; do
        "$BB" sleep 5
        owned_store || return 0
        [ ! -e "$STORE/BOOT_DISABLED" ] || return 0
        # A listener stopped or replaced by setup, recovery or the owner is
        # theirs: never start it again from here.
        if [ "$failures" = 0 ]; then
            daemon_running && [ "$pid" = "$child" ] || return 0
        fi
        next=$(find_address)
        if [ -z "$next" ] || [ "$next" = "$current" ]; then candidate=; continue; fi
        # Addresses change while a link settles: require two matching polls.
        if [ "$next" != "$candidate" ]; then candidate=$next; continue; fi
        candidate=
        # Setup and reinstall wait for this lock before changing the store.
        "$BB" mkdir "$LOCK" 2>/dev/null || continue
        move_listener "$next"
        moved=$?
        "$BB" rmdir "$LOCK"
        case "$moved" in
            0)
                current=$next
                failures=0
                printf 'SSH_READY\n' > "$STORE/BOOT_STATUS.txt"
                printf 'FOLLOW=LISTENER_MOVED\n';;
            2)
                stop_listener
                printf 'FOLLOW=DISABLED\n'
                return 0;;
            *)
                # No half-started daemon may outlive a failed attempt.
                stop_listener
                current=
                failures=$((failures + 1))
                printf '%s\n' "$reason" > "$STORE/BOOT_STATUS.txt"
                printf 'FOLLOW=%s\n' "$reason"
                [ "$failures" -lt 3 ] || return 1;;
        esac
    done
}
verify_tools || finish UNSUPPORTED_NATIVE_SSH_BUILD 1
daemon_running && finish ALREADY_RUNNING 0
for name in namespace.sh session.sh passwd nsswitch.conf ld.so.preload host_ed25519 host_ed25519.pub sshd_config; do
    [ -f "$STORE/$name" ] || finish "MISSING_$name" 1
done
tries=0
addr=
while [ "$tries" -lt 90 ]; do
    [ ! -e "$STORE/BOOT_DISABLED" ] || finish DISABLED 0
    addr=$(find_address)
    [ -z "$addr" ] || break
    "$BB" sleep 2
    tries=$((tries + 1))
done
[ -n "$addr" ] || finish NO_ALLOWED_LAN_WITHIN_180_SECONDS 1
start_listener || finish "$reason" 1
# The boot command returns now; the follower keeps the same log.
follow_address &
finish SSH_READY 0
