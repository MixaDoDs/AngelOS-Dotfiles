pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.modules.y2k

// The angel (or the demon, when the game made you one) on the lock screen, drawn from her
// pictures (SpriteRig, the helper's own): her mood follows the lock.
//   sleep   nobody has touched anything for a while: eyes shut, "z z Z"
//   idle    awake, blinking now and then
//   peek    you type the password: she shuts her eyes — no peeking
//   sad     a wrong password: tears
//   happy   the right one: she talks and beats her wings
// `say` is what she would say now (the look draws the bubble).
Item {
    id: root

    required property var lockScope
    property real px: 2
    property string mood: "sleep"
    property string say: ""
    // a skin to show instead of the one she wears (the settings' fitting room); undefined: hers
    property var skin: undefined
    // a heart over her head when she is happy, "z z Z" when she sleeps
    readonly property bool asleep: mood === "sleep"

    implicitWidth: rig.implicitWidth
    implicitHeight: rig.implicitHeight

    property int tick: 0
    property bool blinking: false
    Timer {
        interval: 125
        repeat: true
        running: root.visible && !Motion.still
        onTriggered: {
            root.tick++;
            // a blink every few seconds while awake
            if (root.mood === "idle" && !root.blinking && Math.random() < 0.03) {
                root.blinking = true;
                unblink.restart();
            }
        }
    }
    Timer {
        id: unblink
        interval: 160
        onTriggered: root.blinking = false
    }

    SpriteRig {
        id: rig
        who: Angel.demon ? "demon" : "angel"
        angelVariant: Angel.angelLook === "glitch" || Angel.angelLook === "ophanim" ? Angel.angelLook : ""
        demonVariant: (Config.y2k.demonLook || "glitch") === "glitch" ? "glitch" : ""
        tick: root.tick
        px: root.px
        width: implicitWidth
        height: implicitHeight
        blink: root.mood === "sleep" || root.mood === "peek" || root.mood === "sad" || root.blinking
        talk: root.mood === "happy" || talking.running
        flutter: root.mood === "happy"
        tears: root.mood === "sad" && !Motion.still
        // her skin from heaven's prayers (services/HeavenStars)
        readonly property var skinWorn: root.skin !== undefined ? root.skin : (who === "angel" ? HeavenStars.worn : null)
        layer.enabled: skinWorn !== null
        layer.smooth: false
        layer.effect: AngelSkinFx {
            skin: rig.skinWorn
        }
        // asleep she sinks a little and breathes; happy she hops
        y: Math.round((root.mood === "sleep" ? Math.sin(root.tick / 8) * 1.5 + 2 : root.mood === "happy" ? -Math.abs(Math.sin(root.tick / 2)) * 4 : 0) * root.px)
    }
    Timer {
        id: talking
        interval: 900
    }

    // z z Z
    Repeater {
        model: root.asleep ? 3 : 0
        Text {
            required property int index
            text: index === 2 ? "Z" : "z"
            color: "#ffffff"
            style: Text.Outline
            styleColor: Theme.edge
            font.family: Theme.fontTitle
            font.pixelSize: Theme.fontPx(index === 2 ? 18 : 9, Theme.fontTitle) * Math.max(1, Math.round(root.px / 2))
            readonly property real phase: ((root.tick / 10) + index / 3) % 1
            x: rig.body.x + rig.body.width * 0.75 + index * root.px * 8 + Math.sin(phase * 6) * root.px * 2
            y: rig.body.y + rig.body.height * 0.15 - phase * root.px * 30
            opacity: 1 - phase
        }
    }

    // ---- what moves her ----
    function set(m, line, ms) {
        mood = m;
        say = line || "";
        back.interval = ms || 0;
        if (ms)
            back.restart();
        else
            back.stop();
        asleepSoon.restart();
    }
    // after a reaction: awake and quiet
    Timer {
        id: back
        onTriggered: {
            if (!root.lockScope.unlocking)
                root.set("idle", "");
        }
    }
    // nothing happens for a while: she dozes off
    Timer {
        id: asleepSoon
        interval: 15000
        running: true
        onTriggered: if (root.mood === "idle" && !root.lockScope.unlocking)
            root.set("sleep", "")
    }
    Connections {
        target: root.lockScope
        function onTyped(length, added) {
            if (root.mood === "sleep" && length <= 1)
                root.set("idle", I18n.t("а? я не сплю!", "huh? I'm awake!"), 1200);
            else if (length > 0)
                root.set("peek", I18n.t("не подглядываю ♡", "not peeking ♡"), 2500);
            else
                root.set("idle", "", 0);
        }
        function onShake() {
            const f = root.lockScope.fails;
            root.set("sad", f > 2 ? I18n.t("ну пожааалуйста…", "pleeease…") : I18n.t("ой… не тот", "oops… not that one"), 2600);
        }
        function onSuccess() {
            root.set("happy", I18n.t("с возвращением!!", "welcome back!!"), 0);
        }
    }
    Connections {
        target: LockStream
        function onNotifiedChanged() {
            if (root.mood === "sleep")
                return;
            talking.restart();
            const n = LockStream.notified;
            root.set("idle", n.length ? I18n.t("тебе пишут в %1", "%1 wants you").arg(n[n.length - 1]) : "", 2500);
        }
    }
    function poke() {
        if (mood === "sleep")
            set("idle", I18n.t("м? ты вернулся(ась)?", "hm? you're back?"), 1800);
    }
}
