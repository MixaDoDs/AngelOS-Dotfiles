"""Plugins from outside the registry (community-plugins.py sideload): a .zip, a GitHub link and
its updates, in a throw-away HOME; GitHub's API and downloads are stand-ins (no network)."""
import importlib.util, io, json, sys, tempfile, zipfile
from pathlib import Path

spec = importlib.util.spec_from_file_location("cp", Path(__file__).resolve().parents[2] / "scripts/community-plugins.py")
cp = importlib.util.module_from_spec(spec); spec.loader.exec_module(cp)
home = Path(tempfile.mkdtemp(prefix="angelos-sideload-"))
cp.load_dir = lambda i, d, h=None: str(d)          # no load links in the real ~/.cache


def zipped(files, top=""):
    b = io.BytesIO()
    with zipfile.ZipFile(b, "w") as z:
        for n, t in files.items():
            z.writestr(top + n, t)
    return b.getvalue()


man = lambda v: json.dumps({"id": "hello-zip", "name": "Hello", "version": v})
version = lambda: json.loads((home / ".config/angelos/plugins/hello-zip/manifest.json").read_text())["version"]
z = home / "p.zip"
z.write_bytes(zipped({"manifest.json": man("1.0"), "Main.qml": "Item {}"}))
r = cp.sideload(str(z), home)
assert r["id"] == "hello-zip" and not r["updated"], r
assert (home / ".config/angelos/plugins/hello-zip/Main.qml").is_file()
assert cp.sources(home)["hello-zip"]["kind"] == "zip"
# over it (a GitHub-style top folder this time): an update with a snapshot; rollback brings 1.0 back
z.write_bytes(zipped({"manifest.json": man("2.0")}, top="hello-zip-abc/"))
r = cp.sideload(str(z), home)
assert r["updated"] and r["snapshot"] and version() == "2.0", r
cp.rollback("hello-zip", home)
assert version() == "1.0"
# unsafe and broken archives are refused, the installed one stays
for bad in (zipped({"../evil": "x", "manifest.json": man("9")}), b"not a zip", zipped({"a/b/manifest.json": man("9")}),
            zipped({"manifest.json": json.dumps({"id": "../x", "name": "x", "version": "1"})})):
    z.write_bytes(bad)
    try:
        cp.sideload(str(z), home)
        raise SystemExit("accepted a bad archive")
    except (ValueError, zipfile.BadZipFile):
        pass
assert version() == "1.0" and not (home / ".config/angelos/evil").exists()

# GitHub links: the latest release's .zip asset, a repository without releases → its newest commit
def api(url, tag="v3"):
    if url.endswith("/releases/latest"):
        if "/norel" in url:
            raise cp.urllib.error.HTTPError(url, 404, "Not Found", {}, None)
        return {"tag_name": tag, "zipball_url": "https://api.github.com/repos/a/b/zipball/" + tag,
                "assets": [{"name": "p.zip", "browser_download_url": f"https://github.com/a/b/releases/download/{tag}/p.zip"}]}
    if url.endswith("/commits/main"):
        return {"sha": "0123456789abcdef0123"}
    return {"default_branch": "main"}


cp._api = api
assert cp.github_latest("https://github.com/a/b") == ("https://github.com/a/b/releases/download/v3/p.zip", "v3")
assert cp.github_latest("https://github.com/a/norel.git")[1] == "0123456789ab"
assert cp.github_latest("https://github.com/a/b/tree/dev")[1] == "dev"
for bad in ("https://github.com/a", "https://gitlab.com/a/b", "https://github.com/a/b/issues"):
    try:
        cp.github_latest(bad)
        raise SystemExit("took " + bad)
    except ValueError:
        pass
cp._download = lambda url, limit, timeout: zipped({"manifest.json": man("3.0")}, top="a-b-1/")
r = cp.sideload("https://github.com/a/b", home)
assert r["kind"] == "github" and r["ref"] == "v3" and version() == "3.0", r
assert not {x["id"]: x for x in cp.sideload_check(home)}["hello-zip"]["update"]
cp._api = lambda url: api(url, "v4")
row = {x["id"]: x for x in cp.sideload_check(home)}["hello-zip"]
assert row["update"] and row["latest"] == "v4", row
cp._download = lambda url, limit, timeout: zipped({"manifest.json": man("4.0")})
r = cp.sideload_update("hello-zip", home)
assert r["updated"] and version() == "4.0" and cp.sources(home)["hello-zip"]["ref"] == "v4"
# another plugin behind the same link is not an update of this one
cp._download = lambda url, limit, timeout: zipped({"manifest.json": json.dumps({"id": "other", "name": "O", "version": "1"})})
try:
    cp.sideload_update("hello-zip", home)
    raise SystemExit("updated into another plugin")
except ValueError:
    pass
print("sideload ok")
