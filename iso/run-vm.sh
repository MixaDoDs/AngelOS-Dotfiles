#!/usr/bin/env bash
# Boots an angelOS ISO in QEMU (UEFI) with no window at all — egl-headless, so DP-1 never sees it —
# and saves a screenshot every STEP seconds until SECS have passed, then powers the VM off.
#
#   iso/run-vm.sh ~/Work/AngelOS/export/iso/angelos-*.iso      → ~/Work/AngelOS/vm/runs/iso-<MMDD-HHMM>/
#   SECS=300 STEP=10 iso/run-vm.sh <iso>
set -Eeuo pipefail

ISO="${1:?usage: iso/run-vm.sh <iso>}"
SECS="${SECS:-180}" STEP="${STEP:-15}"
D="${OUT_DIR:-$HOME/Work/AngelOS/vm/runs/iso-$(date +%m%d-%H%M)}"
mkdir -p "$D"
cp /usr/share/edk2/x64/OVMF_VARS.4m.fd "$D/vars.fd"

nice -n 15 qemu-system-x86_64 -enable-kvm -cpu host -smp 4 -m 4096 -machine q35 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
  -drive if=pflash,format=raw,file="$D/vars.fd" \
  -cdrom "$ISO" -boot d \
  -device virtio-vga-gl,xres=1920,yres=1080 -display egl-headless \
  -audiodev none,id=snd -nic user,model=virtio-net-pci \
  -qmp "unix:$D/qmp.sock,server,nowait" -daemonize -pidfile "$D/qemu.pid"

qmp() { # one QMP command (after the capabilities handshake)
  python3 -I - "$D/qmp.sock" "$1" <<'PY'
import json, socket, sys
s = socket.socket(socket.AF_UNIX); s.connect(sys.argv[1]); f = s.makefile("rw")
f.readline()
for cmd in ({"execute": "qmp_capabilities"}, json.loads(sys.argv[2])):
    f.write(json.dumps(cmd) + "\n"); f.flush()
    while "return" not in (r := json.loads(f.readline())) and "error" not in r: pass
    if "error" in r: sys.exit(r["error"]["desc"])
PY
}

for ((t = STEP; t <= SECS; t += STEP)); do
  sleep "$STEP"
  qmp "{\"execute\":\"screendump\",\"arguments\":{\"filename\":\"$D/$(printf %03d "$t").png\",\"format\":\"png\"}}" || break
done
qmp '{"execute":"quit"}' || true
echo "$D"
