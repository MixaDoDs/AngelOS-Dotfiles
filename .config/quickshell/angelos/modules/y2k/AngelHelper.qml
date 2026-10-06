pragma ComponentBehavior: Bound

import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Wayland
import QtTest
import qs.config
import qs.services
import qs.widgets
import "AngelSprite.js" as AngelArt
import "DemonSprite.js" as DemonArt
import "AngelSpriteMini.js" as AngelMini
import "DemonSpriteMini.js" as DemonMini

// The Y2K helper: a pixel angel (or the demon, services/Angel) floating in the
// bottom-right corner of her screen. Speech bubble with buttons; a click on her
// opens a menu, "Ask…" takes typed questions. Stepped animation at ~8 fps that
// pauses while the screen is locked or covered by a fullscreen window; the
// angel ↔ demon swap drops one through the floor into flames and brings the
// other in.
// On stream (services/StreamAngel) she moves to the streamed screen and sits on the
// taskbar like a streamer at her desk: cut off at the waist on its top edge (the bottom
// of the screen when the bar is elsewhere), her mouth on the streamer's mic, sized by
// Settings → Y2K → The angel on stream (Ctrl + wheel on her too); clicks, the menu and
// the throw into hell work as always.
Scope {
    // created only while she is wanted (no binding on the window's own visible:
    // Quickshell re-applies it when the screen changes, which loops)
    LazyLoader {
        // hidden from you by Mod+Alt+A while OBS runs (StreamAngel.hidden): only her window
        // for OBS draws her (StreamerCast)
        active: Angel.shown && !Shell.bootOpen && !!Angel.screen && !StreamAngel.hidden

        PanelWindow {
            id: win

            screen: Angel.screen
            // on stream: the bar is her desk. The window keeps out of the bar's exclusive
            // zone, so with no gap under it she sits on the bar's top edge (on the
            // screen's bottom edge when the bar is at the top or a side)
            readonly property bool streamer: Angel.streamer
            readonly property bool atLeft: streamer && Config.stream.streamerSide === "left"
            anchors {
                bottom: true
                right: !win.atLeft
                left: win.atLeft
            }
            margins {
                bottom: win.streamer ? 0 : Theme.u * 4
                right: win.atLeft ? 0 : Theme.u * 6
                left: win.atLeft ? Theme.u * 6 : 0
            }
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: 0
            color: "transparent"
            readonly property real availableWidth: Math.max(1, screen.width - Theme.u * 12)
            readonly property real spritePadding: Math.min(Theme.u * 12, availableWidth / 4)
            readonly property real maxSpriteWidth: Math.max(1, Math.floor(availableWidth - spritePadding))
            readonly property real maxSpriteHeight: Math.max(1, Math.floor(screen.height * 0.55))
            implicitWidth: Math.min(availableWidth, Math.max(Theme.u * 160, sprite.width + spritePadding))
            // room above her for the one coming down from the sky, or while she is held
            readonly property int headroom: (Angel.transition ? Theme.u * 70 : grab.held ? Theme.u * 30 : Novel.wantsClick ? Theme.u * 16 : 0) + liftRoom
            implicitHeight: body.height + headroom
            // on stream over fullscreen games too, as OBS sees the screen
            WlrLayershell.layer: win.streamer ? WlrLayer.Overlay : WlrLayer.Top
            WlrLayershell.namespace: "angelos-angel"
            WlrLayershell.keyboardFocus: Angel.menuOpen && ["ask", "assistant"].includes(Angel.menuMode) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            // the bubble's own `visible` follows the window's: the mask uses the state
            readonly property bool bubbleOn: (Angel.talking || Angel.menuOpen) && !Angel.transition
            // a cutscene on her screen (the circle coming up, CircleFx) hides her: never over it
            readonly property bool underCutscene: CircleFx.active && CircleFx.shownOn(Angel.screenName)
            mask: Region {
                item: win.underCutscene ? null : hit
                Region {
                    item: win.bubbleOn && !win.underCutscene ? bubble : null
                }
            }

            // ---- 8 fps clock: wings, bobbing, blinking, talking ----
            // The demon keeps still: in hell the clock runs only while she talks, is held,
            // swaps, or stirs — once every few minutes, for a moment (the thing seen from the
            // corner of an eye). Gluttony's authored belly mouth keeps its regular clock
            // at rest, unless calm motion is selected — the belly alone: her wings, tail and
            // eyes rest like any demon's (`swing` stands still while only the belly ticks).
            property int tick: 0
            property int swing: 0
            readonly property bool still: demonArt && !Angel.transition
            readonly property bool bellyClock: sprite.circleSkin && sprite.skin === "gluttony" && !Motion.calm
            property bool stirring: false
            readonly property string assistantMood: Angel.assistant && Angel.assistant.helperMood || ""
            readonly property bool assistantBusy: !!Angel.assistant && Angel.assistant.helperBusy === true
            readonly property bool expressive: !Motion.calm && !Angel.transition && !grab.held
            readonly property bool awake: !still || stirring || Angel.talking || Angel.menuOpen || grab.held || Novel.wantsClick || voiceOn || assistantBusy || !!assistantMood
            // on stream she stays awake over a fullscreen game: the viewers see her
            readonly property bool clockOn: win.visible && (streamer ? !Shell.locked : !Shell.hiddenScreen(Angel.screenName)) && (awake || bellyClock)
            Timer {
                interval: 125
                running: win.clockOn
                repeat: true
                onTriggered: {
                    win.tick++;
                    if (win.awake)
                        win.swing++;
                }
            }
            Timer {
                id: stirWait
                running: win.still && win.visible && !win.stirring && !Motion.calm
                interval: (100 + Math.random() * 200) * 1000
                onTriggered: {
                    win.stirring = true;
                    stirEnd.restart();
                }
            }
            Timer {
                id: stirEnd
                interval: 2600
                onTriggered: {
                    win.stirring = false;
                    stirWait.interval = (100 + Math.random() * 200) * 1000;
                }
            }
            // the swap flips the sprite halfway through (Angel.becomeDemon/becomeAngel)
            readonly property bool demonArt: Angel.demon
            readonly property bool blinking: clockOn && awake && (tick % 29 === 0 || (expressive && assistantMood === "happy" && tick % 24 < 3))
            // her own words type out; on stream the streamer's voice moves her mouth too
            // (a PNGtuber's: open on loud syllables, flapping in between)
            readonly property bool voiceOn: streamer && StreamAngel.talking && !Angel.transition
            readonly property bool mouthOpen: (Angel.talking && typer.shown < Angel.text.length && tick % 2 === 0) || (voiceOn && (StreamAngel.level > StreamAngel.threshold * 1.5 || tick % 2 === 0))
            // Settings → Y2K → Looks, each of them apart: glitch (the cracked-halo angel /
            // the sleepless neon demon, SpriteRig), chibi (the first pictures), adult (the 30×40
            // pixel sprite, also when the pictures are missing) or mini (20×21); the angel's own
            // past cold is the story's (Angel.angelLook: story/game.json → angel.fallen.look)
            readonly property string angelLook: Angel.angelLook
            readonly property string demonLook: ["glitch", "chibi", "adult", "mini"].includes(Config.y2k.demonLook) ? Config.y2k.demonLook : "glitch"
            readonly property string look: demonArt ? demonLook : angelLook
            readonly property bool mini: look === "mini"
            // her requested size: 75…200 % in 5 % steps; screen bounds cap the rendered size
            readonly property real zoom: Math.max(0.75, Math.min(2, Config.y2k.helperScale || 1))
            // on stream her size is the part above the bar: a share of the screen's height
            // (10…50 %), whole screen pixels per art pixel while there are enough of them
            readonly property real streamShare: Math.max(10, Math.min(50, Config.stream.streamerSize || 30))
            readonly property real waist: sprite.ready && sprite.rig.waist ? sprite.rig.waist : 0.66
            function streamPx(artH) {
                const raw = (win.screen ? win.screen.height : 1080) * streamShare / 100 / Math.max(1, artH * waist);
                return raw >= 3 ? Math.floor(raw) : Math.max(0.5, raw);
            }
            // below the waist she is under the bar's edge (the window ends there)
            readonly property real sink: streamer ? Math.round(sprite.height * (1 - waist)) + Theme.u * 2 : 0
            // she bobs up with the voice and breathes slowly while quiet
            property real voiceBounce: voiceOn && !Motion.still ? StreamAngel.level : 0
            Behavior on voiceBounce {
                NumberAnimation {
                    duration: 90
                }
            }
            readonly property real artPx: sprite.ready ? sprite.px : pixelArt.exactPixel
            readonly property real liftRoom: streamer ? Math.ceil(artPx * 6) : 0
            readonly property real voiceLift: !streamer ? 0 : Math.round(voiceBounce * 4) * artPx + (Motion.still || (still && !stirring) ? 0 : [0, 0, 1, 1][Math.floor(tick / 4) % 4] * artPx)
            readonly property var art: mini ? (demonArt ? DemonMini : AngelMini) : (demonArt ? DemonArt : AngelArt)
            readonly property var frame: {
                if (mouthOpen)
                    return art.talk;
                if (blinking)
                    return art.blink;
                return Math.floor(tick / 3) % 2 ? art.down : art.up;
            }
            readonly property int bob: Angel.transition || Motion.calm || (still && !stirring && !assistantBusy && !assistantMood) ? 0 : [0, 1, 2, 2, 1, 0, -1, -1][tick % 8]
            // swap motion: the leaving one hops and drops through the floor, the new one
            // climbs out of the flames (demon) or comes down from the sky (angel)
            readonly property real swapY: {
                const p = Angel.swap;
                if (!Angel.transition)
                    return 0;
                const h = sprite.height + Theme.u * 8;
                if (p < 0.5) {
                    const q = p / 0.5;
                    // thrown: she keeps falling from where she was let go
                    if (Angel.thrown)
                        return Angel.throwY + q * q * (h * 1.2 - Angel.throwY);
                    return q < 0.25 ? -Math.sin(q / 0.25 * Math.PI) * Theme.u * 8 : (q - 0.25) / 0.75 * h * 1.2;
                }
                const q = (p - 0.5) / 0.5;
                return Angel.transition === "toHell" ? (1 - q) * h * 1.2 : -(1 - q) * Theme.u * 70;
            }
            // where the sprite is: held by the pointer, springing back, or falling from the throw
            readonly property real offX: Angel.transition ? (Angel.thrown && Angel.swap < 0.5 ? Angel.throwX : 0) : grab.dx
            readonly property real offY: Angel.transition ? swapY : grab.dy
            // the angel coming back: from halfway through the swap, and a moment after
            property bool afterglow: false
            property string lastTransition: ""
            readonly property bool resurrecting: (Angel.transition === "ascend" && Angel.swap >= 0.5) || afterglow
            Connections {
                target: Angel
                function onTransitionChanged() {
                    if (!Angel.transition && win.lastTransition === "ascend") {
                        win.afterglow = true;
                        afterglowEnd.restart();
                    }
                    win.lastTransition = Angel.transition;
                }
            }
            Timer {
                id: afterglowEnd
                interval: 1200
                onTriggered: win.afterglow = false
            }
            // hellfire under her: while the swap runs, and as she is pushed into the floor
            readonly property real flames: Angel.transition ? Math.max(0, 1 - Math.abs(Angel.swap - 0.5) * 2.4) : (!demonArt && grab.dy > 0 ? Math.min(1, grab.dy / (sprite.height * 0.55)) : 0)

            Item {
                id: body
                opacity: win.underCutscene ? 0 : 1
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                    }
                }
                anchors.bottom: parent.bottom
                width: parent.width
                height: angel.height + (win.bubbleOn ? bubble.height + Theme.u * 2 + win.liftRoom : 0) + Theme.u * 4

                // ---- speech bubble / menu ----
                PxBox {
                    id: bubble
                    visible: win.bubbleOn
                    anchors.right: win.atLeft ? undefined : parent.right
                    anchors.left: win.atLeft ? parent.left : undefined
                    anchors.bottom: angel.top
                    anchors.bottomMargin: Theme.u * 2 + win.liftRoom
                    width: Theme.u * 150
                    height: bubbleCol.implicitHeight + Theme.u * 8
                    // in hell the bubble is the circle's: its plate, its bone text, its buttons
                    hell: Angel.demon
                    color: Angel.demon ? Theme.hellPanel : Theme.menuSurface
                    shadow: Config.appearance.shadows

                    Column {
                        id: bubbleCol
                        x: Theme.u * 4
                        y: Theme.u * 4
                        width: parent.width - Theme.u * 8
                        spacing: Theme.u * 3

                        Row {
                            width: parent.width
                            spacing: Theme.u * 2
                            // what she says: Undertale letters, typed out and trembling
                            ShakyText {
                                visible: !Angel.menuOpen
                                width: parent.width - closeBtn.width - Theme.u * 2
                                text: Angel.text
                                color: Angel.demon ? Theme.hellText : Theme.text
                                shown: typer.shown
                                shake: 1
                                // Y2K → Text tremble: off | light | strong; the demon's words barely move
                                twitch: Config.y2k.textShake === "off" || Motion.calm ? 0 : (Config.y2k.textShake === "strong" ? 0.18 : 0.05) * (Angel.demon ? 0.5 : 1)
                            }
                            PxText {
                                visible: Angel.menuOpen
                                color: Angel.demon ? Theme.hellText : Theme.text
                                width: parent.width - closeBtn.width - Theme.u * 2
                                text: !Angel.menuOpen ? "" : Angel.menuMode === "assistant" ? (Angel.assistant && Angel.assistant.helperTitle || I18n.t("AI-помощник", "AI assistant")) : Angel.menuMode === "ask" ? (Angel.demon ? I18n.t("Спрашивай. Может, отвечу.", "Go on, ask. Maybe I'll answer.") : I18n.t("Спроси что угодно — и про настройки тоже ♡", "Ask me anything, settings included ♡")) : (Angel.demon ? I18n.t("Ну? Чего тебе? Ангела хочешь — «Спросить…», и проси красиво.", "Well? What do you want? Want your angel — “Ask…”, and beg nicely.") : I18n.t("Чем помочь? ♡", "How can I help? ♡"))
                                wrapMode: Text.Wrap
                            }
                            PxButton {
                                hell: Angel.demon
                                id: closeBtn
                                compact: true
                                flat: true
                                icon: "close"
                                onClicked: Angel.hush()
                            }
                        }

                        // buttons of what she said (undo a prank, show the setting, another joke…):
                        // the first is the one she means; answers to her question (`choice`) all
                        // look the same, none is singled out
                        Flow {
                            visible: !Angel.menuOpen && Angel.actions.length > 0 && typer.shown >= Angel.text.length
                            width: parent.width
                            spacing: Theme.u * 2
                            Repeater {
                                model: Angel.menuOpen ? [] : Angel.actions
                                PxButton {
                                    hell: Angel.demon
                                    required property var modelData
                                    required property int index
                                    compact: true
                                    accent: index === 0 && !modelData.choice
                                    icon: modelData.icon || "heart"
                                    text: modelData.label
                                    onClicked: {
                                        const run = modelData.run;
                                        Angel.hush();
                                        if (run)
                                            run();
                                    }
                                }
                            }
                        }

                        // ---- the menu ----
                        Flow {
                            visible: Angel.menuOpen && Angel.menuMode === "main"
                            width: parent.width
                            spacing: Theme.u * 2
                            PxButton {
                                hell: Angel.demon
                                compact: true
                                accent: true
                                icon: "chat"
                                text: I18n.t("Спросить…", "Ask…")
                                onClicked: Angel.openMenu("ask")
                            }
                            PxButton {
                                hell: Angel.demon
                                visible: !!Angel.assistantUrl
                                compact: true
                                icon: "bot"
                                text: Angel.assistant && Angel.assistant.helperTitle || I18n.t("AI-помощник", "AI assistant")
                                onClicked: Angel.openMenu("assistant")
                            }
                            PxButton {
                                hell: Angel.demon
                                visible: !Angel.demon
                                compact: true
                                icon: "star"
                                text: I18n.t("Совет", "A tip")
                                onClicked: Angel.tip()
                            }
                            PxButton {
                                hell: Angel.demon
                                compact: true
                                icon: "sparkle"
                                text: Angel.demon ? I18n.t("Пошути", "Joke") : I18n.t("Шутка", "A joke")
                                onClicked: Angel.joke()
                            }
                            // the demon asks something, three answers to pick from; in a circle
                            // it is her talk with the player instead (Story → closeness, item 12)
                            PxButton {
                                hell: Angel.demon
                                visible: Angel.demon
                                compact: true
                                icon: "chat"
                                text: Story.circle ? I18n.t("Поговорить", "Talk") : I18n.t("Поболтаем", "Let's chat")
                                onClicked: Story.circle ? Angel.demonDo("talk") : Angel.talk()
                            }
                            PxButton {
                                hell: Angel.demon
                                visible: Angel.demon && !!Story.circle
                                compact: true
                                icon: "heartHorns"
                                text: I18n.t("Подарок: ", "Gift: ") + Story.giftName()
                                onClicked: Angel.demonDo("gift")
                            }
                            PxButton {
                                hell: Angel.demon
                                visible: Angel.demon && !!Story.circle
                                compact: true
                                icon: "pin"
                                text: I18n.t("Остаться", "Stay")
                                onClicked: Angel.demonDo("stay")
                            }
                            PxButton {
                                hell: Angel.demon
                                visible: !Angel.demon
                                compact: true
                                icon: "gear"
                                text: I18n.t("Настройки", "Settings")
                                onClicked: {
                                    Angel.hush();
                                    Shell.openSettings();
                                }
                            }
                            PxButton {
                                hell: Angel.demon
                                compact: true
                                icon: "moon"
                                text: Angel.demon ? I18n.t("Отстань на час", "Leave me for an hour") : I18n.t("Спрячься на час", "Hide for an hour")
                                onClicked: Angel.hide(60)
                            }
                            // the portal: open after the angel's third comeback (or for the owner) —
                            // heaven ↔ hell at once, no begging and no throwing
                            PxButton {
                                hell: Angel.demon
                                visible: Angel.portalOpen
                                compact: true
                                accent: true
                                icon: "sparkle"
                                text: Angel.demon ? I18n.t("Портал в рай", "Portal to heaven") : I18n.t("Портал в ад", "Portal to hell")
                                onClicked: Angel.portal()
                            }
                            PxButton {
                                hell: Angel.demon
                                compact: true
                                icon: "close"
                                text: I18n.t("Выключить", "Turn off")
                                onClicked: {
                                    Angel.hush();
                                    Story.act("helper.off");
                                    Config.y2k.helper = false;
                                }
                            }
                        }

                        // Plugin-owned input/confirmation panel, in both heaven and hell.
                        Loader {
                            width: parent.width
                            active: Angel.menuOpen && Angel.menuMode === "assistant" && !!Angel.assistantUrl
                            visible: active
                            source: active ? Angel.assistantUrl : ""
                            height: active && item ? item.implicitHeight : 0
                        }

                        // ---- Ask… ----
                        PxField {
                            id: askField
                            keepFocus: true
                            visible: Angel.menuOpen && Angel.menuMode === "ask"
                            width: parent.width
                            icon: "chat"
                            placeholder: Angel.demon ? I18n.t("Ну, спроси…", "Go on, ask…") : I18n.t("Например: как сделать крупнее?", "E.g. how do I make things bigger?")
                            onAccepted: {
                                const q = text;
                                text = "";
                                Angel.answer(q);
                            }
                            onKeyPressed: e => {
                                if (e.key === Qt.Key_Escape) {
                                    Angel.hush();
                                    e.accepted = true;
                                }
                            }
                            onVisibleChanged: if (visible)
                                focusLater.restart()
                            Timer {
                                id: focusLater
                                interval: 60
                                onTriggered: askField.focusField()
                            }
                        }
                        Flow {
                            visible: Angel.menuOpen && Angel.menuMode === "ask"
                            width: parent.width
                            spacing: Theme.u * 2
                            PxButton {
                                hell: Angel.demon
                                visible: Angel.demon
                                compact: true
                                accent: true
                                icon: "heart"
                                text: Angel.now && Story.tryLabel(I18n.t("Искать выход", "Seek the way out"))
                                onClicked: Angel.plea()
                            }
                            PxButton {
                                hell: Angel.demon
                                compact: true
                                icon: "sparkle"
                                text: I18n.t("Пошути", "Tell a joke")
                                onClicked: Angel.joke()
                            }
                            PxButton {
                                hell: Angel.demon
                                visible: !Angel.demon
                                compact: true
                                icon: "star"
                                text: I18n.t("Дай совет", "Give me a tip")
                                onClicked: Angel.tip()
                            }
                            PxButton {
                                hell: Angel.demon
                                compact: true
                                icon: "chat"
                                text: I18n.t("Как дела?", "How are you?")
                                onClicked: Angel.answer(I18n.t("как дела", "how are you"))
                            }
                            PxButton {
                                hell: Angel.demon
                                compact: true
                                icon: "info"
                                text: I18n.t("Кто ты?", "Who are you?")
                                onClicked: Angel.answer(I18n.t("кто ты", "who are you"))
                            }
                            PxButton {
                                hell: Angel.demon
                                compact: true
                                flat: true
                                icon: "arrowLeft"
                                text: I18n.t("Назад", "Back")
                                onClicked: Angel.openMenu("main")
                            }
                        }
                    }
                }

                // typewriter for the bubble text: a letter at a time, each with a
                // "pip" of her voice like in Undertale (Y2K → Sounds → Voices)
                QtObject {
                    id: typer
                    property int shown: 0
                }
                Timer {
                    interval: 32
                    running: Angel.talking && typer.shown < Angel.text.length
                    repeat: true
                    onTriggered: {
                        typer.shown = Math.min(Angel.text.length, typer.shown + 1);
                        const c = Angel.text.charAt(typer.shown - 1);
                        if (/[0-9A-Za-zÀ-ɏЀ-ӿ]/.test(c))
                            voice.pip(c);
                    }
                }
                Connections {
                    target: Angel
                    function onTextChanged() {
                        typer.shown = 0;
                        if (voice.on)
                            Sounds.ensure();
                    }
                }
                // a few players take turns: a pip is shorter than a letter
                Item {
                    id: voice
                    readonly property bool on: Sounds.enabled("voice") && !StreamMode.quiet && Sounds.ready
                    // loaded once the pack is ready: an older, louder pack is synthesised again first
                    readonly property url clip: Sounds.ready ? "file://" + Sounds.dir + "/" + (Angel.demon ? "voiceDemon" : "voiceAngel") + ".wav" : ""
                    property int next: 0
                    // past cold (story/game.json → angel.fallen) her voice is broken: no pips — a
                    // syllable on each vowel, one of five, never the same twice running, not on
                    // top of the last one's start (Sounds.fallenVoice, scripts/y2k-sounds.py)
                    readonly property bool broken: !Angel.demon && Story.angelFallen
                    property int lastSyllable: -1
                    property int turn: 0
                    property double sungAt: 0
                    function syllable(c) {
                        if (!/[аеёиоуыэюяaeiouy]/i.test(c) || Date.now() - sungAt < 90)
                            return;
                        let v = Math.floor(Math.random() * 5);
                        if (v === lastSyllable)
                            v = (v + 1 + Math.floor(Math.random() * 4)) % 5;
                        lastSyllable = v;
                        sungAt = Date.now();
                        turn = 1 - turn;
                        const it = syllables.itemAt(v + 5 * turn);
                        if (it)
                            it.fx.play();
                    }
                    Repeater {
                        id: syllables
                        model: voice.broken ? 10 : 0
                        Item {
                            id: syl
                            required property int index
                            property alias fx: fx
                            SoundEffect {
                                id: fx
                                source: Sounds.ready ? "file://" + Sounds.dir + "/" + Sounds.fallenVoice[syl.index % 5] + ".wav" : ""
                                volume: Sounds.volumeOf(Sounds.fallenVoice[syl.index % 5])
                            }
                        }
                    }
                    function pip(c) {
                        if (!on)
                            return;
                        if (broken)
                            return syllable(c);
                        const s = [v0, v1, v2][next];
                        next = (next + 1) % 3;
                        s.play();
                    }
                    SoundEffect {
                        id: v0
                        source: voice.clip
                        volume: Sounds.volumeOf("voiceAngel")
                    }
                    SoundEffect {
                        id: v1
                        source: voice.clip
                        volume: Sounds.volumeOf("voiceAngel")
                    }
                    SoundEffect {
                        id: v2
                        source: voice.clip
                        volume: Sounds.volumeOf("voiceAngel")
                    }
                }

                // ---- the angel (or the demon) ----
                Item {
                    id: angel
                    anchors.right: win.atLeft ? undefined : parent.right
                    anchors.left: win.atLeft ? parent.left : undefined
                    anchors.bottom: parent.bottom
                    width: sprite.width
                    height: sprite.height + Theme.u * 4 - win.sink

                    // the window takes the pointer over her body, where she stands at
                    // rest; the air around the wings and the tail lets clicks through
                    Item {
                        id: hit
                        x: sprite.body.x
                        y: Theme.u * 2 + sprite.body.y
                        width: sprite.body.width
                        height: Math.max(1, Math.min(sprite.body.height, angel.height - y))
                    }

                    // her stage reaches up into the sky and across the window while she
                    // moves; below the floor she is cut off (drops through it instead of
                    // over the bar)
                    Item {
                        id: stage
                        readonly property bool moving: !!Angel.transition || grab.held
                        anchors.bottom: parent.bottom
                        anchors.right: win.atLeft ? undefined : parent.right
                        anchors.left: win.atLeft ? parent.left : undefined
                        width: moving ? win.width : parent.width
                        height: parent.height + win.headroom
                        clip: moving

                        // the angel is back from the dead: she floats down a column of
                        // light in a glow, and it lingers a moment after she lands
                        Item {
                            id: rise
                            anchors.fill: parent
                            opacity: win.resurrecting ? 1 : 0
                            visible: opacity > 0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 450
                                }
                            }
                            readonly property real cx: sprite.x + sprite.body.x + sprite.body.width / 2
                            readonly property real cy: sprite.y + sprite.body.y + sprite.body.height / 2
                            Rectangle {
                                x: rise.cx - width / 2
                                width: sprite.width * 0.8
                                height: sprite.y + sprite.height * 0.85
                                gradient: Gradient {
                                    GradientStop {
                                        position: 0
                                        color: Qt.rgba(1, 0.95, 0.72, 0)
                                    }
                                    GradientStop {
                                        position: 0.55
                                        color: Qt.rgba(1, 0.95, 0.72, 0.28)
                                    }
                                    GradientStop {
                                        position: 1
                                        color: Qt.rgba(1, 0.98, 0.86, 0.5)
                                    }
                                }
                            }
                            // the glow in stepped pixel rings, breathing with the 8 fps clock
                            Repeater {
                                model: 3
                                Rectangle {
                                    required property int index
                                    readonly property real pad: Theme.u * (3 + index * 5 + (win.tick + index) % 2)
                                    x: sprite.x - pad
                                    y: sprite.y - pad
                                    width: sprite.width + pad * 2
                                    height: sprite.height + pad * 2
                                    radius: Theme.u * (6 + index * 3)
                                    color: Qt.rgba(1, 0.92, 0.6, 0.2 - index * 0.055)
                                }
                            }
                            // sparkles around her, twinkling in turns
                            Repeater {
                                model: 6
                                PxIcon {
                                    required property int index
                                    readonly property real a: index / 6 * Math.PI * 2 + win.tick * 0.35
                                    name: "sparkle"
                                    pixel: Math.max(1, Theme.u)
                                    fill: "#fff3b0"
                                    fill3: "#ffe07a"
                                    x: rise.cx + Math.cos(a) * sprite.body.width * 0.85 - width / 2
                                    y: rise.cy + Math.sin(a) * sprite.height * 0.55 - height / 2
                                    visible: (win.tick + index) % 3 !== 0
                                }
                            }
                        }

                        // her pictures in parts: wings (and the demon's tail) swing,
                        // she blinks and talks (sprites/, SpriteRig)
                        SpriteRig {
                            id: sprite
                            x: (win.atLeft ? 0 : stage.width - width) + win.offX
                            y: stage.height - angel.height + Theme.u * 2 + (stage.moving ? 0 : win.streamer ? -win.voiceLift : win.bob * Math.max(1, Theme.u / 2)) + win.offY
                            width: ready ? implicitWidth : pixelArt.width
                            height: ready ? implicitHeight : pixelArt.height
                            who: win.demonArt ? "demon" : "angel"
                            tick: win.tick
                            swingTick: win.swing
                            blink: win.blinking
                            talk: win.mouthOpen
                            // Small whole-rig gestures keep authored sprite parts aligned.
                            rotation: win.expressive ? win.assistantBusy ? Math.sin(win.tick * 0.23) * 2 : win.assistantMood === "happy" ? Math.sin(win.tick * 0.65) * 3 : win.assistantMood === "concerned" ? -2 : 0 : 0
                            transformOrigin: Item.Bottom
                            flutter: grab.held || (win.expressive && win.assistantMood === "happy")
                            // past cold she cries (story/game.json → angel.fallen); motion off: no drops
                            tears: !win.demonArt && Story.angelFallen && !Motion.still
                            // her skin from heaven's prayers (services/HeavenStars)
                            layer.enabled: !win.demonArt && ready && HeavenStars.worn !== null
                            layer.smooth: false
                            layer.effect: AngelSkinFx {
                                skin: HeavenStars.worn
                            }
                            use: win.look === "chibi" || win.look === "glitch" || win.look === "ophanim"
                            // each figure's pictures, both read up front: the swap flips at once
                            // even when the angel's look and the demon's differ
                            angelVariant: win.angelLook === "glitch" || win.angelLook === "ophanim" ? win.angelLook : ""
                            demonVariant: win.demonLook === "glitch" ? "glitch" : ""
                            // the circle's own demon, once her pictures are cut (sprite-rig.py skins);
                            // the debug panel may stand any circle's demon here
                            skin: !win.demonArt ? "" : GameDebug.skin === "-" ? "" : GameDebug.skin || (Story.inHell ? HellLook.circle : "")
                            // At Theme.u=2, the 236px circle body is ~271px at 115%.
                            // Bound the whole rig, including wings, without changing the saved zoom.
                            px: ready ? Math.min(win.streamer ? win.streamPx(rig.size[1]) : Math.max(1, Theme.u / 2) * win.zoom,
                                                 win.maxSpriteWidth / Math.max(1, rig.size[0]),
                                                 win.maxSpriteHeight / Math.max(1, rig.size[1]))
                                      : Math.max(1, Theme.u / 2) * win.zoom

                            // in hell too she is drawn in her own colours, as the author painted her:
                            // no recolouring into the circle's palette (each circle has its own girl)

                            // without the pictures: the 30×40 pixel sprite, 3 screen
                            // pixels each at the default size; the mini ones 4 each
                            PxIcon {
                                id: pixelArt
                                visible: !sprite.ready
                                bitmap: sprite.ready ? null : win.frame
                                pixel: win.mini ? Theme.u * 2 : Math.max(2, Math.round(Theme.u * 1.5))
                                exactPixel: Math.min(win.streamer ? win.streamPx(win.frame.length) : pixel * win.zoom,
                                                     win.maxSpriteWidth / Math.max(1, win.frame.reduce((w, row) => Math.max(w, row.length), 0)),
                                                     win.maxSpriteHeight / Math.max(1, win.frame.length))
                                // the mini ones: the colours they had, from the theme
                                ink: win.demonArt ? "#1a0a14" : (Theme.dark ? Theme.text : Theme.edge)
                                body: win.demonArt ? "#f7d9e3" : "#ffd9c7"
                                fill: win.demonArt ? "#ff3b6b" : Theme.accent
                                fill2: "#3a1a46"
                                fill3: Theme.dark ? "#ffe07a" : "#f5c542"
                                light: win.demonArt ? "#7a1e46" : "#ffffff"
                                bad: "#d8203a"
                                // the adult ones: her own colours; the angel's pink follows the accent
                                palette: win.mini ? ({}) : win.demonArt ? DemonArt.palette : Object.assign({}, AngelArt.palette, {
                                    "o": Theme.hex(Theme.accent)
                                })
                            }
                        }
                        // the novel has a question for you: a "?" bobbing over her head (click her)
                        PxBox {
                            visible: Novel.wantsClick && !win.bubbleOn && !stage.moving
                            x: sprite.x + sprite.body.x + (sprite.body.width - width) / 2
                            y: Math.max(0, sprite.y + sprite.body.y - height - Theme.u * 3 + (win.tick % 4 < 2 ? 0 : -Theme.u))
                            width: Theme.u * 11
                            height: Theme.u * 13
                            color: Angel.demon ? Theme.hellBlood : Theme.accent
                            PxText {
                                anchors.centerIn: parent
                                kind: "title"
                                font.bold: true
                                color: Angel.demon ? Theme.hellText : Theme.selectText
                                text: "?"
                            }
                        }
                        // hellfire at the floor under her while they swap, or as she is
                        // pushed down
                        Row {
                            visible: win.flames > 0
                            opacity: win.flames
                            anchors.bottom: parent.bottom
                            x: sprite.x + sprite.body.x + (sprite.body.width - width) / 2
                            spacing: 0
                            Repeater {
                                model: 4
                                PxIcon {
                                    required property int index
                                    name: "fire"
                                    pixel: Theme.u * 2
                                    // the circle's fire, not a cartoon's: its accent, its blood, its dim light
                                    ink: Theme.hellEdge
                                    fill3: Theme.hellAccent
                                    bad: Theme.hellBlood
                                    light: Theme.hellFlame
                                    y: ((win.tick + index) % 2) * Theme.u
                                }
                            }
                        }
                    }
                    // a click opens her menu; press and drag picks her up. Let go deep
                    // below the floor (or fling her down) and she falls into hell;
                    // anything less and she springs back. The demon always springs back.
                    MouseArea {
                        id: grab
                        anchors.fill: parent
                        enabled: !Angel.transition
                        cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                        property bool dragging: false
                        readonly property bool held: dragging || spring.running
                        property real dx: 0
                        property real dy: 0
                        property point start
                        property real vy: 0                      // downward speed, px/ms
                        property real lastY: 0
                        property double lastT: 0
                        readonly property real deep: sprite.height * 0.55

                        onPressed: m => {
                            spring.stop();
                            start = Qt.point(m.x, m.y);
                            dragging = false;
                            dx = 0;
                            dy = 0;
                            vy = 0;
                            lastY = m.y;
                            lastT = Date.now();
                        }
                        onPositionChanged: m => {
                            if (!pressed)
                                return;
                            if (!dragging) {
                                if (Math.abs(m.x - start.x) + Math.abs(m.y - start.y) < Theme.u * 3)
                                    return;
                                dragging = true;
                                Angel.grabbed();
                            }
                            const now = Date.now();
                            if (now > lastT) {
                                vy = vy * 0.4 + (m.y - lastY) / (now - lastT) * 0.6;
                                lastY = m.y;
                                lastT = now;
                            }
                            dx = win.atLeft ? Math.max(-Theme.u * 4, Math.min(win.width - sprite.width, m.x - start.x)) : Math.max(-(win.width - sprite.width), Math.min(Theme.u * 4, m.x - start.x));
                            dy = Math.max(-Theme.u * 26, m.y - start.y);
                        }
                        onReleased: {
                            if (!dragging) {
                                // the novel waits for this click ("?" over her): its question comes
                                if (!Angel.menuOpen && Novel.click())
                                    return;
                                if (Angel.menuOpen)
                                    Angel.hush();
                                else
                                    Angel.openMenu("main");
                                return;
                            }
                            dragging = false;
                            const thrown = !Angel.demon && (dy > deep || (dy > Theme.u * 6 && vy > 0.9));
                            // flung (fast) or pushed down slowly, on purpose: the game weighs it
                            Angel.released(thrown, dx, dy, vy > 0.9);
                            if (thrown) {
                                dx = 0;
                                dy = 0;
                            } else {
                                spring.start();
                            }
                        }
                        onCanceled: {
                            dragging = false;
                            spring.start();
                        }
                        // Ctrl + wheel: 75…200 %, 5 % a notch; on stream her share of the
                        // screen, 10…50 %, 2 % a notch
                        property real wheelRest: 0
                        onWheel: w => {
                            if (!(w.modifiers & Qt.ControlModifier)) {
                                w.accepted = false;
                                return;
                            }
                            wheelRest += w.angleDelta.y !== 0 ? w.angleDelta.y / 120 : w.pixelDelta.y / 40;
                            const notches = wheelRest > 0 ? Math.floor(wheelRest) : Math.ceil(wheelRest);
                            if (!notches)
                                return;
                            wheelRest -= notches;
                            if (win.streamer) {
                                const share = Math.max(10, Math.min(50, Math.round(win.streamShare + notches * 2)));
                                if (share !== Config.stream.streamerSize)
                                    Config.stream.streamerSize = share;
                                sizeNote.show();
                                return;
                            }
                            const next = Math.max(0.75, Math.min(2, Math.round((win.zoom + notches * 0.05) * 100) / 100));
                            if (next !== Config.y2k.helperScale)
                                Config.y2k.helperScale = next;
                            sizeNote.show();
                        }
                        // dev (`angelos helper "drag DX DY MS"`): the same drag, replayed
                        TestEvent {
                            id: sim
                        }
                        Timer {
                            id: replay
                            property var path: []
                            interval: 16
                            repeat: true
                            onTriggered: {
                                const p = path.shift();
                                if (p.up)
                                    sim.mouseRelease(grab, p.x, p.y, Qt.LeftButton, Qt.NoModifier, -1);
                                else
                                    sim.mouseMove(grab, p.x, p.y, -1, Qt.LeftButton, Qt.NoModifier);
                                if (!path.length)
                                    stop();
                            }
                        }
                        Connections {
                            target: Angel
                            enabled: Shell.dev
                            function onDevDrag(ddx, ddy, ms) {
                                const x0 = grab.width / 2, y0 = grab.height / 2, n = Math.max(2, Math.round(ms / 16));
                                sim.mousePress(grab, x0, y0, Qt.LeftButton, Qt.NoModifier, -1);
                                const path = [];
                                for (let i = 1; i <= n; i++)
                                    path.push({
                                        "x": x0 + ddx * i / n,
                                        "y": y0 + ddy * i / n
                                    });
                                path.push({
                                    "x": x0 + ddx,
                                    "y": y0 + ddy,
                                    "up": true
                                });
                                replay.path = path;
                                replay.start();
                            }
                        }
                        // back to her place with a little bounce
                        ParallelAnimation {
                            id: spring
                            NumberAnimation {
                                target: grab
                                property: "dx"
                                to: 0
                                duration: 320
                                easing.type: Easing.OutBack
                            }
                            NumberAnimation {
                                target: grab
                                property: "dy"
                                to: 0
                                duration: 320
                                easing.type: Easing.OutBack
                            }
                        }
                    }
                }
            }

            // the size, for a moment, as Ctrl + wheel changes it
            PxBox {
                id: sizeNote
                function show() {
                    opacity = 1;
                    sizeFade.restart();
                }
                opacity: 0
                visible: opacity > 0
                anchors.right: win.atLeft ? undefined : parent.right
                anchors.left: win.atLeft ? parent.left : undefined
                anchors.rightMargin: Theme.u * 2
                anchors.leftMargin: Theme.u * 2
                y: parent.height - angel.height + Theme.u * 2
                width: sizeText.implicitWidth + Theme.u * 6
                height: sizeText.implicitHeight + Theme.u * 3
                color: Theme.menuSurface
                PxText {
                    id: sizeText
                    anchors.centerIn: parent
                    text: Math.round(win.streamer ? win.streamShare : win.zoom * 100) + "%"
                    kind: "tiny"
                }
                Timer {
                    id: sizeFade
                    interval: 900
                    onTriggered: sizeNote.opacity = 0
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                    }
                }
            }

            RightClickGuard {}
        }
    }
}
