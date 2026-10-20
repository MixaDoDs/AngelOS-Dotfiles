pragma Singleton

import QtQuick
import Quickshell
import qs.config

// The looks of the pixel menus (widgets/PxMenu: the desktop's, a widget's, later the bar's, a
// task's, the tray's, the Halo's). One resolver says which look a menu wears (lookFor), one
// table holds each look's tokens: the frame, the title, the row highlight, the text, the line.
//   classic — the bevelled box as it always was (PxBox + PxMenuItem)
//   save    — «Сейв», the 2004 lock's memory card: a dark box, white outlined text, the accent
//             title bar, the selection a ► marker over a faint tint
//   sticker — «Наклейка», a page of a squared notebook: paper, a 4-pixel grid, a red margin, a
//             hard offset shadow, the selection a highlighter stripe
//   y2k     — the desktop's Y2K gloss bubble (Config.desktop.menuStyle "y2k"): desktop and widget
//             menus only
// Each has a hell recolour (Theme.hell: the desktop is in hell while the demon rules).
// Everything is pixel-hard: no soft gradients, no blurred shadows (y2k is its own old thing).
Singleton {
    id: root

    readonly property var looks: ["classic", "save", "sticker"]
    // menus that may wear their own look (Config.menus.per; "" = as all)
    readonly property var kinds: ["desktop", "widget", "panel", "task", "tray", "halo"]
    function lookLabel(l) {
        return ({
                "classic": I18n.t("Как сейчас", "Classic"),
                "save": I18n.t("Сейв", "Save"),
                "sticker": I18n.t("Наклейка", "Sticker")
            })[l] || l;
    }

    // the one place a menu's look is decided: its own (Config.menus.per[kind]), else the look
    // for all (Config.menus.look), else classic. The desktop's Y2K gloss stays its own.
    readonly property var cfg: Config.menus !== undefined ? Config.menus : null
    function lookFor(kind) {
        if ((kind === "desktop" || kind === "widget") && DeskMenu.style === "y2k")
            return "y2k";
        const per = cfg && cfg.per ? cfg.per : {};
        const own = per[kind] || "";
        if (looks.includes(own))
            return own;
        const all = cfg ? cfg.look : "";
        return looks.includes(all) ? all : "classic";
    }

    // one width for every menu (art pixels × Theme.u): narrower ones grow, wider labels elide
    readonly property int minWidth: Theme.u * 120
    readonly property int maxWidth: Theme.u * 230

    // a shortcut in one format: ["Mod", "T"] or "Mod + T" → "Mod+T"
    function keyText(keys) {
        if (!keys)
            return "";
        const parts = typeof keys === "string" ? keys.split("+") : Array.from(keys);
        return parts.map(s => String(s).trim()).filter(s => s !== "").join("+");
    }
    // an entry's submenu: `children` (or the desktop lists' older `flyout`), a list or a
    // function that builds it as it opens
    function hasKids(it) {
        if (!it)
            return false;
        const c = it.children !== undefined ? it.children : it.flyout;
        return typeof c === "function" || (!!c && typeof c === "object" && c.length > 0);
    }
    function kidsOf(it) {
        if (!it)
            return [];
        const c = it.children !== undefined ? it.children : it.flyout;
        // a list that went through a model comes back as a sequence, not an Array
        const l = typeof c === "function" ? c() : c;
        return !!l && typeof l === "object" && l.length > 0 ? Array.from(l) : [];
    }
    function on(v, dflt) {
        return typeof v === "function" ? v() !== false : v === undefined ? dflt : v !== false;
    }

    // the tokens of the look a menu item stands in: the nearest parent with `menuTokens`
    // (PxMenuList), classic outside any (the bar's own menus as they are)
    function tokensFor(item) {
        for (let p = item; p; p = p.parent)
            if (p.menuTokens !== undefined && p.menuTokens !== null)
                return p.menuTokens;
        return plain;
    }
    function tokens(look) {
        return look === "save" ? save : look === "sticker" ? sticker : look === "y2k" ? y2k : classic;
    }

    // a tile of the notebook's squares: a line on its top and left edge, `cell` pixels apart
    function gridTile(cell, color) {
        const c = Theme.hex(color);
        return "data:image/svg+xml;utf8," + encodeURIComponent("<svg xmlns='http://www.w3.org/2000/svg' width='" + cell + "' height='" + cell + "' shape-rendering='crispEdges'><rect x='0' y='0' width='" + cell + "' height='1' fill='" + c + "'/><rect x='0' y='0' width='1' height='" + cell + "' fill='" + c + "'/></svg>");
    }

    readonly property bool hell: Theme.hell
    // tokens: frame (face, edge, hi, lo, flat, outline, hellBox, shadow, shadowColor, shadowU),
    // paper (grid colour or "", gridCell, margin colour or ""), title (head: plain | bar | ink,
    // headBg, headText, caps, badge), rows (pad in art px, text, dim, ink for icons, outlineText:
    // the text's 1-pixel outline or "transparent", lit, litText, litInk, marker: fill | arrow |
    // stripe, markerColor),
    // lines (sepLo, sepHi), tiles (tileBg, tileEdge, tileBevel)
    // classic in hell: hell's obsidian box (PxBox.hell), a blood-red highlight
    readonly property var classicHell: ({
            "name": "classic",
            "face": Theme.hellPanel,
            "edge": Theme.hellEdge,
            "hi": Theme.hellHi,
            "lo": Theme.hellLo,
            "flat": false,
            "outline": true,
            "hellBox": true,
            "shadow": true,
            "shadowColor": Qt.alpha(Theme.shadow, Theme.shadowAlpha),
            "shadowU": 2,
            "grid": "",
            "margin": "",
            "head": "plain",
            "headBg": "transparent",
            "headText": Theme.hellTextDim,
            "caps": false,
            "badge": "",
            "pad": 5,
            "text": Theme.hellText,
            "dim": Theme.hellTextDim,
            "ink": Theme.hellText,
            "outlineText": "transparent",
            "lit": Theme.hellBlood,
            "litText": Theme.hellText,
            "litInk": Theme.hellText,
            "marker": "fill",
            "markerColor": Theme.hellBlood,
            "sepLo": Theme.hellLo,
            "sepHi": Theme.hellHi,
            "tileBg": Theme.mix(Theme.hellFace, Theme.hellBlood, 0.3),
            "tileEdge": Theme.hellEdge,
            "tileBevel": true
        })
    // classic as it always was; also what a PxMenuItem outside any PxMenu wears (the bar's
    // own menus, Start), in hell too: its box is not this engine's
    readonly property var plain: ({
            "name": "classic",
            "face": Qt.alpha(Theme.menuSurface, Theme.panelAlpha),
            "edge": Theme.edge,
            "hi": Theme.hi,
            "lo": Theme.lo,
            "flat": Theme.zine,
            "outline": true,
            "hellBox": false,
            "shadow": true,
            "shadowColor": Qt.alpha(Theme.shadow, Theme.shadowAlpha),
            "shadowU": 2,
            "grid": "",
            "margin": "",
            "head": "plain",
            "headBg": "transparent",
            "headText": Theme.textDim,
            "caps": false,
            "badge": "",
            "pad": 5,
            "text": Theme.text,
            "dim": Theme.textDim,
            "ink": Theme.dark ? Theme.text : Theme.edge,
            "outlineText": "transparent",
            "lit": Theme.select,
            "litText": Theme.selectText,
            "litInk": Theme.selectText,
            "marker": "fill",
            "markerColor": Theme.select,
            "sepLo": Theme.lo,
            "sepHi": Theme.hi,
            "tileBg": Theme.mix(Theme.face, Theme.accent, 0.18),
            "tileEdge": Theme.edge,
            "tileBevel": true
        })
    readonly property var classic: hell ? classicHell : plain

    // «Сейв»: dark whatever the theme (white text needs it); by day the theme's ink is the box
    readonly property color saveBox: hell ? Theme.hellFace : Theme.dark ? Theme.mix(Theme.face, Theme.accent, 0.06) : Theme.mix(Theme.edge, Theme.accent, 0.14)
    readonly property var save: ({
            "name": "save",
            "face": saveBox,
            "edge": hell ? Theme.hellEdge : Theme.mix(saveBox, "#000000", 0.6),
            "hi": hell ? Theme.hellEdge : Theme.mix(saveBox, "#000000", 0.6),
            "lo": hell ? Theme.hellEdge : Theme.mix(saveBox, "#000000", 0.6),
            "flat": true,
            "outline": true,
            "hellBox": false,
            "shadow": true,
            "shadowColor": Qt.alpha(Theme.shadow, Math.max(0.55, Theme.shadowAlpha)),
            "shadowU": 2,
            "grid": "",
            "margin": "",
            "head": "bar",
            "headBg": hell ? Theme.hellBlood : Theme.accent,
            "headText": hell ? Theme.hellText : Theme.inkOn(Theme.accent),
            "caps": true,
            "badge": "2004",
            "pad": 8,
            "text": hell ? Theme.hellText : "#ffffff",
            "dim": hell ? Theme.hellTextDim : Theme.mix("#ffffff", saveBox, 0.42),
            "ink": hell ? Theme.hellText : Theme.mix("#ffffff", saveBox, 0.1),
            "outlineText": Theme.mix(saveBox, "#000000", 0.7),
            "lit": hell ? Theme.mix(saveBox, Theme.hellEmber, 0.2) : Theme.mix(saveBox, "#ffffff", 0.09),
            "litText": hell ? Theme.hellText : "#ffffff",
            "litInk": hell ? Theme.hellText : Theme.mix("#ffffff", saveBox, 0.1),
            "marker": "arrow",
            "markerColor": hell ? Theme.hellFlame : "#ffcf4a",
            "sepLo": Theme.mix(saveBox, "#000000", 0.5),
            "sepHi": Theme.mix(saveBox, "#ffffff", 0.1),
            "tileBg": hell ? Theme.mix(saveBox, Theme.hellEmber, 0.2) : Theme.mix(saveBox, "#ffffff", 0.09),
            "tileEdge": hell ? Theme.hellFlame : Theme.accent,
            "tileBevel": false
        })

    // «Наклейка»: paper by day and by night; in hell a scorched parchment
    readonly property color stickerPaper: hell ? Theme.mix("#d9c39a", Theme.hellBlood, 0.14) : Theme.mix("#f7f4ea", Theme.accent2, 0.04)
    readonly property color stickerInk: hell ? Theme.mix(Theme.hellBody, "#000000", 0.4) : "#1f2440"
    readonly property color stickerLine: hell ? Theme.hellBlood : "#5a8fd8"
    readonly property var sticker: ({
            "name": "sticker",
            "face": stickerPaper,
            "edge": Theme.mix(stickerInk, stickerLine, 0.35),
            "hi": Theme.mix(stickerInk, stickerLine, 0.35),
            "lo": Theme.mix(stickerInk, stickerLine, 0.35),
            "flat": true,
            "outline": true,
            "hellBox": false,
            "shadow": true,
            "shadowColor": Qt.alpha(stickerInk, 0.85),
            "shadowU": 2,
            "grid": Theme.mix(stickerPaper, stickerLine, 0.2),
            "gridCell": 4,
            "margin": hell ? Theme.hellBlood : Theme.mix("#e0475e", stickerPaper, 0.2),
            "head": "ink",
            "headBg": "transparent",
            "headText": stickerInk,
            "caps": false,
            "badge": "",
            "pad": 5,
            "text": stickerInk,
            "dim": Theme.mix(stickerInk, stickerPaper, 0.45),
            "ink": stickerInk,
            "outlineText": "transparent",
            "lit": hell ? Theme.mix(stickerPaper, Theme.hellEmber, 0.6) : Theme.mix("#ffe45c", Theme.accent, 0.08),
            "litText": stickerInk,
            "litInk": stickerInk,
            "marker": "stripe",
            "markerColor": hell ? Theme.hellEmber : "#ffe45c",
            "sepLo": Theme.mix(stickerLine, stickerInk, 0.3),
            "sepHi": "transparent",
            "tileBg": hell ? Theme.mix(stickerPaper, Theme.hellEmber, 0.6) : Theme.mix("#ffe45c", Theme.accent, 0.08),
            "tileEdge": stickerInk,
            "tileBevel": false
        })

    // the desktop's Y2K gloss: the chrome bubble (Y2kGloss) and PxMenuItem's own "y2k" rows
    readonly property var y2k: Object.assign({}, plain, {
            "name": "y2k",
            "y2k": true,
            "face": "transparent",
            "flat": true,
            "outline": false,
            "shadow": false
        })
}
