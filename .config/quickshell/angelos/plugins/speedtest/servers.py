#!/usr/bin/env python3
"""speedtest-cli with today's server list (Speed.qml runs this in its place).

speedtest.net's old server list, the one speedtest-cli reads, came back with only far-away
servers (Iran) that a VPN cannot reach, and the test failed. The list the site itself uses
(its JS API) names the near ones; this takes it, over https (a VPN drops plain http), and falls
back to the old one. Everything else is speedtest-cli's own. After frostpix's pc-kit.
"""
import json
import sys
import urllib.request

try:
    import speedtest
except ImportError:
    sys.exit(127)   # Speed.qml: "speedtest-cli is not installed"

API = "https://www.speedtest.net/api/js/servers?engine=js&limit=20&https_functional=true"
_old = speedtest.Speedtest.get_servers


def get_servers(self, servers=None, exclude=None):
    servers, exclude = servers or [], exclude or []
    try:
        req = urllib.request.Request(API, headers={"User-Agent": "curl/8.10"})
        data = json.load(urllib.request.urlopen(req, timeout=10))
        self.servers.clear()
        for s in data:
            sid = int(s["id"])
            if (servers and sid not in servers) or sid in exclude:
                continue
            a = {k: str(v) for k, v in s.items()}
            a["url"] = "https://%s/speedtest/upload.php" % a["host"]
            a["d"] = d = speedtest.distance(self.lat_lon, (float(a["lat"]), float(a["lon"])))
            self.servers.setdefault(d, []).append(a)
        if self.servers:
            return self.servers
    except (OSError, ValueError, KeyError, TypeError):
        pass
    return _old(self, servers, exclude)


speedtest.Speedtest.get_servers = get_servers
if __name__ == "__main__":
    sys.argv[0] = "speedtest-cli"
    sys.exit(speedtest.main())
