#!/usr/bin/env python3
"""angelOS: a picture dragged from a browser onto the Halo's shelf, into a file.

  shelf-fetch.py OUT_DIR [REFERER] [--name NAME] < source

The source (on stdin: a data: address can be megabytes, too long for an argument) is the
picture's own address, taken from the <img> the browser put in the drag:
  · http(s): fetched the way a browser would — its User-Agent, Accept and a Referer (the page's
    link when the drag had one, else the picture's own site); some sites refuse without them;
    once more without the Referer if that is refused;
  · data:image/…;base64,… : written out as it is;
  · blob: lives only inside the browser — nothing to fetch (exit 3).
The file is named after the address, its extension from what came (the bytes, not the address:
a «.php?id=3» is a JPEG). Only a picture is kept. Prints the file's path; exit 0 = done.
"""
import base64
import os
import re
import sys
import time
import urllib.parse
import urllib.request

UA = ("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) "
      "Chrome/140.0.0.0 Safari/537.36")
MAX = 64 * 1024 * 1024

MAGIC = [
    (b"\x89PNG\r\n\x1a\n", "png"),
    (b"\xff\xd8\xff", "jpg"),
    (b"GIF87a", "gif"),
    (b"GIF89a", "gif"),
    (b"BM", "bmp"),
]


def kind(data):
    for sig, ext in MAGIC:
        if data.startswith(sig):
            return ext
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "webp"
    if data[4:12] in (b"ftypavif", b"ftypavis"):
        return "avif"
    head = data[:512].lstrip().lower()
    if head.startswith(b"<svg") or (head.startswith(b"<?xml") and b"<svg" in head):
        return "svg"
    return None


def name_of(src):
    if src.startswith("data:"):
        return "picture"
    path = urllib.parse.urlsplit(src).path
    stem = os.path.splitext(os.path.basename(urllib.parse.unquote(path)))[0]
    stem = re.sub(r"[^\w.-]+", "_", stem).strip("._")[:60]
    return stem or "picture"


def fetch(src, referer):
    headers = {"User-Agent": UA, "Accept": "image/avif,image/webp,image/apng,image/*,*/*;q=0.8"}
    if referer:
        headers["Referer"] = referer
    req = urllib.request.Request(src, headers=headers)
    with urllib.request.urlopen(req, timeout=20) as r:
        data = r.read(MAX + 1)
    if len(data) > MAX:
        raise ValueError("too big")
    return data


def main(argv):
    if len(argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    args = argv[1:]
    given = ""
    if "--name" in args:
        k = args.index("--name")
        given = args[k + 1] if k + 1 < len(args) else ""
        del args[k:k + 2]
    out_dir = args[0]
    referer = args[1] if len(args) > 1 else ""
    src = sys.stdin.read().strip()
    if src.startswith("blob:"):
        print("blob: lives only in the browser", file=sys.stderr)
        return 3
    try:
        if src.startswith("data:"):
            head, _, body = src.partition(",")
            data = base64.b64decode(body) if ";base64" in head else urllib.parse.unquote_to_bytes(body)
        elif re.match(r"https?://", src, re.I):
            own = "{0.scheme}://{0.netloc}/".format(urllib.parse.urlsplit(src))
            try:
                data = fetch(src, referer or own)
            except Exception:
                data = fetch(src, "")
        else:
            print("not an address: " + src[:80], file=sys.stderr)
            return 2
    except Exception as e:
        print("fetch failed: %s" % e, file=sys.stderr)
        return 1
    ext = kind(data)
    if not ext:
        print("not a picture", file=sys.stderr)
        return 4
    os.makedirs(out_dir, exist_ok=True)
    stem = re.sub(r"[^\w.-]+", "_", given).strip("._")[:60] or name_of(src)
    path = os.path.join(out_dir, "%d-%s.%s" % (int(time.time() * 1000), stem, ext))
    with open(path + ".tmp", "wb") as f:
        f.write(data)
    os.replace(path + ".tmp", path)
    print(path)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
