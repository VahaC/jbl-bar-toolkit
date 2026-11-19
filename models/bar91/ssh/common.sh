#!/bin/sh
# Sourced by the installer and background boot helper.
BB=${JBL_BUSYBOX:-/bin/busybox}
STORE=${JBL_SSH_STORE:-/var/JBLLocalSSH}
OWNER=JBL_LOCAL_SSH_REV1
release_sockets() {
    for p in /proc/$$/fd/*; do
        fd=${p##*/}
        case "$fd" in ''|*[!0-9]*|0|1|2) continue;; esac
        [ -L "$p" ] || continue
        target=$("$BB" readlink "$p" 2>/dev/null) || { [ ! -L "$p" ] && continue; return 1; }
        case "$target" in socket:*) eval "exec ${fd}>&-" || return 1;; esac
    done
}
owned_store() {
    [ -d "$STORE" ] && [ ! -L "$STORE" ] &&
        [ "$("$BB" cat "$STORE/OWNER.txt" 2>/dev/null)" = "$OWNER" ]
}
verify_tools() {
    hash=$("$BB" sha256sum /usr/local/sbin/sshd) || return 1
    [ "${hash%% *}" = 10df86a5dc23bd9d9593ebb36e140de2cdd61ed62cef3d8de308b21403a16bed ] || return 1
    hash=$("$BB" sha256sum /usr/local/bin/ssh-keygen) || return 1
    [ "${hash%% *}" = d9a97304808ce1f3a13cc6aa0b3d95a238e140a80f6a84f60a7fbe128e69c6df ] || return 1
    [ -f /system/bdplib/ld-2.18.so ] && [ -f /system/bdplib/libc-2.18.so ]
}
find_address() {
    # Restrict SSH to a private IPv4 interface sharing the owner's PC subnet.
    # Honor the actual interface prefix rather than assuming a /24 or address.
    # @VahaC identified the wlan0-only failure and proposed LAN selection (#59).
    # Auto and discovery use interface-name then numeric-address order.
    {
        # Address filtering by "up" checks only administrative state. Inspect
        # carrier too, since unplugged Ethernet can retain its old LAN address.
        "$BB" ip -o link show up 2>/dev/null || return 1
        if [ "${INTERFACE:-auto}" = auto ]; then
            "$BB" ip -4 -o addr show up 2>/dev/null
        else
            "$BB" ip -4 -o addr show dev "$INTERFACE" up 2>/dev/null
        fi
    } |
    "$BB" awk -v pc="$ALLOWED_PC" -v selected="${INTERFACE:-auto}" '
    function number(s, a,n,i,v) {
        n=split(s,a,"."); if(n!=4) return -1; v=0;
        for(i=1;i<=4;i++) {if(a[i]!~/^[0-9]+$/ || a[i]>255) return -1; v=v*256+a[i]}
        return v
    }
    $3 ~ /^</ {
        name=$2; sub(/:$/, "", name); split(name,iface,"@");
        flags="," substr($3,2,length($3)-2) ",";
        active[iface[1]]=(index(flags,",UP,") && index(flags,",LOWER_UP,") && !index(flags,",DORMANT,"));
        next
    }
    $3=="inet" {
        split($2,iface,"@"); name=iface[1];
        if(!active[name]) next;
        if(selected!="auto" && name!=selected) next;
        if(name=="lo" || name=="ap0" || name~/^p2p/) next;
        split($4,c,"/"); split(c[1],b,"."); ip=number(c[1]);
        private=(b[1]==10 || (b[1]==172 && b[2]>=16 && b[2]<=31) || (b[1]==192 && b[2]==168));
        if(index(pc,"/")) {
            split(pc,p,"/"); net=number(p[1]);
            if(ip<0 || net<0 || p[2]!~/^[0-9]+$/ || p[2]<1 || p[2]>32 || !private) next;
            unit=1; for(i=0;i<32-p[2];i++) unit*=2;
            if(int(ip/unit)==int(net/unit)) choose(name,ip,c[1]);
            next
        }
        owner=number(pc);
        if(ip<0 || owner<0 || c[2]<1 || c[2]>32 || !private || ip==owner) next;
        unit=1; for(i=0;i<32-c[2];i++) unit*=2;
        if(int(ip/unit)==int(owner/unit)) choose(name,ip,c[1]);
    }
    function choose(name,ip,text) {
        if(!found || "x" name < "x" bestname || (name==bestname && ip<bestip)) {
            found=1; bestname=name; bestip=ip; besttext=text
        }
    }
    END {if(found) print besttext}'
}
daemon_running() {
    [ -f "$STORE/sshd.pid" ] || return 1
    pid=$("$BB" cat "$STORE/sshd.pid")
    case "$pid" in ''|*[!0-9]*|0|1) return 1;; esac
    kill -0 "$pid" 2>/dev/null || return 1
    cmd=$("$BB" tr '\000' ' ' < "/proc/$pid/cmdline")
    case "$cmd" in *"sshd -D -E $STORE/sshd.log -f $STORE/sshd_config"*) return 0;; esac
    return 1
}
prepare_privsep() {
    [ ! -L /var/empty ] || return 1
    [ -d /var/empty ] || "$BB" mkdir -m 755 /var/empty || return 1
    [ "$("$BB" stat -c %u /var/empty)" = 0 ] && "$BB" chmod 755 /var/empty
}
wait_listener() {
    child=$1
    addrhex=$("$BB" awk -v ip="$addr" 'BEGIN {split(ip,a,"."); printf "%02X%02X%02X%02X",a[4],a[3],a[2],a[1]}')
    tries=0
    while [ "$tries" -lt 35 ]; do
        kill -0 "$child" 2>/dev/null || return 1
        inode=$("$BB" awk -v endpoint="$addrhex:08AE" '$2==endpoint && $4=="0A" {print $10; exit}' /proc/net/tcp)
        if [ -n "$inode" ]; then
            for fd in /proc/"$child"/fd/*; do
                [ "$("$BB" readlink "$fd" 2>/dev/null)" != "socket:[$inode]" ] || return 0
            done
        fi
        "$BB" sleep 1
        tries=$((tries + 1))
    done
    return 1
}
connection_info() {
    {
        printf 'IP=%s\nPORT=2222\nUSER=root\nALLOWED_PC=%s\n' "$addr" "$ALLOWED_PC"
        printf 'CONNECT=ssh -p 2222 root@%s\n' "$addr"
        "$BB" cat "$STORE/host_fingerprint.txt"
    } > "$STORE/connection.txt"
}
