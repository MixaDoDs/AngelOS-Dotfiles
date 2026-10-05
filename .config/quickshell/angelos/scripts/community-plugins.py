#!/usr/bin/env python3
"""AngelOS's built-in community catalog. No third-party Python dependencies.

The catalog and the installer both read the official registry; a GUI-supplied
URL can never bypass moderation. Inspired by angelos-community-store's ZIP
validation, but independent of the optional Community Store plugin.
"""
import hashlib
import io
import json
import os
import re
import shutil
import stat
import sys
import tempfile
import time
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path, PurePosixPath

REGISTRY_URL = "https://raw.githubusercontent.com/futureUnd1ground/angelos-community-registry/main/plugins.json"
MAX_REGISTRY = 2 * 1024 * 1024
MAX_ARCHIVE = 64 * 1024 * 1024
MAX_FILES = 2000
PLUGIN_ID = re.compile(r"^[a-z0-9][a-z0-9_-]{1,63}$")


def _download(url, limit, timeout):
    if urllib.parse.urlsplit(url).scheme != "https":
        raise ValueError("HTTPS is required")
    request = urllib.request.Request(url, headers={"User-Agent": "AngelOS-community-plugins/1"})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        if urllib.parse.urlsplit(response.geturl()).scheme != "https":
            raise ValueError("HTTPS is required after redirects")
        data = response.read(limit + 1)
    if len(data) > limit:
        raise ValueError("Download is too large")
    return data


def catalog():
    # Cache-busting matters when a maintainer suspends an approved entry.
    url = REGISTRY_URL + "?_angelos=" + str(time.time_ns())
    payload = json.loads(_download(url, MAX_REGISTRY, 20).decode("utf-8"))
    if not isinstance(payload, dict) or payload.get("version") != 1 or not isinstance(payload.get("plugins"), list):
        raise ValueError("Unsupported community registry format")
    entries = []
    for entry in payload["plugins"]:
        if not isinstance(entry, dict) or entry.get("status") != "approved":
            continue
        plugin_id, version, source = entry.get("id"), entry.get("version"), entry.get("source")
        if (not isinstance(plugin_id, str) or not PLUGIN_ID.fullmatch(plugin_id)
                or not isinstance(version, str) or not version.strip()
                or not isinstance(entry.get("name"), str) or not entry["name"].strip()
                or not isinstance(source, str) or urllib.parse.urlsplit(source).scheme != "https"):
            continue
        if entry.get("sha256") is not None and (
                not isinstance(entry["sha256"], str) or not re.fullmatch(r"[a-fA-F0-9]{64}", entry["sha256"])):
            continue
        safe = dict(entry)
        for field in ("tags", "dependencies", "permissions", "screenshots"):
            value = entry.get(field)
            safe[field] = [item for item in value if isinstance(item, str)] if isinstance(value, list) else []
        for field in ("author", "description", "category", "license", "repository", "homepage", "changelog"):
            safe[field] = entry[field] if isinstance(entry.get(field), str) else ""
        if safe["repository"] and urllib.parse.urlsplit(safe["repository"]).scheme != "https":
            safe["repository"] = ""
        entries.append(safe)
    return entries


def _unpack(data, root, expected_id, expected_version):
    archive = zipfile.ZipFile(io.BytesIO(data))
    with archive:
        members = archive.infolist()
        if len(members) > MAX_FILES or sum(m.file_size for m in members) > MAX_ARCHIVE:
            raise ValueError("Plugin archive exceeds size or file limit")
        seen = set()
        for member in members:
            name = member.filename
            path = PurePosixPath(name)
            mode = member.external_attr >> 16
            if (not name or not path.parts or "\\" in name or "\x00" in name or name.startswith("/")
                    or ".." in path.parts or ":" in path.parts[0]
                    or stat.S_ISLNK(mode) or (stat.S_IFMT(mode) not in (0, stat.S_IFDIR, stat.S_IFREG))):
                raise ValueError("Plugin archive contains an unsafe path or link")
            normalized = str(path)
            if normalized in seen:
                raise ValueError("Plugin archive contains an unsafe duplicate path")
            seen.add(normalized)
        archive.extractall(root)
    manifests = list(root.rglob("manifest.json"))
    if len(manifests) != 1 or len(manifests[0].relative_to(root).parts) not in (1, 2):
        raise ValueError("Plugin archive must contain one top-level manifest.json")
    manifest = json.loads(manifests[0].read_text(encoding="utf-8"))
    if not isinstance(manifest, dict) or manifest.get("id") != expected_id:
        raise ValueError("Plugin manifest id does not match registry")
    if manifest.get("version") != expected_version:
        raise ValueError("Plugin manifest version does not match registry")
    if not isinstance(manifest.get("name"), str) or not manifest["name"].strip():
        raise ValueError("Plugin manifest name is missing")
    return manifests[0].parent


