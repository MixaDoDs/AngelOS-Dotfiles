#!/usr/bin/env python3
"""angelOS Community Plugins: the one catalog of plugins (Settings → Plugins).
No third-party Python dependencies.

  community-plugins.py list                          -> {"plugins": [approved registry entries]}
  community-plugins.py install ID VERSION            -> a new plugin
  community-plugins.py update ID VERSION OLD         -> a newer version over OLD (a bundled plugin
                                                        gets a copy of its own that shadows it)
  community-plugins.py rollback ID                   -> the snapshot taken before the last update back
  community-plugins.py retire                        -> the old stand-alone Community Store plugin out
                                                        of the plugin folder (its job is angelOS's now)

The catalog and the installer both read the official registry; a GUI-supplied
URL can never bypass moderation. Before an update the installed copy is kept as a
snapshot in ~/.local/state/angelos/plugin-backups/<id>/<stamp>/ (the same place
Plugin Studio keeps its versions, so its «roll back» sees them too); `rollback`
puts it back when the new version does not load. Install and update print the
fresh load path (~/.cache/angelos/plugin-load/<id>.<n>): QML caches components by
URL, the shell loads the new files through it without a restart.
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
SHELL = Path(__file__).resolve().parents[1]
STAMP = re.compile(r"\d{8}-\d{6}(?:-\d+)?")
SNAPSHOTS_KEEP = 10
# plugins whose job angelOS does itself now: never installed, never loaded
RETIRED = ("community-store",)


def _home(home=None):
    return home if home is not None else Path.home()


def _snapshots(plugin_id, home=None):
    return _home(home) / ".local/state/angelos/plugin-backups" / plugin_id


def _bundled_version(plugin_id):
    try:
        manifest = json.loads((SHELL / "plugins" / plugin_id / "manifest.json").read_text(encoding="utf-8"))
        return manifest.get("version") if isinstance(manifest, dict) else None
    except (OSError, ValueError):
        return None


def _stamp_dir(folder):
    folder.mkdir(mode=0o700, parents=True, exist_ok=True)
    if folder.is_symlink() or not folder.is_dir():
        raise ValueError("Snapshot directory must not be a symbolic link")
    stamp = time.strftime("%Y%m%d-%H%M%S")
    target, n = folder / stamp, 1
    while target.exists() or (folder / (target.name + ".json")).exists():
        target, n = folder / f"{stamp}-{n}", n + 1
    return target


def _snapshot_list(plugin_id, home=None):
    folder = _snapshots(plugin_id, home)
    if folder.is_symlink() or not folder.is_dir():
        return []
    return sorted((p for p in folder.iterdir() if p.suffix == ".json" and STAMP.fullmatch(p.stem)), key=lambda p: p.stem)


def _prune(plugin_id, home=None):
    for old in _snapshot_list(plugin_id, home)[:-SNAPSHOTS_KEEP]:
        shutil.rmtree(old.with_suffix(""), ignore_errors=True)
        old.unlink(missing_ok=True)


def load_dir(plugin_id, destination, home=None):
    """a fresh path to the plugin for the shell (Plugin Studio's scheme)"""
    root = _home(home) / ".cache/angelos/plugin-load"
    root.mkdir(parents=True, exist_ok=True)
    for old in root.glob(plugin_id + ".*"):
        if old.is_symlink():
            old.unlink()
    link = root / f"{plugin_id}.{time.time_ns()}"
    os.symlink(destination, link)
    return str(link)


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
        if not isinstance(entry, dict) or entry.get("status") != "approved" or entry.get("id") in RETIRED:
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
        # the looks it draws (manifest "themes": "pixel", "mac"); none: made before the Mac look
        value = entry.get("themes")
        safe["themes"] = [t for t in value if t in ("pixel", "mac")] if isinstance(value, list) else []
        for field in ("author", "description", "category", "license", "repository", "homepage", "changelog", "icon",
                      "minAngelOSVersion"):
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
    plugins_dir = _home(home) / ".config/angelos/plugins"
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
    # a bundled plugin is updated by a copy of its own in the user folder (it shadows the bundled one)
    over_bundled = existing_version is not None and not destination.exists()
    if over_bundled and _bundled_version(plugin_id) != existing_version:
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
        if existing_version is not None:
            # the snapshot: the installed copy itself, moved aside whole (or, over a bundled
            # plugin, only a note — rolling back removes the copy and the bundled one shows again)
            backup = _stamp_dir(_snapshots(plugin_id, home))
            note = {"reason": "update", "version": str(existing_version), "to": version, "bundled": over_bundled}
            (backup.parent / (backup.name + ".json")).write_text(json.dumps(note), encoding="utf-8")
            if not over_bundled:
                os.replace(destination, backup)
        try:
            os.replace(staged, destination)
        except Exception:
            if backup is not None and backup.exists() and not destination.exists():
                os.replace(backup, destination)
            if backup is not None:
                (backup.parent / (backup.name + ".json")).unlink(missing_ok=True)
            raise
    if backup is not None:
        _prune(plugin_id, home)
    return {"id": plugin_id, "version": version, "updated": backup is not None,
            "snapshot": str(backup) if backup is not None else "", "loadDir": load_dir(plugin_id, destination, home)}


def rollback(plugin_id, home=None):
    """the newest snapshot back in place of the plugin (an update that does not load)"""
    if not isinstance(plugin_id, str) or not PLUGIN_ID.fullmatch(plugin_id):
        raise ValueError("Invalid plugin id")
    notes = _snapshot_list(plugin_id, home)
    if not notes:
        raise ValueError("No snapshot of this plugin is saved")
    note_path = notes[-1]
    note = json.loads(note_path.read_text(encoding="utf-8"))
    snapshot = note_path.with_suffix("")
    destination = _home(home) / ".config/angelos/plugins" / plugin_id
    if destination.is_symlink():
        raise ValueError("Existing plugin is a symbolic link")
    # the version that did not load is kept too (in the trash: Settings → Plugins → Removed)
    failed = None
    if destination.exists():
        trash = _home(home) / ".local/state/angelos/plugin-trash"
        trash.mkdir(parents=True, exist_ok=True)
        failed = trash / (time.strftime("%Y%m%d-%H%M%S") + "-" + plugin_id)
        n = 1
        while failed.exists():
            failed = trash / (time.strftime("%Y%m%d-%H%M%S") + f"-{n}-" + plugin_id)
            n += 1
        os.replace(destination, failed)
    if note.get("bundled"):
        restored = SHELL / "plugins" / plugin_id
    else:
        if not snapshot.is_dir():
            raise ValueError("The snapshot folder is missing")
        os.replace(snapshot, destination)
        restored = destination
    note_path.unlink(missing_ok=True)
    return {"id": plugin_id, "version": note.get("version", ""), "bundled": bool(note.get("bundled")),
            "failed": str(failed) if failed else "", "loadDir": load_dir(plugin_id, restored, home)}


def retire(home=None):
    """the old stand-alone Community Store plugin: its job is angelOS's own now. Its folder goes
    with its snapshots (nothing is deleted), its settings stay in settings.json"""
    out = []
    for plugin_id in RETIRED:
        folder = _home(home) / ".config/angelos/plugins" / plugin_id
        if folder.is_dir() and not folder.is_symlink():
            target = _stamp_dir(_snapshots(plugin_id, home))
            version = ""
            try:
                version = json.loads((folder / "manifest.json").read_text(encoding="utf-8")).get("version", "")
            except (OSError, ValueError, AttributeError):
                pass
            (target.parent / (target.name + ".json")).write_text(
                json.dumps({"reason": "retired: built into angelOS", "version": str(version)}), encoding="utf-8")
            os.replace(folder, target)
            out.append({"id": plugin_id, "moved": str(target)})
    return {"retired": out}


def main(args):
    if args == ["list"]:
        print(json.dumps({"plugins": catalog()}, ensure_ascii=False))
    elif len(args) == 3 and args[0] == "install":
        print(json.dumps(install(args[1], args[2]), ensure_ascii=False))
    elif len(args) == 4 and args[0] == "update":
        print(json.dumps(install(args[1], args[2], existing_version=args[3]), ensure_ascii=False))
    elif len(args) == 2 and args[0] == "rollback":
        print(json.dumps(rollback(args[1]), ensure_ascii=False))
    elif args == ["retire"]:
        print(json.dumps(retire(), ensure_ascii=False))
    else:
        raise ValueError("Usage: community-plugins.py list | install ID VERSION | update ID VERSION OLD_VERSION"
                         " | rollback ID | retire")


if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except (OSError, ValueError, zipfile.BadZipFile, urllib.error.URLError) as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
