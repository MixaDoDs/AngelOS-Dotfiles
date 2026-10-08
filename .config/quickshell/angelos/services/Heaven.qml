pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Heaven's things (рай): the looks and effects the game hands out bit by bit — each one is
// the reward of an achievement (story/achievements.json → "reward", services/Achievements).
// Everything that shows or applies one of them asks has(id) and nothing else, so no other
// path can open a locked thing or lock an open one:
//   the game off ("Just the desktop")  everything here is open — no angel, nothing to earn
//   the game on                        open once its achievement is earned; locked again when
//                                      the game is turned back on after "Just the desktop"
//   no achievement gives it            open (nothing to earn it by: an admin took it off)
// A locked pick is kept as it is in settings.json (the harp stays chosen): the shell shows
// the usual thing instead until it is earned, then the pick comes back by itself.
// Besides the looks, things (story/items.json → `things`): an object that lies in the
// achievement's card and opens something in the system (the Angel's diary, services/Diary).
Singleton {
    id: root

    // id → what it is; `page`: the settings page it is picked on
    readonly property var looks: [
        {
            "id": "fx.sparkles",
            "ru": "Шлейф блёсток",
            "en": "The sparkle trail",
            "icon": "sparkle",
            "page": "cursor"
        },
        {
            "id": "look.mini",
            "ru": "Ангел: малышка 20×21",
            "en": "Angel: the 20×21 mini",
            "icon": "heart",
            "page": "y2k"
        },
        {
            "id": "look.chibi",
            "ru": "Ангел: чиби",
            "en": "Angel: chibi",
            "icon": "heart",
            "page": "y2k"
        },
        {
            "id": "menu.wings",
            "ru": "Меню «Крылья»",
            "en": "The Wings menu",
            "icon": "sparkleStar",
            "page": "deskmenu"
        },
        {
            "id": "cursor.glitter",
            "ru": "Курсор angelOS Glitter",
            "en": "The angelOS Glitter cursor",
            "icon": "cursor",
            "page": "cursor"
        },
        {
            "id": "fx.rays",
            "ru": "Лучи и хор ангела",
            "en": "The angel's rays and choir",
            "icon": "sun",
            "page": "y2k"
        },
        {
            "id": "look.adult",
            "ru": "Ангел: взрослая 30×40",
            "en": "Angel: the adult 30×40",
            "icon": "heart",
            "page": "y2k"
        },
        {
            "id": "menu.harp",
            "ru": "Меню «Арфа»",
            "en": "The Harp menu",
            "icon": "music",
            "page": "deskmenu"
        }
    ]
    // the things: {id, ru, en, desc, opens, texture: {ru, en, palette, rows}, textureId, textures}
    property var thingsDoc: ({})
    readonly property var things: (Array.isArray(thingsDoc.things) ? thingsDoc.things : []).filter(t => t && typeof t.id === "string" && t.id).map(t => {
            const textures = t.textures && typeof t.textures === "object" ? t.textures : {};
            const pick = textures[t.texture] ? t.texture : Object.keys(textures)[0] || "";
            return Object.assign({}, t, {
                "kind": "thing",
                "icon": t.icon || "sparkleStar",
                "textureId": pick,
                "textures": textures,
                "texture": textures[pick] || null
            });
        })
    readonly property var items: looks.concat(things)
    readonly property var ids: items.map(i => i.id)
    function item(id) {
        return items.find(i => i.id === id) || null;
    }
    function label(id) {
        const i = item(id);
        return i ? I18n.t(i.ru, i.en) : id;
    }
    function thing(id) {
        return things.find(t => t.id === id) || null;
    }
    // the thing that opens this ("diary"), "" when none does
    function thingFor(opens) {
        const t = things.find(x => x.opens === opens);
        return t ? t.id : "";
    }
    // use a thing: what it opens (the achievement's card, Settings → Achievements → Things)
    function use(id) {
        const t = thing(id);
        if (!t || !has(id))
            return false;
        const o = String(t.opens || "");
        if (o === "diary")
            Diary.open();
        else if (o.startsWith("settings:"))
            Shell.openSettings(o.slice(9));
        else if (o === "novel")
            Shell.openSettings("novel");
        else
            return false;
        return true;
    }

    // story/items.json (the author edits it on the owner's diary page, «Publish» ships it)
    readonly property string thingsFile: Quickshell.shellDir + "/story/items.json"
    property bool thingsLoaded: false
    AsyncFile {
        id: thingsView
        path: root.thingsFile
        watchChanges: true
        blockLoading: true
        printErrors: false
        onFileChanged: reloadSoon()
        onLoaded: {
            try {
                root.thingsDoc = JSON.parse(text());
            } catch (e) {
                console.warn("story/items.json: " + e);
            }
            root.thingsLoaded = true;
        }
        onLoadFailed: root.thingsLoaded = true
    }
    // the author's pick of a thing's picture (the owner's page)
    function setTexture(id, texture) {
        const d = JSON.parse(JSON.stringify(thingsDoc));
        const t = (d.things || []).find(x => x.id === id);
        if (!t || !(t.textures || {})[texture])
            return false;
        t.texture = texture;
        thingsView.write(JSON.stringify(d, null, 2) + "\n");
        thingsDoc = d;
        return true;
    }

    // the game is off: all of heaven is open
    readonly property bool allOpen: Config.ready && !Story.enabled
    // the save is read: until then nothing on screen changes either way
    readonly property bool ready: Config.ready && (!Story.enabled || (Story.ready && Achievements.loaded))
    function has(id) {
        if (!Story.enabled || !ready)
            return true;
        if (!ids.includes(id))
            return true;
        if (Achievements.itemEarned(id))
            return true;
        return !Achievements.giverOf(id);
    }
    // what opens it, for the settings: "" when it is open
    function lockHint(id) {
        if (has(id))
            return "";
        const a = Achievements.giverOf(id);
        if (!a)
            return "";
        return a.secret ? I18n.t("откроется за тайное достижение", "opens with a secret achievement") : I18n.t("откроется за достижение «", "opens with the achievement “") + Achievements.nameOf(a) + I18n.t("»", "”");
    }

    // the menu looks and the angel's looks behind the ids
    function menuItem(style) {
        return style === "wings" ? "menu.wings" : style === "harp" ? "menu.harp" : "";
    }
    function menuOk(style) {
        const i = menuItem(style);
        return !i || has(i);
    }
    function lookItem(look) {
        return look === "mini" || look === "chibi" || look === "adult" ? "look." + look : "";
    }
    function lookOk(look) {
        const i = lookItem(look);
        return !i || has(i);
    }
}
