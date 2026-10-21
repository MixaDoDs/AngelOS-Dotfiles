"""A rejected key switch reports the selector that remains in front."""
import json
import os
from pathlib import Path
import subprocess
import tempfile


script = Path(__file__).resolve().parents[2] / "scripts/keyprofile.py"
with tempfile.TemporaryDirectory(prefix="aos-keyprofile-test-") as tmp:
    home = Path(tmp) / "home"
    cfg = home / ".config/niri/cfg"
    cfg.mkdir(parents=True)
    (cfg.parent / "config.kdl").write_text('include "cfg/keybinds.kdl"\n')
    (cfg / "keybinds.kdl").write_text('include "keybinds-common.kdl"\ninclude "keybinds-pixel.kdl"\n')
    bin_dir = Path(tmp) / "bin"
    bin_dir.mkdir()
    niri = bin_dir / "niri"
    niri.write_text("#!/bin/sh\nexit 1\n")
    niri.chmod(0o755)
    env = dict(os.environ, HOME=str(home), PATH=str(bin_dir) + ":" + os.environ["PATH"])
    result = subprocess.run(["python3", str(script), "apply", "macos"], env=env, capture_output=True, text=True)
    response = json.loads(result.stdout)
    assert result.returncode == 1 and response["error"] and response["profile"] == "pixel", response
    assert "keybinds-pixel.kdl" in (cfg / "keybinds.kdl").read_text()
    (cfg / "keybinds.kdl").write_text('include "keybinds-common.kdl"\ninclude "keybinds-macos.kdl"\n')
    result = subprocess.run(["python3", str(script), "apply", "pixel"], env=env, capture_output=True, text=True)
    response = json.loads(result.stdout)
    assert result.returncode == 1 and response["error"] and response["profile"] == "macos", response
    assert "keybinds-macos.kdl" in (cfg / "keybinds.kdl").read_text()
    # the first switch (no selector yet): the staged copy passes, the real config is refused
    (cfg / "keybinds.kdl").unlink()
    niri.write_text('#!/bin/sh\ncase "$3" in *angelos-keyprofile-*) exit 0;; esac\nexit 1\n')
    result = subprocess.run(["python3", str(script), "apply", "macos"], env=env, capture_output=True, text=True)
    response = json.loads(result.stdout)
    assert result.returncode == 1 and response["error"] and response["profile"] != "macos", response
    assert not (cfg / "keybinds.kdl").exists()
print("TEST keyprofile-refused-keeps-pixel PASS")
