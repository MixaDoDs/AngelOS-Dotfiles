# A slow download for tests/downloads: /slow.bin (3 MB over ~4 s), /tiny.txt (7 KB at once),
# both as attachments, so a browser saves them.  python3 serve.py PORT
import http.server, sys, time


class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        slow = self.path.startswith("/slow")
        name = "slow.bin" if slow else "tiny.txt"
        n = 3_000_000 if slow else 7_000
        self.send_response(200)
        self.send_header("Content-Type", "application/octet-stream")
        self.send_header("Content-Disposition", 'attachment; filename="%s"' % name)
        self.send_header("Content-Length", str(n))
        self.end_headers()
        parts = 40 if slow else 1
        for _ in range(parts):
            self.wfile.write(b"\0" * (n // parts))
            self.wfile.flush()
            if slow:
                time.sleep(0.1)

    def log_message(self, *a):
        pass


http.server.ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
