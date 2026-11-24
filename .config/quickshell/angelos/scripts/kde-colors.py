#!/usr/bin/env python3
"""The angelOS palette for KDE's apps (EasyEffects): the render hook "kde-colors" (templates.json).

Kirigami apps take their colours from a KDE colour scheme, not from qt6ct; with none they are
light Breeze whatever the theme. This turns qt6ct's colours (colors/angelos.conf, written by
qt-theme.py just before, when Qt apps are themed) into ~/.local/share/color-schemes/angelOS.colors
and points EasyEffects (~/.config/easyeffectsrc) at it. Nothing to do without EasyEffects or
without qt6ct's colours. After frostpix's pc-kit.

  kde-colors.py [PALETTE.json]      (the palette is not read: qt6ct's colours already are it)
"""

import configparser
import shutil
from pathlib import Path

HOME = Path.home()
SRC = HOME / ".config/qt6ct/colors/angelos.conf"
DST = HOME / ".local/share/color-schemes/angelOS.colors"
# QPalette roles in qt6ct's order
ROLES = ["WindowText", "Button", "Light", "Midlight", "Dark", "Mid", "Text", "BrightText",
         "ButtonText", "Base", "Window", "Shadow", "Highlight", "HighlightedText", "Link",
         "LinkVisited", "AlternateBase", "NoRole", "ToolTipBase", "ToolTipText",
         "PlaceholderText", "Accent"]


def rgb(h):
    h = h.strip().lstrip("#")[-6:]
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def s(c):
    return ",".join(map(str, c))


def main():
    flatpak = HOME / ".var/app/com.github.wwmm.easyeffects"
    if not SRC.is_file() or not (shutil.which("easyeffects") or flatpak.is_dir()):
        return
    cp = configparser.ConfigParser(interpolation=None)
    cp.read(SRC)
    act = dict(zip(ROLES, map(rgb, cp["ColorScheme"]["active_colors"].split(","))))
    dis = dict(zip(ROLES, map(rgb, cp["ColorScheme"]["disabled_colors"].split(","))))
    accent = act["Highlight"]
    neg, neu, pos = (237, 102, 120), (232, 180, 90), (110, 200, 140)

    def group(bg, alt, fg):
        return {
            "BackgroundNormal": s(bg), "BackgroundAlternate": s(alt),
            "ForegroundNormal": s(fg), "ForegroundInactive": s(act["PlaceholderText"]),
            "ForegroundActive": s(accent), "ForegroundLink": s(act["Link"]),
            "ForegroundVisited": s(act["LinkVisited"]), "ForegroundNegative": s(neg),
            "ForegroundNeutral": s(neu), "ForegroundPositive": s(pos),
            "DecorationFocus": s(accent), "DecorationHover": s(mix(accent, (255, 255, 255), .2)),
        }

    out = configparser.ConfigParser(interpolation=None)
    out.optionxform = str
    out["General"] = {"ColorScheme": "angelOS", "Name": "angelOS"}
    out["KDE"] = {"contrast": "4"}
    out["Colors:Window"] = group(act["Window"], act["AlternateBase"], act["WindowText"])
    out["Colors:View"] = group(act["Base"], act["AlternateBase"], act["Text"])
    out["Colors:Button"] = group(act["Button"], act["Midlight"], act["ButtonText"])
    out["Colors:Selection"] = group(accent, mix(accent, act["Base"], .3), act["HighlightedText"])
    out["Colors:Tooltip"] = group(act["ToolTipBase"], act["AlternateBase"], act["ToolTipText"])
    out["Colors:Complementary"] = group(act["Dark"], act["Window"], act["WindowText"])
    out["Colors:Header"] = group(act["Dark"], act["Window"], act["WindowText"])
    out["ColorEffects:Disabled"] = {"Color": s(dis["Text"]), "ColorAmount": "0", "ColorEffect": "0",
                                    "ContrastAmount": "0.65", "ContrastEffect": "1",
                                    "IntensityAmount": "0.1", "IntensityEffect": "2"}
    out["ColorEffects:Inactive"] = {"ChangeSelectionColor": "false", "Enable": "false"}
    out["WM"] = {"activeBackground": s(act["Dark"]), "activeForeground": s(act["WindowText"]),
                 "inactiveBackground": s(act["Window"]),
                 "inactiveForeground": s(act["PlaceholderText"])}
    DST.parent.mkdir(parents=True, exist_ok=True)
    with open(DST, "w") as f:
        out.write(f, space_around_delimiters=False)

    # where KColorSchemeManager (autosave) keeps the app's choice
    rc = HOME / ".config/easyeffectsrc"
    app = configparser.ConfigParser(interpolation=None, strict=False)
    app.optionxform = str
    app.read(rc)
    if app.get("UiSettings", "ColorScheme", fallback="") == "angelOS":
        return
    if not app.has_section("UiSettings"):
        app.add_section("UiSettings")
    app["UiSettings"]["ColorScheme"] = "angelOS"
    with open(rc, "w") as f:
        app.write(f, space_around_delimiters=False)


if __name__ == "__main__":
    main()
