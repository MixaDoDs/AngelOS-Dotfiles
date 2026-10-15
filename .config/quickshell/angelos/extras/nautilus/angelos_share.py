"""angelOS for Nautilus: «Отправить рядом» — Quick Share to LocalSend devices nearby.

Opens angelOS's share sheet (services/QuickShare) with the selected files and folders;
the paths go to `angelos share` as arguments, never through a shell.
"""
import os
import subprocess
from typing import List
from urllib.parse import unquote

from gi.repository import GObject, Nautilus

SHELL_DIR = os.path.join(os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config"), "quickshell/angelos")
ANGELOS = os.path.join(SHELL_DIR, "bin/angelos")


class AngelosShare(GObject.GObject, Nautilus.MenuProvider):
    @staticmethod
    def path(file):
        uri = file.get_uri()
        return unquote(uri[7:]) if uri.startswith("file://") else ""

    def run(self, _menu, files):
        paths = [p for p in (self.path(f) for f in files) if p]
        if paths:
            subprocess.Popen([ANGELOS, "share", *paths], start_new_session=True,
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    def get_file_items(self, files: List[Nautilus.FileInfo]):
        if not files or any(f.get_uri_scheme() != "file" for f in files):
            return []
        item = Nautilus.MenuItem(name="AngelosShare::send", label="Отправить рядом (LocalSend)", icon="send-to-symbolic")
        item.connect("activate", self.run, files)
        return [item]