def install(plugin_id, version, home=None, existing_version=None):
    if not isinstance(plugin_id, str) or not PLUGIN_ID.fullmatch(plugin_id):
        raise ValueError("Invalid plugin id")
    entry = next((p for p in catalog() if p["id"] == plugin_id), None)
    if not entry:
        raise ValueError("Plugin is not approved in the current registry")
    if entry["version"] != version:
        raise ValueError("Registry changed; refresh the catalog before installing")
    data = _download(entry["source"], MAX_ARCHIVE, 60)
    if entry.get("sha256") and hashlib.sha256(data).hexdigest().lower() != entry["sha256"].lower():
        raise ValueError("Release SHA-256 does not match the reviewed registry digest")
    plugins_dir = (home if home is not None else Path.home()) / ".config/angelos/plugins"
    if plugins_dir.is_symlink():
        raise ValueError("Plugin directory is a symbolic link")
    plugins_dir.mkdir(parents=True, exist_ok=True)
    destination = plugins_dir / plugin_id
    if destination.is_symlink():
        raise ValueError("Existing plugin is a symbolic link")
    if destination.exists() and not destination.is_dir():
        raise ValueError("Existing plugin is not a directory")
    if existing_version is None and destination.exists():
        raise ValueError("Plugin already exists; refresh and confirm an update")
    if existing_version is not None and not destination.exists():
        raise ValueError("Existing plugin changed; refresh the catalog")
    with tempfile.TemporaryDirectory(prefix=".community-install-", dir=plugins_dir) as temp:
        extracted = Path(temp) / "unpacked"
        extracted.mkdir()
        source = _unpack(data, extracted, plugin_id, version)
        # An existing directory with a different manifest is not our plugin.
        if destination.exists():
            try:
                current = json.loads((destination / "manifest.json").read_text(encoding="utf-8"))
            except (OSError, ValueError) as exc:
                raise ValueError("Existing plugin has no valid manifest") from exc
            if not isinstance(current, dict) or current.get("id") != plugin_id:
                raise ValueError("Existing plugin id does not match")
            if current.get("version") != existing_version:
                raise ValueError("Existing plugin changed; refresh the catalog")
        staged = Path(temp) / "staged"
        shutil.copytree(source, staged)
        backup = None
        if destination.exists():
            trash = plugins_dir.parent.parent.parent / ".local/state/angelos/plugin-trash"
            trash.mkdir(parents=True, exist_ok=True)
            for i in range(100):
                stamp = time.strftime("%Y%m%d-%H%M%S", time.localtime(time.time() + i))
                candidate = trash / (stamp + "-" + plugin_id)
                if not candidate.exists() and not candidate.is_symlink():
                    backup = candidate
                    break
            if backup is None:
                raise ValueError("Could not reserve a plugin backup")
            os.replace(destination, backup)
        try:
            os.replace(staged, destination)
        except Exception:
            if backup is not None and backup.exists() and not destination.exists():
                os.replace(backup, destination)
            raise
    return {"id": plugin_id, "version": version, "updated": backup is not None}


def main(args):
    if args == ["list"]:
        print(json.dumps({"plugins": catalog()}, ensure_ascii=False))
    elif len(args) == 3 and args[0] == "install":
        print(json.dumps(install(args[1], args[2]), ensure_ascii=False))
    elif len(args) == 4 and args[0] == "update":
        print(json.dumps(install(args[1], args[2], existing_version=args[3]), ensure_ascii=False))
    else:
        raise ValueError("Usage: community-plugins.py list | install ID VERSION | update ID VERSION OLD_VERSION")


if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except (OSError, ValueError, zipfile.BadZipFile, urllib.error.URLError) as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
