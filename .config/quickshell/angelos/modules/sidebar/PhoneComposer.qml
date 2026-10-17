pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// The composer, like the old phones' (PhoneScreen): 1…7 put the notes c d e f g a b, 0 a rest,
// 8 and 9 make the last one shorter and longer, * its octave, # sharp; ◀ takes the last one
// off, OK plays it all, the red key leaves. The green key keeps it: as her calls' ringtone
// (Config.phone.ringtone), or among the system sounds (a file in Sounds.customDir: System
// sounds lists it for any event — the choice stays there), or back to hers. Every note sounds
// as it goes in (the beeper of scripts/phone-sounds.py).
Item {
    id: root

    required property var phone
    readonly property int k: Theme.u
    readonly property color ink: phone.screenInk

    readonly property var names: ["c", "d", "e", "f", "g", "a", "b"]
    readonly property var semis: ({
            "c": 0,
            "d": 2,
            "e": 4,
            "f": 5,
            "g": 7,
            "a": 9,
            "b": 11
        })
    property var notes: parse(Config.phone.ringtone || PhoneLine.tunes[PhoneLine.who])
    property int oct: 2
    property bool saving: false
    property int saveAt: 0
    readonly property var saves: [I18n.t("На звонок", "As ringtone"), I18n.t("В звуки системы", "To the system sounds"), I18n.t("Вернуть её мелодию", "Back to hers")]
    readonly property var soft: saving ? ["", "OK", I18n.t("Отмена", "Cancel")] : [I18n.t("Сохр.", "Save"), I18n.t("Играть", "Play"), I18n.t("Назад", "Back")]

    function parse(spec) {
        const out = [];
        for (const tok of String(spec || "").trim().split(/\s+/)) {
            const m = /^(\d*)(#?)([a-h-])(\d?)/.exec(tok);
            if (m)
                out.push({
                    "d": Number(m[1]) || 4,
                    "s": m[2] === "#",
                    "n": m[3] === "h" ? "b" : m[3],
                    "o": Number(m[4]) || 2
                });
        }
        return out;
    }
    function spec() {
        return notes.map(n => n.d + (n.s ? "#" : "") + n.n + (n.n === "-" ? "" : n.o)).join(" ");
    }
    function midi(n) {
        return 48 + 12 * (n.o - 1) + semis[n.n] + (n.s ? 1 : 0);
    }
    function change(f) {
        if (!notes.length)
            return;
        const list = notes.slice(), last = Object.assign({}, list[list.length - 1]);
        f(last);
        list[list.length - 1] = last;
        notes = list;
        if (last.n !== "-")
            PhoneLine.note(midi(last));
    }
    function key(k) {
        if (saving) {
            if (k === "left" || k === "up" || k === "2")
                saveAt = (saveAt + 2) % 3;
            else if (k === "right" || k === "down" || k === "8")
                saveAt = (saveAt + 1) % 3;
            else if (k === "ok" || k === "call")
                keep(saveAt);
            else if (k === "end")
                saving = false;
            return true;
        }
        const i = "1234567".indexOf(k);
        if (i >= 0) {
            const n = {
                "d": notes.length ? notes[notes.length - 1].d : 8,
                "s": false,
                "n": names[i],
                "o": oct
            };
            notes = notes.concat([n]);
            PhoneLine.note(midi(n));
            return true;
        }
        if (k === "0") {
            notes = notes.concat([{
                    "d": 8,
                    "s": false,
                    "n": "-",
                    "o": oct
                }]);
            return true;
        }
        if (k === "8") {
            change(n => n.d = Math.min(32, n.d * 2));
            return true;
        }
        if (k === "9") {
            change(n => n.d = Math.max(1, n.d / 2));
            return true;
        }
        if (k === "*") {
            oct = oct % 3 + 1;
            change(n => n.o = root.oct);
            return true;
        }
        if (k === "#") {
            change(n => {
                if (n.n !== "e" && n.n !== "b" && n.n !== "-")
                    n.s = !n.s;
            });
            return true;
        }
        if (k === "left") {
            notes = notes.slice(0, -1);
            return true;
        }
        if (k === "ok") {
            if (notes.length)
                PhoneLine.playTune(spec(), 0.8);
            return true;
        }
        if (k === "call") {
            saving = true;
            saveAt = 0;
            return true;
        }
        return false;
    }
    function keep(i) {
        const s = spec();
        if (i === 0 && s) {
            Config.phone.ringtone = s;
            Achievements.note("phone.melody", "ring");
        } else if (i === 1 && s) {
            // a file of its own in sounds/custom: Settings → System sounds offers it to any event
            const name = I18n.t("Раскладушка ", "Flip phone ") + Qt.formatDateTime(new Date(), "dd.MM hh-mm") + ".wav";
            PhoneLine.render(s, p => {
                Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && cp "$2" "$1/$3"', "sh", Sounds.customDir, p, name]);
                Qt.callLater(Sounds.rescanCustom);
            });
            Achievements.note("phone.melody", "sounds");
        } else if (i === 2) {
            Config.phone.ringtone = "";
            notes = parse(PhoneLine.tunes[PhoneLine.who]);
        }
        saving = false;
        PhoneLine.play("sms", 0.5);
    }

    Column {
        anchors.fill: parent
        spacing: root.k * 2
        Row {
            width: parent.width
            PxText {
                width: parent.width / 2
                text: I18n.t("Мелодия", "Tune")
                kind: "tiny"
                color: root.phone.trim
            }
            PxText {
                width: parent.width / 2
                horizontalAlignment: Text.AlignRight
                text: I18n.t("октава ", "octave ") + root.oct
                kind: "tiny"
                color: root.phone.trim
            }
        }
        // the notes as the old phones wrote them; the last one lit
        Flow {
            visible: !root.saving
            width: parent.width
            spacing: root.k * 2
            Repeater {
                model: root.notes
                PxText {
                    required property var modelData
                    required property int index
                    text: modelData.d + (modelData.s ? "#" : "") + modelData.n + (modelData.n === "-" ? "" : modelData.o)
                    kind: "tiny"
                    color: index === root.notes.length - 1 ? root.phone.trim : root.ink
                    font.bold: index === root.notes.length - 1
                }
            }
        }
        Column {
            visible: root.saving
            width: parent.width
            spacing: root.k
            Repeater {
                model: root.saves
                Rectangle {
                    id: opt
                    required property string modelData
                    required property int index
                    width: parent.width
                    height: root.k * 10
                    color: index === root.saveAt ? root.phone.trim : "transparent"
                    PxText {
                        x: root.k * 2
                        anchors.verticalCenter: parent.verticalCenter
                        text: opt.modelData
                        kind: "tiny"
                        color: opt.index === root.saveAt ? Theme.selectText : root.ink
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.keep(opt.index)
                    }
                }
            }
        }
    }
    PxText {
        visible: !root.saving
        anchors.bottom: parent.bottom
        width: parent.width
        wrapMode: Text.Wrap
        text: I18n.t("1–7 ноты · 0 пауза · 8 9 длина · * октава · # диез · ◀ стереть", "1–7 notes · 0 rest · 8 9 length · * octave · # sharp · ◀ delete")
        kind: "tiny"
        color: phone.hell ? Theme.hellTextDim : Theme.textDim
    }
}
