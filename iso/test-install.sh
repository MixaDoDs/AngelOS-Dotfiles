#!/usr/bin/env bash
# Installs angelOS from the ISO onto an empty virtual disk and boots the result — all without a window
# (DP-1 never sees it). The tree's angelos-install-disk is pushed into the live first, so a change to it
# needs no new ISO. Then the disk alone is booted, the test user logs in (QMP keys) and the first desktop is
# photographed through a guest agent the test puts on the disk (test-only; screendump can't see virgl).
#
#   iso/test-install.sh ~/Work/AngelOS/export/iso/angelos-*.iso   → ~/Work/AngelOS/vm/runs/install-<MMDD-HHMM>/
#   (progress.txt, install.log, esp.txt, login-*.png, boot-journal.txt, user-journal.txt; disk.qcow2 deleted unless KEEP_DISK=1)
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
S="$HERE/profile/airootfs/usr/local/bin/angelos-install-disk"
if [[ "$(g 'test -x /usr/local/bin/angelos-install-disk && sha256sum </usr/local/bin/angelos-install-disk' 2>/dev/null)" == "$(sha256sum <"$S")" ]]; then
  echo "the image's own angelos-install-disk"
else
  echo "angelos-install-disk from the tree (the image has another or none)"
  g "echo $(base64 -w0 "$S") | base64 -d >/usr/local/bin/angelos-install-disk && chmod 755 /usr/local/bin/angelos-install-disk"
fi
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
# test-only: the guest agent onto the installed system, so its desktop can be photographed (virgl)
[[ $rc == 0 ]] && g "mount -o subvol=@ /dev/vda2 /mnt && mount -o subvol=@pkg /dev/vda2 /mnt/var/cache/pacman/pkg &&
  arch-chroot /mnt pacman -S --noconfirm --needed qemu-guest-agent && arch-chroot /mnt systemctl enable qemu-guest-agent;
  sync; umount -R /mnt" >"$D/agent.txt" 2>&1 || echo "✕ no guest agent on the disk, see agent.txt"
g "sync; systemctl poweroff" >/dev/null 2>&1 || true
for ((i = 0; i < 120; i++)); do kill -0 "$(cat "$D/qemu.pid")" 2>/dev/null || break; sleep 1; done; stop
[[ $rc == 0 ]] || { echo "✕ install failed (rc=${rc:-timeout}), see $D/err.txt and install.log"; cat "$D/err.txt"; exit 1; }
echo "install: $((SECONDS - start)) s"

# 2. the disk alone
vm -device virtio-vga-gl,xres=1920,yres=1080 -display egl-headless \
  -device virtio-serial -chardev "socket,path=$D/qga.sock,server=on,wait=off,id=qga0" \
  -device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0
# qmp <keys…> (QEMU key names: a b … minus ret) — the keyboard works with virgl, screendump does not
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
for k in sys.argv[2:]:
    call("send-key", keys=[{"type": "qcode", "data": k}]); time.sleep(0.15)
PY
}
# the login screen (sddm on X: its display), then the test user's password and the first login's desktop
for ((i = 0; i < 40; i++)); do g "pgrep -x sddm-greeter-qt6 || pgrep -f sddm-greeter" >/dev/null 2>&1 && break; sleep 5; done
sleep 10
g "pgrep -a sddm; pgrep -a Xorg" >"$D/greeter.txt" 2>&1 || echo "✕ no login screen"
qmp a n g e l minus t e s t ret
AS_TESTER='runuser -u tester -- env XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1'
for t in 30 60 90 120 150; do
  sleep 30
  g "$AS_TESTER grim -" >"$D/login-$(printf %03d "$t").png" 2>/dev/null && echo "login $t s: picture" ||
    { rm -f "$D/login-$(printf %03d "$t").png"; echo "login $t s: no picture"; }
done
g "journalctl -b --no-pager -o short-monotonic" >"$D/boot-journal.txt" 2>/dev/null || true
g "runuser -u tester -- journalctl --user -b --no-pager" >"$D/user-journal.txt" 2>/dev/null || true
g "free -m; systemctl --failed --no-pager; pgrep -a quickshell; pgrep -a niri" >"$D/state.txt" 2>/dev/null || true
g "systemctl poweroff" >/dev/null 2>&1 || true
sleep 5
stop
[[ ${KEEP_DISK:-0} == 1 ]] || rm -f "$D/disk.qcow2"
echo "$D"
