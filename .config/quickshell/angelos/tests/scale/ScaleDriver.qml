pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.modules.settings
import qs.modules.bar
import qs.modules.bar.parts
import qs.modules.notifications
import qs.widgets

// The scale matrix (tests/scale/run.sh): Settings pages, the Start looks, the bar's widgets
// in a bar of the shell's height and a notification card, laid out at every art pixel and
// font scale of the matrix on a 1280×720 screen. Against px 2 / fonts ×1 (as shipped), no
// new text may run over other text or an icon, out of its own box, or past the window.
// Prints "TEST <name> PASS|FAIL [detail]", offenders as "SCALE …", then "TEST DONE <failures>".
Scope {
    id: root

    property int failures: 0
    function report(name, ok, detail) {
        if (!ok)
            failures++;
        console.log("TEST " + name + " " + (ok ? "PASS" : "FAIL") + (detail ? " " + detail : ""));
    }

    // art pixel, font scale: the first is the reference
    readonly property var allCombos: [[2, 1], [2, 2], [1, 1], [4, 1], [3, 1.5], [4, 2]]
    // ANGELOS_SCALE_ONLY="1 2": the reference and those of the rest (run.sh runs a few at once)
    readonly property var combos: {
        const only = (Quickshell.env("ANGELOS_SCALE_ONLY") || "").trim();
        return only ? [allCombos[0]].concat(only.split(/\s+/).map(i => allCombos[Number(i)])) : allCombos;
    }
    readonly property var surfaces: ["settings:home", "settings:appearance", "settings:updates", "settings:monitor", "settings:notifications", "settings:bar", "start:win11", "start:classic", "start:windose", "start:spotlight", "bar", "notification"]

    FloatingWindow {
        id: win
        implicitWidth: 1280
        implicitHeight: 720
        title: "angelOS scale test"
        color: Theme.desk
        Loader {
            id: stage
            anchors.fill: parent
            property string what: ""
            sourceComponent: what.startsWith("settings") ? settingsC : what === "start:win11" ? win11C : what === "start:classic" ? classicC : what === "start:windose" ? windoseC : what === "start:spotlight" ? spotC : what === "bar" ? barC : what === "notification" ? notifC : null
        }
    }
    Component {
        id: settingsC
        SettingsView {
            hostWindow: win
        }
    }
    Component {
        id: win11C
        Item {
            StartWin11 {
                anchors.bottom: parent.bottom
                room: parent.height - Theme.u * 4
            }
        }
    }
    Component {
        id: classicC
        Item {
            StartMenuBody {
                anchors.bottom: parent.bottom
                room: parent.height - Theme.u * 4
            }
        }
    }
    Component {
        id: windoseC
        Item {
            StartWindose {
                anchors.bottom: parent.bottom
                room: parent.height - Theme.u * 4
            }
        }
    }
    Component {
        id: spotC
        Item {
            StartSpotlight {
                y: Math.round(parent.height * 0.2)
                anchors.horizontalCenter: parent.horizontalCenter
                room: parent.height * 0.75
            }
        }
    }
    // the taskbar's right side in a bar as tall as the shell's own (Theme.barHeight)
    Component {
        id: barC
        Item {
            Rectangle {
                objectName: "box"
                anchors.bottom: parent.bottom
                width: parent.width
                height: Theme.barHeight
                color: Theme.face
                clip: true
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.u * 4
                    height: parent.height
                    spacing: Theme.u * 2
                    StartButton {
                        anchors.verticalCenter: parent.verticalCenter
                        screenName: "TEST-1"
                    }
                    KbLayout {
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Bell {
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Volume {
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Clock {
                        anchors.verticalCenter: parent.verticalCenter
                        screenName: "TEST-1"
                    }
                }
            }
        }
    }
    Component {
        id: notifC
        Item {
            NotificationCard {
                x: parent.width - width - Theme.u * 4
                y: Theme.u * 4
                width: Theme.u * 175 - Theme.u * 3
                notification: ({
                        "id": 1,
                        "appName": "angelOS",
                        "summary": "Привет, это тест ♡",
                        "body": "Уведомление в стиле NGO: пиксели, розовый и сердечки. Клик — закрыть.",
                        "actions": [
                            {
                                "text": "Ответить",
                                "identifier": "reply",
                                "invoke": () => {}
                            }
                        ],
                        "urgency": 1,
                        "expireTimeout": -1,
                        "image": "",
                        "appIcon": "kitty",
                        "desktopEntry": "",
                        "tracked": false
                    })
            }
        }
    }

    // ---- what is drawn where ----
    function typeName(it) {
        return String(it).replace(/\(.*$/, "").replace(/_QML(TYPE)?_[0-9]+$/, "").replace(/_QMLTYPE_[0-9]+/, "");
    }
    function isText(it) {
        return typeof it.text === "string" && it.font !== undefined && it.contentHeight !== undefined && it.text.trim() !== "";
    }
    function isImage(it) {
        return it.sourceSize !== undefined && it.status !== undefined && it.paintedWidth !== undefined && it.width > 0 && it.height > 0;
    }
    // every visible text and image: its painted rectangle in the window, clipped by clipping
    // ancestors; "box" = the rectangle of the item itself (overflow: the text paints past it)
    function collect(top) {
        const out = [];
        const walk = (it, path, clipRect, scrolled) => {
            if (!it || !it.visible || it.opacity < 0.05)
                return;
            let p;
            try {
                p = it.mapToItem(win.contentItem, 0, 0);
            } catch (e) {
                return;
            }
            // a rectangle of the item (its own coordinates) as it lands in the window, rotations too
            const place = (x, y, w, h) => {
                const c = [it.mapToItem(win.contentItem, x, y), it.mapToItem(win.contentItem, x + w, y), it.mapToItem(win.contentItem, x, y + h), it.mapToItem(win.contentItem, x + w, y + h)];
                const xs = c.map(q => q.x), ys = c.map(q => q.y);
                const x0 = Math.min.apply(null, xs), y0 = Math.min.apply(null, ys);
                return [x0, y0, Math.max.apply(null, xs) - x0, Math.max.apply(null, ys) - y0];
            };
            let rect = clipRect;
            if (it.clip)
                rect = inter(rect, place(0, 0, it.width, it.height));
            // inside something that scrolls, a line half out of view is just scrolled
            const scrolls = scrolled || it.contentY !== undefined;
            if (isText(it)) {
                const cw = Math.min(it.contentWidth, it.width > 0 ? it.width : it.contentWidth), ch = it.contentHeight;
                const ox = it.horizontalAlignment === Text.AlignRight ? it.width - cw : it.horizontalAlignment === Text.AlignHCenter ? (it.width - cw) / 2 : 0;
                const oy = it.verticalAlignment === Text.AlignBottom ? it.height - ch : it.verticalAlignment === Text.AlignVCenter ? (it.height - ch) / 2 : 0;
                const painted = place(ox, oy, cw, ch);
                out.push({
                    "kind": "text",
                    "path": path,
                    "text": it.text.slice(0, 24),
                    "rect": inter(painted, rect),
                    "full": painted,
                    "box": place(0, 0, it.width, it.height),
                    "scrolled": scrolls
                });
            } else if (isImage(it)) {
                out.push({
                    "kind": "image",
                    "path": path,
                    "text": "",
                    "rect": inter(place(0, 0, it.width, it.height), rect),
                    "full": place(0, 0, it.width, it.height)
                });
            }
            const kids = it.children || [];
            for (let i = 0; i < kids.length; i++)
                walk(kids[i], path + "/" + typeName(kids[i]) + i, rect, scrolls);
        };
        walk(top, typeName(top), [0, 0, win.width, win.height], false);
        return out;
    }
    function inter(a, b) {
        const x = Math.max(a[0], b[0]), y = Math.max(a[1], b[1]);
        const r = Math.min(a[0] + a[2], b[0] + b[2]), btm = Math.min(a[1] + a[3], b[1] + b[3]);
        return [x, y, Math.max(0, r - x), Math.max(0, btm - y)];
    }
    function area(r) {
        return r[2] * r[3];
    }
    // the problems in a surface: a key each (stable across scales: the item paths)
    function problems(top) {
        const items = collect(top);
        const found = {};
        const texts = items.filter(x => x.kind === "text" && area(x.rect) > 0);
        for (const t of texts) {
            // the text paints past the window (cut off), or past its own box by more than a
            // pixel of the art (it runs into whatever lies there)
            // cut off: by the window or a box; inside something that scrolls only sideways
            // (a line half out of view vertically is just scrolled)
            const cutW = t.rect[2] < t.full[2] * 0.9, cutH = t.rect[3] < t.full[3] * 0.9;
            if (t.rect[3] > 0 && (t.scrolled ? cutW : cutW || cutH))
                found["cut " + t.path] = "cut: «" + t.text + "»";
            const over = Math.max(t.full[3] - t.box[3], t.full[2] - t.box[2]);
            if (over > Theme.u + 1 && t.box[3] > 0)
                found["over " + t.path] = "taller than its box by " + Math.round(over) + " px: «" + t.text + "»";
        }
        for (let i = 0; i < texts.length; i++) {
            const a = texts[i];
            for (const b of items) {
                if (b === a || area(b.rect) <= 0 || (b.kind === "text" && items.indexOf(b) < items.indexOf(a)))
                    continue;
                if (b.path.startsWith(a.path + "/") || a.path.startsWith(b.path + "/"))
                    continue;
                if (b.kind === "text" && b.text === a.text)
                    continue;          // a shadow or an outline drawn as a second copy
                const r = inter(a.rect, b.rect);
                if (r[2] > Theme.u && r[3] > Theme.u && area(r) > 0.15 * Math.min(area(a.rect), area(b.rect)))
                    found["overlap " + a.path + " " + b.path] = "«" + a.text + "» over " + (b.kind === "text" ? "«" + b.text + "»" : "an image");
            }
        }
        return found;
    }

    // ---- the run: per combo, per surface: set, wait for the layout, look ----
    property int ci: 0
    property int si: 0
    property int ticks: 0
    property var baseline: ({})
    property var bad: []
    function setCombo(c) {
        Config.appearance.px = c[0];
        Config.appearance.fontScale = c[1];
    }
    Timer {
        interval: 120
        running: Config.ready
        repeat: true
        onTriggered: {
            const c = root.combos[root.ci];
            const what = root.surfaces[root.si];
            if (root.ticks === 0) {
                root.setCombo(c);
                stage.what = what;
                if (what.startsWith("settings:"))
                    Shell.settingsPage = what.slice(9);
            }
            root.ticks++;
            if (root.ticks < 6 || stage.status !== Loader.Ready)
                return;
            const key = what;
            const found = root.problems(stage.item);
            if (root.ci === 0) {
                root.baseline[key] = found;
            } else {
                const base = root.baseline[key] || {};
                for (const k in found)
                    if (!(k in base)) {
                        root.bad.push("px " + c[0] + " ×" + c[1] + " " + what + ": " + found[k]);
                        console.log("SCALE px" + c[0] + " fs" + c[1] + " " + what + " " + found[k] + "   [" + k.slice(0, 160) + "]");
                    }
            }
            root.ticks = 0;
            stage.what = "";
            if (++root.si >= root.surfaces.length) {
                root.si = 0;
                if (root.ci > 0) {
                    const mine = root.bad.filter(b => b.startsWith("px " + c[0] + " ×" + c[1] + " "));
                    root.report("scale-px" + c[0] + "-fs" + c[1], mine.length === 0, mine.length ? mine.length + " new: " + mine.slice(0, 3).join("; ") : root.surfaces.length + " surfaces as at px 2 ×1");
                } else {
                    let n = 0;
                    for (const k in root.baseline)
                        n += Object.keys(root.baseline[k]).length;
                    console.log("SCALE baseline: " + n + " known overlaps at px 2 ×1");
                }
                if (++root.ci >= root.combos.length) {
                    stop();
                    root.setCombo(root.combos[0]);
                    console.log("TEST DONE " + root.failures);
                    Qt.callLater(Qt.quit);
                }
            }
        }
    }
    Timer {
        interval: 200000
        running: true
        onTriggered: {
            root.report("timeout", false, "combo " + root.ci + " surface " + root.si);
            console.log("TEST DONE " + root.failures);
            Qt.quit();
        }
    }
}
