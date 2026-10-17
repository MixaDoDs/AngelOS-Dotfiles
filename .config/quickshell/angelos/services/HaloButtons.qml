pragma Singleton

import QtQuick
import Quickshell
import qs.config

// The Halo's quick buttons (modules/halo, the «Buttons» page): what each one is, does and
// shows. Settings → Halo picks them and their order (Config.halo.buttons). kind: action (a
// press does it), toggle (on/off, `on`), field (a line to type: a timer, a note). Only what the
// sidebar doesn't have already: no second DND, mic, night light or volume here.
Singleton {
    id: root

    readonly property var catalog: [
        {
            "id": "pomodoro",
            "icon": "coffee",
            "ru": "Помодоро",
            "en": "Pomodoro",
            "wide": false,
            "kind": "toggle"
        },
        {
            "id": "timer",
            "icon": "clock",
            "ru": "Таймер",
            "en": "Timer",
            "wide": true,
            "kind": "field"
        },
        {
            "id": "record",
            "icon": "camera",
            "ru": "Запись",
            "en": "Record",
            "wide": false,
            "kind": "toggle"
        },
        {
            "id": "picker",
            "icon": "drop",
            "ru": "Пипетка",
            "en": "Color picker",
            "wide": false,
            "kind": "action"
        },
        {
            "id": "note",
            "icon": "note",
            "ru": "Заметка",
            "en": "Note",
            "wide": true,
            "kind": "field"
        }
    ]
    // the chosen ones, in the chosen order; ids nobody knows are skipped
    readonly property var list: (Config.halo.buttons || []).map(id => catalog.find(b => b.id === id)).filter(b => !!b)

    function byId(id) {
        return catalog.find(b => b.id === id) || null;
    }
    function label(b) {
        return I18n.t(b.ru, b.en);
    }
    function hint(id) {
        return id === "timer" ? I18n.t("25, 5m чай, помодоро 50/10", "25, 5m tea, pomodoro 50/10") : id === "note" ? I18n.t("заметка на полку…", "a note for the shelf…") : "";
    }

    function on(id) {
        return id === "record" ? Capture.recording : id === "pomodoro" ? Timers.items.some(t => t.kind === "pomodoro") : false;
    }

    function run(id) {
        switch (id) {
        // one pomodoro at a time: a second press stops it, so repeated presses don't stack
        // rounds that all ring at once
        case "pomodoro":
            if (on("pomodoro"))
                Timers.set(Timers.items.filter(t => t.kind !== "pomodoro"));
            else
                Timers.add(Timers.parse("помодоро"));
            break;
        case "record":
            if (Capture.recording)
                Capture.stopRecord();
            else
                Capture.record();
            break;
        case "picker":
            ColorPicker.pick();
            break;
        }
    }

    function submit(id, text) {
        const t = String(text || "").trim();
        if (!t)
            return false;
        if (id === "timer") {
            // only timers are typed here: a bare number is minutes
            const spec = Timers.parse(t, true);
            if (!spec)
                return false;
            Timers.add(spec);
            return true;
        }
        if (id === "note") {
            Shelf.addText(t, true);
            return true;
        }
        return false;
    }

    // the page's grid: [{b, row, col}], `cols` cells a row in the chosen order; a wide one that
    // doesn't fit the row's last cell lets the next small one fill it (no holes but the last)
    function pack(list, cols) {
        const out = [], rest = list.slice();
        let row = 0, col = 0;
        while (rest.length) {
            const i = rest.findIndex(b => (b.wide ? 2 : 1) <= cols - col);
            if (i < 0) {
                row++;
                col = 0;
                continue;
            }
            const b = rest.splice(i, 1)[0];
            out.push({
                "b": b,
                "row": row,
                "col": col
            });
            col += b.wide ? 2 : 1;
            if (col >= cols) {
                row++;
                col = 0;
            }
        }
        return out;
    }
}
