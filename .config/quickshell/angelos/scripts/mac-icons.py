#!/usr/bin/env python3
"""The Golden Gate Dock's icons: MacTahoe, a free icon theme drawn like macOS 26 (GPL-3.0,
(c) Vince Liuice, github.com/vinceliuice/MacTahoe-icon-theme) — no file of Apple's.

  mac-icons.py status      -> JSON: where the theme is (ours, or one installed already) and the
                              names it has in apps/ and places/ (scalable)
  mac-icons.py install     -> download the pinned release, verify SHA-256, put the theme together
                              in ~/.local/share/angelos/icons/MacTahoe
  mac-icons.py remove      -> delete the copy made by this script

The theme is put together here the way its install.sh makes the default variant (src/ then the
links/ over it), but nothing from the download is executed: only regular files, folders and
symbolic links that stay inside the theme are taken. It is not in the icon theme path, so GTK
and the rest keep theirs: only the Dock reads it. Python standard library only.
"""
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import posixpath
import shutil
import sys
import tarfile
import tempfile
import urllib.request

DATA = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
OURS = DATA / "angelos/icons/MacTahoe"
# a MacTahoe installed already (its install.sh, a package) is used as it is
OTHERS = [DATA / "icons/MacTahoe", Path.home() / ".icons/MacTahoe", Path("/usr/share/icons/MacTahoe")]
RELEASE = "2026-09-10"
URL = "https://codeload.github.com/vinceliuice/MacTahoe-icon-theme/tar.gz/refs/tags/" + RELEASE
SHA256 = "6330369e9e10a28cfc8da598ebf63a7204be705403519963ff84e1cb84719d35"
MAX_DOWNLOAD = 24 * 1024 * 1024
# what the default variant is made of (install.sh, color ''): these folders of src/ and links/
PARTS = ["actions", "animations", "apps", "categories", "devices", "emotes", "emblems", "mimes",
         "places", "preferences", "status"]
STATUS = ["16", "22", "24", "32", "symbolic"]
KINDS = ["apps", "places"]


def where():
    for d in [OURS] + OTHERS:
        if (d / "index.theme").is_file() and (d / "apps/scalable").is_dir():
            return d
    return None


def names(theme, kind):
    folder = theme / kind / "scalable"
    try:
        return sorted(p.name[:-4] for p in folder.iterdir() if p.name.endswith(".svg") and p.exists())
    except OSError:
        return []


def status():
    theme = where()
    out = {"installed": theme is not None, "ours": theme == OURS, "dir": str(theme or ""),
           "release": RELEASE, "license": "GPL-3.0",
           "homepage": "https://github.com/vinceliuice/MacTahoe-icon-theme"}
    if theme:
        out["names"] = {kind: names(theme, kind) for kind in KINDS}
    return out


def fetch():
    request = urllib.request.Request(URL, headers={"User-Agent": "angelOS-mac-icons/1"})
    with urllib.request.urlopen(request, timeout=120) as response:
        data = response.read(MAX_DOWNLOAD + 1)
    if len(data) > MAX_DOWNLOAD:
        raise ValueError("Download is too large")
    if hashlib.sha256(data).hexdigest() != SHA256:
        raise ValueError("Checksum mismatch for " + URL)
    return data


def wanted(rel):
    """The path inside the theme for an archive path (without its top folder), or None."""
    parts = rel.parts
    if rel.as_posix() in ("COPYING", "AUTHORS", "src/index.theme"):
        return PurePosixPath(parts[-1])
    if len(parts) < 2 or parts[0] not in ("src", "links") or parts[1] not in PARTS:
        return None
    if parts[1] == "status" and (len(parts) < 3 or parts[2] not in STATUS):
        return None
    return PurePosixPath(*parts[1:])


def build(data, staging):
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as archive:
        for member in archive:
            top, _, rest = member.name.partition("/")
            if not rest or ".." in PurePosixPath(rest).parts:
                continue
            target = wanted(PurePosixPath(rest))
            if target is None:
                continue
            dst = staging / target
            if member.isdir():
                dst.mkdir(parents=True, exist_ok=True)
            elif member.isfile():
                dst.parent.mkdir(parents=True, exist_ok=True)
                if dst.is_symlink():
                    dst.unlink()
                dst.write_bytes(archive.extractfile(member).read())
                dst.chmod(0o644)
            elif member.issym():
                link = member.linkname
                inside = posixpath.normpath(posixpath.join(target.parent.as_posix(), link))
                if posixpath.isabs(link) or inside == ".." or inside.startswith("../"):
                    continue
                dst.parent.mkdir(parents=True, exist_ok=True)
                if dst.is_symlink() or dst.is_file():
                    dst.unlink()
                elif dst.is_dir():
                    continue
                dst.symlink_to(link)
    if not (staging / "index.theme").is_file() or not (staging / "apps/scalable").is_dir():
        raise ValueError("The archive has no icon theme")
    (staging / ".angelos").write_text(RELEASE + "\n")


def install():
    data = fetch()
    OURS.parent.mkdir(parents=True, exist_ok=True)
    staging = Path(tempfile.mkdtemp(prefix=".install-", dir=OURS.parent))
    try:
        build(data, staging)
        staging.chmod(0o755)
        if OURS.is_symlink():
            OURS.unlink()
        elif OURS.exists():
            shutil.rmtree(OURS)
        staging.rename(OURS)
    finally:
        if staging.exists():
            shutil.rmtree(staging)
    return status()


def remove():
    if OURS.is_dir() and not OURS.is_symlink() and (OURS / ".angelos").exists():
        shutil.rmtree(OURS)
    return {"removed": True} | status()


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "status"
    try:
        if action == "status":
            result = status()
        elif action == "install":
            result = install()
        elif action == "remove":
            result = remove()
        else:
            raise ValueError("usage: mac-icons.py status | install | remove")
    except (OSError, ValueError, tarfile.TarError) as error:
        result = {"error": str(error)}
    print(json.dumps(result, ensure_ascii=False))
    return 1 if "error" in result else 0


if __name__ == "__main__":
    sys.exit(main())
