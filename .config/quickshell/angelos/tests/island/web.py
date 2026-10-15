#!/usr/bin/env python3
"""tests/island/run.sh: a little web on 127.0.0.1 for the island's own program. /p1 moves on to
/p2 by itself (so "the page it is on now" differs from the link it opened with); POST /upload
is where the Lens page posts the picture. Every request goes into LOG as one line.
  web.py PORTFILE LOG PNG"""
import http.server
import sys

port_file, log, png = sys.argv[1:4]
want = open(png, "rb").read()


class H(http.server.BaseHTTPRequestHandler):
    def note(self, s):
        with open(log, "a") as f:
            f.write(s + "\n")

    def reply(self, body):
        b = body.encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def do_GET(self):
        self.note("GET " + self.path)
        if self.path == "/p1":
            self.reply("<title>one</title><script>location.replace('/p2?x=1')</script>")
        else:
            self.reply("<title>two</title>page two")

    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        ok = b'name="encoded_image"' in body and want in body
        self.note("POST %s %s %d" % (self.path, "picture" if ok else "no-picture", len(body)))
        self.reply("<title>lens</title>got it")

    def log_message(self, *a):
        pass


# threads: Chromium opens spare connections that never send a request
s = http.server.ThreadingHTTPServer(("127.0.0.1", 0), H)
open(port_file, "w").write(str(s.server_address[1]))
s.serve_forever()
