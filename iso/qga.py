"""qga.py <socket> '<shell command>' → its stdout; runs as root in the guest through the QEMU guest agent
(a virtio port: no network or sshd in the image). Fails while the agent is not up yet."""
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
sys.stderr.buffer.write(base64.b64decode(st.get("err-data", "")))
sys.exit(st.get("exitcode", 1))
