#!/usr/bin/env bash
# A live ISO kept running for working on the installer's screens (no window: DP-1 never sees it).
#   iso/vm-dev.sh up <iso>       boot it with an empty 40 GB disk (vm/runs/dev/)
#   iso/vm-dev.sh push           the shell's files changed since BASE (default main; the ISO's own commit when it is older) → the live, restart
#   iso/vm-dev.sh keys a b ret   QEMU key names (shift-a for capitals, minus, spc, tab, ret, backspace…)
#   iso/vm-dev.sh click <x> <y>  a left click at screen pixel x,y (1920×1080)
#   iso/vm-dev.sh shot <name>    a picture of the live → vm/runs/dev/<name>.png
#   iso/vm-dev.sh sh '<cmd>'     a command as root in the live
#   iso/vm-dev.sh down           power off and delete vm/runs/dev (its disk too)
set -Eeuo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO="$(cd -- "$HERE/.." && pwd -P)"
D="$HOME/Work/AngelOS/vm/runs/dev"
g() { timeout 60 python3 -I "$HERE/qga.py" "$D/qga.sock" "$@"; }
AS_ANGEL='runuser -u angel -- env XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1'
case "${1:-}" in
  up)
    mkdir -p "$D"; rm -f "$D"/*.png
    cp /usr/share/edk2/x64/OVMF_VARS.4m.fd "$D/vars.fd"
    qemu-img create -q -f qcow2 "$D/disk.qcow2" 40G
    nice -n 15 qemu-system-x86_64 -enable-kvm -cpu host -smp 4 -m 4096 -machine q35 \
      -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
      -drive if=pflash,format=raw,file="$D/vars.fd" -drive file="$D/disk.qcow2",if=virtio,format=qcow2 \
      -cdrom "${2:?iso}" -boot d -device virtio-vga-gl,xres=1920,yres=1080 -display egl-headless \
      -audiodev none,id=snd -nic user,model=virtio-net-pci -device qemu-xhci -device usb-tablet \
      -device virtio-serial -chardev "socket,path=$D/qga.sock,server=on,wait=off,id=qga0" \
      -device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0 \
      -qmp "unix:$D/qmp.sock,server,nowait" -daemonize -pidfile "$D/qemu.pid"
    for ((i = 0; i < 60; i++)); do g true 2>/dev/null && break; sleep 5; done
    g true && echo "up" ;;
  push)
    cd "$REPO"
    mapfile -t files < <({ git diff --name-only "${BASE:-main}" -- .config/quickshell/angelos; git ls-files -o --exclude-standard -- .config/quickshell/angelos; } | sort -u)
    for f in "${files[@]}"; do
      [[ -f $f ]] || continue
      dst="/home/angel/${f}"
      g "mkdir -p '$(dirname "$dst")'" && g --push "$f" "$dst" && echo "→ $f"
    done
    [[ -f $REPO/iso/profile/airootfs/usr/local/bin/angelos-install-disk ]] &&
      g --push "$REPO/iso/profile/airootfs/usr/local/bin/angelos-install-disk" /usr/local/bin/angelos-install-disk && g "chmod 755 /usr/local/bin/angelos-install-disk"
    g "chown -R angel:angel /home/angel/.config/quickshell; grep -q ANGELOS_INSTALLER /home/angel/.config/environment.d/50-angelos-live.conf || echo ANGELOS_INSTALLER=1 >>/home/angel/.config/environment.d/50-angelos-live.conf
       runuser -u angel -- env XDG_RUNTIME_DIR=/run/user/1000 systemctl --user set-environment ANGELOS_INSTALLER=1
       runuser -u angel -- env XDG_RUNTIME_DIR=/run/user/1000 systemctl --user restart angelos.service" && echo "shell restarted" ;;
  keys)
    shift
    python3 -I - "$D/qmp.sock" "$@" <<'PY'
import json, socket, sys, time
s = socket.socket(socket.AF_UNIX); s.connect(sys.argv[1]); f = s.makefile("rw"); f.readline()
def call(cmd, **a):
    f.write(json.dumps({"execute": cmd, "arguments": a}) + "\n"); f.flush()
    while "return" not in (r := json.loads(f.readline())):
        if "error" in r: sys.exit(r["error"]["desc"])
call("qmp_capabilities")
for k in sys.argv[2:]:
    call("send-key", keys=[{"type": "qcode", "data": x} for x in k.split("-") if x] if k != "minus" else [{"type": "qcode", "data": "minus"}]); time.sleep(0.12)
PY
    ;;
  click)
    python3 -I - "$D/qmp.sock" "${2:?x}" "${3:?y}" <<'PY'
import json, socket, sys, time
s = socket.socket(socket.AF_UNIX); s.connect(sys.argv[1]); f = s.makefile("rw"); f.readline()
def call(cmd, **a):
    f.write(json.dumps({"execute": cmd, "arguments": a}) + "\n"); f.flush()
    while "return" not in (r := json.loads(f.readline())):
        if "error" in r: sys.exit(r["error"]["desc"])
call("qmp_capabilities")
x, y = int(sys.argv[2]) * 32767 // 1919, int(sys.argv[3]) * 32767 // 1079
call("input-send-event", events=[{"type": "abs", "data": {"axis": "x", "value": x}}, {"type": "abs", "data": {"axis": "y", "value": y}}])
time.sleep(0.1)
for down in (True, False):
    call("input-send-event", events=[{"type": "btn", "data": {"down": down, "button": "left"}}]); time.sleep(0.08)
PY
    ;;
  shot) g "$AS_ANGEL grim -" >"$D/${2:?name}.png" && echo "$D/$2.png" ;;
  sh) g "${2:?cmd}" ;;
  down) g "systemctl poweroff" >/dev/null 2>&1 || true; sleep 5; kill "$(cat "$D/qemu.pid")" 2>/dev/null || true; rm -rf "$D" ;;
  *) sed -n 2,9p "$0"; exit 2 ;;
esac
