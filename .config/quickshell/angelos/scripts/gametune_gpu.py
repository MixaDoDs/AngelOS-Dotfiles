"""The video card's series from its name, the same way for a ProtonDB report and for this machine
(scripts/protondb-digest.py groups the reports by it, scripts/game-tune.py looks its own up):
rtx50 rtx40 rtx30 rtx20 gtx16 gtx10 nvold | rdna4 rdna3 rdna2 rdna1 amdold apu deck | arc intel | other
"""
import re


def gpu_series(text):
    t = (text or "").lower()
    if "nvidia" in t or "geforce" in t or re.search(r"\b(rtx|gtx)\b", t):
        m = re.search(r"rtx\s*(?:a)?(\d)0\d0", t)
        if m:
            return {"5": "rtx50", "4": "rtx40", "3": "rtx30", "2": "rtx20"}.get(m.group(1), "nvold")
        if re.search(r"gtx\s*16\d0", t):
            return "gtx16"
        if re.search(r"gtx\s*10\d0", t):
            return "gtx10"
        return "nvold"
    if "custom gpu 0405" in t or "custom gpu 0932" in t or "vangogh" in t or "sephiroth" in t:
        return "deck"
    if "amd" in t or "radeon" in t or "radv" in t:
        m = re.search(r"rx\s*(\d)\d{3}", t)
        if m:
            return {"9": "rdna4", "7": "rdna3", "6": "rdna2", "5": "rdna1"}.get(m.group(1), "amdold")
        if re.search(r"navi\s*4\d|gfx12", t):
            return "rdna4"
        if re.search(r"navi\s*3\d|gfx11", t):
            return "rdna3"
        if re.search(r"navi\s*2\d|gfx103", t):
            return "rdna2"
        if re.search(r"\d{3}m\b|radeon graphics|vega \d+ graphics|renoir|cezanne|rembrandt|phoenix|raphael", t):
            return "apu"
        return "amdold"
    if "intel" in t:
        return "arc" if "arc" in t else "intel"
    return "other"


if __name__ == "__main__":
    cases = {"NVIDIA GeForce RTX 4060": "rtx40", "GeForce RTX 3070 Ti": "rtx30", "NVIDIA GeForce GTX 1660 SUPER": "gtx16",
             "NVIDIA GeForce GTX 1080": "gtx10", "AMD Radeon RX 9070 XT (radeonsi, gfx1201)": "rdna4",
             "AMD Radeon RX 6600 (radeonsi, navi23)": "rdna2", "AMD Custom GPU 0405 (radeonsi, vangogh)": "deck",
             "AMD Radeon 780M (radeonsi, gfx1103)": "rdna3", "AMD Radeon Graphics (radeonsi, renoir)": "apu",
             "Intel(R) Arc(tm) A770 Graphics (DG2)": "arc", "Mesa Intel(R) UHD Graphics 620": "intel",
             "NVIDIA GeForce RTX 5090": "rtx50", "GeForce RTX 2060": "rtx20"}
    for text, want in cases.items():
        assert gpu_series(text) == want, (text, gpu_series(text), want)
    print("ok")
