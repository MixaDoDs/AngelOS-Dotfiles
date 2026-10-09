#!/usr/bin/env python3
"""A changed login-screen build input must trigger the next update."""
import importlib.util
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[2] / "scripts" / "sddm-theme.py"
spec = importlib.util.spec_from_file_location("sddm_theme", SCRIPT)
theme = importlib.util.module_from_spec(spec)
spec.loader.exec_module(theme)


class SourceStampTest(unittest.TestCase):
    def test_shader_font_and_rig_changes_invalidate_the_theme(self):
        self.assertTrue(hasattr(theme, "source_fingerprint"), "SDDM needs a build-input fingerprint")
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            font_dir = root / "user-fonts"
            paths = [
                root / "extras/sddm/angelos/Main.qml",
                root / "shaders/sddm_wall.frag.qsb",
                root / "data/fonts/Jacquard12Hell-Regular.ttf",
                root / "modules/y2k/sprites/angel/body.png",
                font_dir / "PixeloidSans.ttf",
                root / "scripts/sddm-theme.py",
            ]
            for path in paths:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(b"original")
            previous = theme.source_fingerprint(root, font_dir)
            for path in paths:
                path.write_bytes(b"changed")
                current = theme.source_fingerprint(root, font_dir)
                self.assertNotEqual(current, previous, path.name)
                previous = current


if __name__ == "__main__":
    unittest.main()
