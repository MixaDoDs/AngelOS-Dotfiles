#!/usr/bin/env bash
# Installs angelOS from the ISO onto an empty virtual disk and boots the result — all without a window
# (DP-1 never sees it). The tree's angelos-install-disk is pushed into the live first, so a change to it
# needs no new ISO. Then the disk alone is booted and the login screen photographed (QMP screendump:
# the installed system has no guest agent, and plain virtio-vga instead of virgl so screendump sees it).
#
#   iso/test-install.sh ~/Work/AngelOS/export/iso/angelos-*.iso   → ~/Work/AngelOS/vm/runs/install-<MMDD-HHMM>/
#   (progress.txt, install.log, list.json, boot-*.png; disk.qcow2 is deleted unless KEEP_DISK=1)
set -Eeuo pipefail

ISO="${1:?usage: iso/test-install.sh <iso>}"
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
D="${OUT_DIR:-$HOME/Work/AngelOS/vm/runs/install-$(date +%m%d-%H%M)}"
mkdir -p "$D"
cp /usr/share/edk2/x64/OVMF_VARS.4m.fd "$D/vars.fd"
qemu-img create -q -f qcow2 "$D/disk.qcow2" 40G
g() { timeout 60 python3 -I "$HERE/qga.py" "$D/qga.sock" "$1"; }
stop() { kill "$(cat "$D/qemu.pid" 2>/dev/null)" 2>/dev/null || true; }
trap stop EXIT
vm() { # common QEMU, then the boot-specific arguments
  nice -n 15 qemu-system-x86_64 -enable-kvm -cpu host -smp 4 -m 4096 -machine q35 \
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
    -drive if=pflash,format=raw,file="$D/vars.fd" \
    -drive file="$D/disk.qcow2",if=virtio,format=qcow2 \
    -audiodev none,id=snd -nic user,model=virtio-net-pci \
    -qmp "unix:$D/qmp.sock,server,nowait" -daemonize -pidfile "$D/qemu.pid" "$@"
}

# 1. the live, with the guest agent
vm -cdrom "$ISO" -boot d -device virtio-vga-gl,xres=1920,yres=1080 -display egl-headless \
  -device virtio-serial -chardev "socket,path=$D/qga.sock,server=on,wait=off,id=qga0" \
  -device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0
for ((i = 0; i < 60; i++)); do g true 2>/dev/null && break; sleep 5; done
g true || { echo "✕ the live's guest agent never answered"; exit 1; }
g "echo $(base64 -w0 "$HERE/profile/airootfs/usr/local/bin/angelos-install-disk") | base64 -d >/usr/local/bin/angelos-install-disk && chmod 755 /usr/local/bin/angelos-install-disk"
g "angelos-install-disk list" >"$D/list.json"
g "setsid sh -c 'echo angel-test | INSTALL_DISK=/dev/vda INSTALL_CONFIRM=/dev/vda INSTALL_USER=tester \
   INSTALL_TZ=Europe/Moscow INSTALL_LOCALE=ru_RU.UTF-8 angelos-install-disk >/tmp/progress 2>/tmp/err; echo \$? >/tmp/rc' \
   </dev/null >/dev/null 2>&1 &"
start=$SECONDS last=""
while ((SECONDS - start < 3600)); do
  sleep 20
  p="$(g 'tail -n 1 /tmp/progress' 2>/dev/null || true)"
  [[ $p != "$last" ]] && { echo "$((SECONDS - start)) s: $p"; last=$p; }
  rc="$(g 'cat /tmp/rc 2>/dev/null' 2>/dev/null || true)"
  [[ -n $rc ]] && break
done
g "cat /tmp/progress" >"$D/progress.txt" || true
g "cat /var/log/angelos-install.log" >"$D/install.log" || true
g "cat /tmp/err" >"$D/err.txt" || true
g "mkdir -p /tmp/esp && mount -o ro /dev/vda1 /tmp/esp && find /tmp/esp; umount /tmp/esp" >"$D/esp.txt" 2>&1 || true
g "sync; systemctl poweroff" >/dev/null 2>&1 || true
for ((i = 0; i < 120; i++)); do kill -0 "$(cat "$D/qemu.pid")" 2>/dev/null || break; sleep 1; done; stop
[[ $rc == 0 ]] || { echo "✕ install failed (rc=${rc:-timeout}), see $D/err.txt and install.log"; cat "$D/err.txt"; exit 1; }
echo "install: $((SECONDS - start)) s"

# 2. the disk alone
vm -device virtio-vga,xres=1920,yres=1080 -display none
# qmp shot <file.png> | qmp type <keys…> (QEMU key names: a b … minus ret)
qmp() {
  python3 -I - "$D/qmp.sock" "$@" <<'PY'
import json, socket, sys, time
s = socket.socket(socket.AF_UNIX); s.connect(sys.argv[1]); f = s.makefile("rw")
f.readline()
def call(cmd, **args):
    f.write(json.dumps({"execute": cmd, "arguments": args}) + "\n"); f.flush()
    while "return" not in (r := json.loads(f.readline())):
        if "error" in r: sys.exit(r["error"]["desc"])
call("qmp_capabilities")
if sys.argv[2] == "shot":
    call("screendump", filename=sys.argv[3], format="png")
else:
    for k in sys.argv[3:]:
        call("send-key", keys=[{"type": "qcode", "data": k}]); time.sleep(0.15)
PY
}
for t in 30 60 90; do
  sleep 30
  qmp shot "$D/boot-$(printf %03d "$t").png" && echo "boot $t s: picture"
done
# the login screen: the test user's password (angel-test), then the first login's desktop
qmp type a n g e l minus t e s t ret
for t in 30 60 90 120; do
  sleep 30
  qmp shot "$D/login-$(printf %03d "$t").png" && echo "login $t s: picture"
done
stop
[[ ${KEEP_DISK:-0} == 1 ]] || rm -f "$D/disk.qcow2"
echo "$D"
