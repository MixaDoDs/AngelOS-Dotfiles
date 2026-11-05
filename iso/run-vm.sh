#!/usr/bin/env bash
# Boots an angelOS ISO in QEMU (UEFI) with no window at all — egl-headless, so DP-1 never sees it.
# Pictures and logs come through the QEMU guest agent (a virtio port, no network, no sshd in the image):
# a grim screenshot every STEP seconds until SECS, then the shell's journal, then power off.
#
#   iso/run-vm.sh ~/Work/AngelOS/export/iso/angelos-*.iso      → ~/Work/AngelOS/vm/runs/iso-<MMDD-HHMM>/
#   SECS=300 STEP=10 iso/run-vm.sh <iso>
set -Eeuo pipefail

ISO="${1:?usage: iso/run-vm.sh <iso>}"
SECS="${SECS:-180}" STEP="${STEP:-20}"
D="${OUT_DIR:-$HOME/Work/AngelOS/vm/runs/iso-$(date +%m%d-%H%M)}"
mkdir -p "$D"
cp /usr/share/edk2/x64/OVMF_VARS.4m.fd "$D/vars.fd"

nice -n 15 qemu-system-x86_64 -enable-kvm -cpu host -smp 4 -m 4096 -machine q35 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
  -drive if=pflash,format=raw,file="$D/vars.fd" \
  -cdrom "$ISO" -boot d \
  -device virtio-vga-gl,xres=1920,yres=1080 -display egl-headless \
  -audiodev none,id=snd -nic user,model=virtio-net-pci \
  -device virtio-serial -chardev "socket,path=$D/qga.sock,server=on,wait=off,id=qga0" \
  -device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0 \
  -qmp "unix:$D/qmp.sock,server,nowait" -daemonize -pidfile "$D/qemu.pid"

# g 'shell command' → its stdout (run as root in the guest); fails while the agent is not up yet
g() {
  timeout 60 python3 -I - "$D/qga.sock" "$1" <<'PY'
import base64, json, socket, sys, time
s = socket.socket(socket.AF_UNIX); s.settimeout(10); s.connect(sys.argv[1]); f = s.makefile("rw")
def call(cmd, **args):
    f.write(json.dumps({"execute": cmd, "arguments": args}) + "\n"); f.flush()
    while True:
        r = json.loads(f.readline())
        if "return" in r: return r["return"]
        if "error" in r: sys.exit(r["error"]["desc"])
call("guest-sync", id=4711)
pid = call("guest-exec", path="/bin/sh", arg=["-c", sys.argv[2]], **{"capture-output": True})["pid"]
while not (st := call("guest-exec-status", pid=pid))["exited"]: time.sleep(0.3)
sys.stdout.buffer.write(base64.b64decode(st.get("out-data", "")))
sys.exit(st.get("exitcode", 1))
PY
}
AS_ANGEL='export XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1;'

for ((t = STEP; t <= SECS; t += STEP)); do
  sleep "$STEP"
  kill -0 "$(cat "$D/qemu.pid")" 2>/dev/null || { echo "✕ QEMU is gone"; break; }
  if g "runuser -u angel -- sh -c '$AS_ANGEL grim -'" >"$D/$(printf %03d "$t").png" 2>/dev/null; then
    echo "$t s: picture"
  else
    rm -f "$D/$(printf %03d "$t").png"; echo "$t s: no picture (agent or session not up)"
  fi
  # who holds the memory (the journal's OOM report names only "python3")
  { echo "== $t s"; g "free -m | sed -n 2p; ps -eo rss=,args= --sort=-rss | head -6 | cut -c1-200"; } >>"$D/memory.txt" 2>/dev/null || true
done
g "journalctl -b --no-pager -o short-monotonic" >"$D/journal.txt" 2>/dev/null || true
g "runuser -u angel -- journalctl --user -b --no-pager" >"$D/user-journal.txt" 2>/dev/null || true
g "systemctl --failed --no-pager; pgrep -a quickshell; pgrep -a niri" >"$D/state.txt" 2>/dev/null || true
g "systemctl poweroff" >/dev/null 2>&1 || true
sleep 5; kill "$(cat "$D/qemu.pid")" 2>/dev/null || true
echo "$D"
