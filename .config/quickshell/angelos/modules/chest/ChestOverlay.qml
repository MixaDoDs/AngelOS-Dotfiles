pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Heaven's chest (services/Chests): one prayer or ten, opened like a Vampire Survivors /
// Megabonk chest. idle (it bobs: press) → shake (its glow climbs blue → purple → gold up to the
// best rarity inside) → burst (the lid flies, a beam, a flash) → reel (×1: a strip of prizes
// slows down onto yours) or fan (×10: the cards fly out and turn over) → prize (the card,
// its stars one by one, NEW or the refund) → done (another one, ten, close). Any key or click
// skips to the next beat; Esc closes once it is open. Pixel art: data/chest (scripts/chest-art.py).
PanelWindow {
    id: win

    screen: Shell.focusedScreen
    visible: Chests.open
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "angelos-chest"
    WlrLayershell.layer: WlrLayer.Overlay
    // takes input: the chest is opened with a click or a key, the whole screen is its button
    WlrLayershell.keyboardFocus: visible ? (Shell.dev ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive) : WlrKeyboardFocus.None

    readonly property var res: Chests.results
    readonly property bool ten: res.length > 1
    readonly property var prize: res.length ? res[0] : null
    // idle | shake | burst | reel | fan | prize | done
    property string phase: "idle"
    property int glow: 3                       // the rarity the glow shows now
    readonly property var colors: ({
            "3": "#4aa3ff",
            "4": "#b061ff",
            "5": "#ffc83d"
        })
    function colorOf(r) {
        return colors[String(r || 3)];
    }
    readonly property color glowColor: colorOf(glow)
    readonly property string assets: Quickshell.shellDir + "/data/chest/"
    // whole pixels: the chest is 64×56, about a quarter of the screen's height
    readonly property int px: Math.max(2, Math.floor(height * 0.24 / 56))
    readonly property real cx: width / 2
    readonly property real chestY: height * 0.62

    onVisibleChanged: if (visible)
        start()
    onResChanged: if (visible)
        start()
    function start() {
        phase = "idle";
        glow = 3;
        lidFly.stop();
        reelAnim.stop();
        flash.opacity = 0;
        lid.y = 0;
        lid.rotation = 0;
        lid.opacity = 1;
        beam.width = 0;
        fanStep = 0;
        starsShown = 0;
        keys.forceActiveFocus();
    }
    // the next beat: a press in any phase
    function advance() {
        if (phase === "idle")
            shake();
        else if (phase === "shake")
            burst();
        else if (phase === "burst")
            reveal();
        else if (phase === "reel") {
            reelAnim.complete();
        } else if (phase === "fan") {
            fanStep = res.length;
            fanTimer.stop();
            toPrize();
        } else if (phase === "prize") {
            starsShown = 5;
            phase = "done";
        }
    }
    function shake() {
        phase = "shake";
        Sounds.play("chestTick");
        climb.restart();
    }
    function burst() {
        climb.stop();
        glow = Chests.best;
        phase = "burst";
        Sounds.play("chestOpen");
        if (Chests.best >= 5)
            Sounds.play("chestLegend");
        flash.opacity = 0.85;
        flashOut.restart();
        lidFly.restart();
        beamGrow.restart();
        burstWait.restart();
    }
    function reveal() {
        burstWait.stop();
        if (ten) {
            phase = "fan";
            fanTimer.restart();
        } else {
            phase = "reel";
            reelAnim.restart();
        }
    }
    function toPrize() {
        phase = "prize";
        starsShown = 0;
        starTimer.restart();
        Sounds.play(Chests.best >= 5 && !ten ? "chestLegend" : "chestPrize");
    }

    // ---- the glow climbing while it shakes: blue, then maybe purple, then maybe gold ----
    SequentialAnimation {
        id: climb
        PauseAnimation {
            duration: Motion.ms(650)
        }
        ScriptAction {
            script: if (Chests.best >= 4) {
                win.glow = 4;
                Sounds.play("chestTick");
            }
        }
        PauseAnimation {
            duration: Motion.ms(550)
        }
        ScriptAction {
            script: if (Chests.best >= 5) {
                win.glow = 5;
                Sounds.play("chestTick");
            }
        }
        PauseAnimation {
            duration: Motion.ms(450)
        }
        ScriptAction {
            script: win.burst()
        }
    }
    Timer {
        id: burstWait
        interval: Motion.ms(650)
        onTriggered: win.reveal()
    }

    // ---- the backdrop: dark, the rarity's light round the chest, rays turning ----
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.02, 0.01, 0.06, 0.93)
    }
    Item {
        id: rays
        x: win.cx
        y: win.chestY - win.px * 20
        opacity: win.phase === "idle" ? 0.25 : win.phase === "shake" ? 0.5 : 0.85
        Behavior on opacity {
            NumberAnimation {
                duration: Motion.ms(300)
            }
        }
        RotationAnimation on rotation {
            from: 0
            to: 360
            duration: win.phase === "shake" ? 4000 : 16000
            loops: Animation.Infinite
            running: win.visible && !Motion.still
        }
        Repeater {
            model: 12
            Rectangle {
                required property int index
                width: win.px * 22
                height: Math.max(win.width, win.height) * 0.6
                x: -width / 2
                y: 0
                transformOrigin: Item.Top
                rotation: index * 30
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Qt.alpha(win.glowColor, 0.3)
                    }
                    GradientStop {
                        position: 1
                        color: Qt.alpha(win.glowColor, 0)
                    }
                }
            }
        }
    }
    // the light pooled round the chest
    Rectangle {
        width: win.px * 120
        height: width
        radius: width / 2
        x: win.cx - width / 2
        y: win.chestY - win.px * 20 - height / 2
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.alpha(win.glowColor, win.phase === "idle" ? 0.12 : 0.3)
            }
            GradientStop {
                position: 0.5
                color: Qt.alpha(win.glowColor, 0)
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Motion.ms(200)
            }
        }
        scale: win.phase === "shake" ? 1.15 : 1
    }

    // ---- the beam out of the open chest ----
    Rectangle {
        id: beam
        x: win.cx - width / 2
        y: 0
        height: win.chestY - win.px * 22
        width: 0
        visible: width > 0
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.alpha(win.glowColor, 0)
            }
            GradientStop {
                position: 0.7
                color: Qt.alpha(win.glowColor, 0.55)
            }
            GradientStop {
                position: 1
                color: Qt.alpha("#ffffff", 0.9)
            }
        }
        opacity: win.phase === "prize" || win.phase === "done" ? 0.35 : 1
    }
    NumberAnimation {
        id: beamGrow
        target: beam
        property: "width"
        from: 0
        to: win.px * (Chests.best >= 5 ? 40 : Chests.best === 4 ? 30 : 22)
        duration: Motion.ms(350)
        easing.type: Easing.OutBack
    }

    // ---- the chest ----
    Item {
        id: chest
        width: 64 * win.px
        height: 56 * win.px
        x: win.cx - width / 2 + shakeX
        y: win.chestY - height + bob
        property real shakeX: 0
        property real bob: 0
        SequentialAnimation on bob {
            running: win.phase === "idle" && !Motion.still
            loops: Animation.Infinite
            NumberAnimation {
                to: -win.px * 3
                duration: 600
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                to: 0
                duration: 600
                easing.type: Easing.InOutSine
            }
        }
        Timer {
            interval: 30
            repeat: true
            running: win.phase === "shake"
            onTriggered: chest.shakeX = (Math.random() - 0.5) * win.px * (2 + (win.glow - 3) * 2.5)
            onRunningChanged: if (!running)
                chest.shakeX = 0
        }
        Image {
            anchors.fill: parent
            source: "file://" + win.assets + (win.phase === "idle" || win.phase === "shake" ? "chest-closed.png" : "chest-open.png")
            smooth: false
            sourceSize: Qt.size(64, 56)
        }
        // the rarity's light inside the open chest
        Rectangle {
            visible: win.phase !== "idle" && win.phase !== "shake"
            x: 9 * win.px
            y: 27 * win.px
            width: 46 * win.px
            height: 4 * win.px
            color: win.glowColor
            SequentialAnimation on opacity {
                running: parent.visible && !Motion.still
                loops: Animation.Infinite
                NumberAnimation {
                    to: 0.55
                    duration: 500
                }
                NumberAnimation {
                    to: 1
                    duration: 500
                }
            }
        }
        // the lid, flying off at the burst
        Image {
            id: lid
            visible: win.phase === "burst" && opacity > 0
            width: parent.width
            height: parent.height
            source: "file://" + win.assets + "chest-lid.png"
            smooth: false
            sourceSize: Qt.size(64, 56)
        }
        ParallelAnimation {
            id: lidFly
            NumberAnimation {
                target: lid
                property: "y"
                from: 0
                to: -win.height * 0.6
                duration: Motion.ms(650)
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: lid
                property: "rotation"
                from: 0
                to: -40
                duration: Motion.ms(650)
            }
            NumberAnimation {
                target: lid
                property: "opacity"
                from: 1
                to: 0
                duration: Motion.ms(650)
            }
        }
    }
    // sparks rising out of it once open
    Repeater {
        model: win.phase === "idle" || win.phase === "shake" ? 0 : 18
        Rectangle {
            id: spark
            required property int index
            readonly property real seed: (index * 7919) % 97 / 97
            width: win.px * (1 + index % 2)
            height: width
            color: index % 3 === 0 ? "#ffffff" : win.glowColor
            x: win.cx + (seed - 0.5) * win.px * 70
            y: win.chestY - win.px * 26
            NumberAnimation on y {
                from: win.chestY - win.px * 26
                to: win.chestY - win.px * (60 + spark.seed * 80)
                duration: 900 + spark.seed * 900
                loops: Animation.Infinite
                running: !Motion.still
            }
            NumberAnimation on opacity {
                from: 1
                to: 0
                duration: 900 + spark.seed * 900
                loops: Animation.Infinite
                running: !Motion.still
            }
        }
    }

    // ---- ×1: the reel of prizes slowing down onto yours ----
    readonly property int tile: win.px * 22
    readonly property var reelItems: {
        if (!prize)
            return [];
        const pool = HeavenStars.cards.map(c => ({
                    "icon": c.icon,
                    "stars": c.rarity
                })).concat(HeavenStars.skins.map(s => ({
                    "icon": "heart",
                    "stars": s.rarity
                })));
        const out = [];
        // mostly blue ones, a few purple, now and then a gold teaser
        for (let i = 0; i < 34; i++) {
            const want = i % 11 === 7 ? 5 : i % 4 === 1 ? 4 : 3;
            const choices = pool.filter(p => p.stars === want);
            out.push(choices[(i * 31 + 7) % choices.length]);
        }
        out.push({
            "icon": prize.icon,
            "stars": prize.stars,
            "win": true
        });
        for (let i = 0; i < 3; i++)
            out.push(pool[(i * 13) % pool.length]);
        return out;
    }
    readonly property int reelStop: 34
    Item {
        id: reelBox
        visible: win.phase === "reel"
        width: win.tile * 5 + win.px * 8
        height: win.tile + win.px * 8
        x: win.cx - width / 2
        y: win.chestY - win.px * 56 - height
        clip: true
        Rectangle {
            anchors.fill: parent
            color: "#120a24"
            border.width: win.px
            border.color: win.glowColor
        }
        Row {
            id: strip
            y: win.px * 4
            x: win.px * 4
            spacing: 0
            property real offset: 0
            transform: Translate {
                x: -strip.offset
            }
            property int lastIdx: -1
            onOffsetChanged: {
                const i = Math.floor(offset / win.tile);
                if (i !== lastIdx) {
                    lastIdx = i;
                    Sounds.play("chestTick");
                }
            }
            Repeater {
                model: win.reelItems
                Item {
                    required property var modelData
                    width: win.tile
                    height: win.tile
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: win.px * 2
                        color: Qt.alpha(win.colorOf(parent.modelData.stars), 0.28)
                        border.width: win.px
                        border.color: win.colorOf(parent.modelData.stars)
                    }
                    PxIcon {
                        anchors.centerIn: parent
                        name: parent.modelData.icon
                        pixel: Math.max(1, Math.floor(win.px * 0.9))
                        fill: win.colorOf(parent.modelData.stars)
                    }
                }
            }
        }
        // the frame in the middle: what it stops on
        Rectangle {
            x: win.px * 4 + win.tile * 2
            y: win.px * 2
            width: win.tile
            height: win.tile + win.px * 4
            color: "transparent"
            border.width: win.px
            border.color: "#ffffff"
        }
    }
    NumberAnimation {
        id: reelAnim
        target: strip
        property: "offset"
        from: 0
        to: (win.reelStop - 2) * win.tile
        duration: Motion.still ? 0 : 2600
        easing.type: Easing.OutQuint
        onFinished: if (win.phase === "reel")
            win.toPrize()
    }

    // ---- ×10: the cards fly out of the chest and turn over ----
    property int fanStep: 0
    Timer {
        id: fanTimer
        interval: Motion.still ? 1 : 170
        repeat: true
        onTriggered: {
            win.fanStep++;
            Sounds.play("chestTick");
            if (win.fanStep >= win.res.length) {
                stop();
                win.toPrize();
            }
        }
    }
    Grid {
        id: fan
        visible: win.ten && (win.phase === "fan" || win.phase === "prize" || win.phase === "done")
        columns: 5
        spacing: win.px * 4
        x: win.cx - width / 2
        y: win.height * 0.1
        Repeater {
            model: win.ten ? win.res : []
            Item {
                id: card
                required property var modelData
                required property int index
                readonly property bool out: index < win.fanStep
                width: win.px * 34
                height: win.px * 46
                opacity: out ? 1 : 0
                scale: out ? 1 : 0.2
                Behavior on scale {
                    NumberAnimation {
                        duration: Motion.ms(260)
                        easing.type: Easing.OutBack
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: Motion.ms(160)
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    color: "#160c2a"
                    border.width: win.px
                    border.color: win.colorOf(card.modelData.stars)
                }
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: win.px * 2
                    color: Qt.alpha(win.colorOf(card.modelData.stars), card.modelData.stars >= 5 ? 0.4 : 0.2)
                }
                PxIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: win.px * 6
                    name: card.modelData.icon
                    pixel: win.px
                    fill: win.colorOf(card.modelData.stars)
                }
                PxText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height - win.px * 18
                    width: parent.width - win.px * 4
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    kind: "tiny"
                    color: "#ffffff"
                    text: card.modelData.name
                }
                PxText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height - win.px * 10
                    kind: "tiny"
                    color: win.colorOf(card.modelData.stars)
                    text: "★".repeat(card.modelData.stars) + (card.modelData.fresh ? " NEW" : "")
                }
            }
        }
    }

    // ---- the prize ----
    property int starsShown: 0
    Timer {
        id: starTimer
        interval: Motion.still ? 1 : 140
        repeat: true
        onTriggered: {
            win.starsShown++;
            if (win.starsShown >= (win.prize ? win.prize.stars : 3)) {
                stop();
                win.phase = "done";
            }
        }
    }
    Column {
        id: prizeCard
        visible: !win.ten && (win.phase === "prize" || win.phase === "done") && win.prize !== null
        anchors.horizontalCenter: parent.horizontalCenter
        y: win.chestY - win.px * 60 - height
        spacing: win.px * 3
        scale: visible ? 1 : 0.3
        Behavior on scale {
            NumberAnimation {
                duration: Motion.ms(300)
                easing.type: Easing.OutBack
            }
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: win.px * 40
            height: width
            color: Qt.alpha(win.glowColor, 0.25)
            border.width: win.px
            border.color: win.glowColor
            PxIcon {
                anchors.centerIn: parent
                name: win.prize ? win.prize.icon : "heart"
                pixel: win.px * 2
                fill: win.glowColor
            }
        }
        PxText {
            anchors.horizontalCenter: parent.horizontalCenter
            kind: "huge"
            color: win.glowColor
            text: "★".repeat(win.starsShown)
            style: Text.Outline
            styleColor: "#000000"
        }
        PxText {
            anchors.horizontalCenter: parent.horizontalCenter
            kind: "big"
            color: "#ffffff"
            font.bold: true
            text: win.prize ? win.prize.name : ""
        }
        PxText {
            anchors.horizontalCenter: parent.horizontalCenter
            kind: "title"
            color: win.prize && win.prize.fresh ? win.glowColor : "#c8c0e0"
            text: !win.prize ? "" : (win.prize.kind === "skin" ? I18n.t("скин ангела", "the angel's skin") : I18n.t("карточка в альбом", "a card for the album")) + (win.prize.fresh ? I18n.t(" · НОВОЕ!", " · NEW!") : I18n.t(" · повтор +%1 ✦", " · duplicate +%1 ✦").arg(win.prize.refund))
        }
    }

    // ---- the words and the buttons ----
    PxText {
        visible: win.phase === "idle"
        anchors.horizontalCenter: parent.horizontalCenter
        y: win.chestY + win.px * 8
        kind: "big"
        color: "#ffffff"
        text: win.ten ? I18n.t("Десять сундуков — жми!", "Ten chests — press!") : Chests.source === "lock" ? I18n.t("Молитва при входе — открой!", "The unlock's prayer — open it!") : Chests.source === "free" ? I18n.t("Сундук дня — открой!", "The day's chest — open it!") : I18n.t("Сундук Небес — открой!", "Heaven's chest — open it!")
        SequentialAnimation on opacity {
            running: win.phase === "idle" && !Motion.still
            loops: Animation.Infinite
            NumberAnimation {
                to: 0.4
                duration: 700
            }
            NumberAnimation {
                to: 1
                duration: 700
            }
        }
    }
    Row {
        visible: win.phase === "done"
        anchors.horizontalCenter: parent.horizontalCenter
        y: win.chestY + win.px * 8
        spacing: win.px * 4
        PxButton {
            kind: "title"
            accent: true
            icon: "sparkleStar"
            enabled: Chests.freeReady || HeavenStars.stars >= Chests.cost
            text: Chests.freeReady ? I18n.t("Ещё: сундук дня", "Another: the day's chest") : I18n.t("Ещё сундук · %1 ✦", "Another · %1 ✦").arg(Chests.cost)
            onClicked: {
                Chests.open = false;
                Chests.openOne();
            }
        }
        PxButton {
            kind: "title"
            icon: "sparkle"
            enabled: HeavenStars.stars >= Chests.cost * 10
            text: I18n.t("×10 · %1 ✦", "×10 · %1 ✦").arg(Chests.cost * 10)
            onClicked: {
                Chests.open = false;
                Chests.openTen();
            }
        }
        PxButton {
            kind: "title"
            text: I18n.t("Закрыть", "Close")
            onClicked: Chests.close()
        }
    }
    PxText {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: win.px * 6
        kind: "tiny"
        color: "#a89cc8"
        text: I18n.t("✦ %1 · сундуков доступно: %2 · любая клавиша — дальше, Esc — закрыть", "✦ %1 · chests available: %2 · any key: next, Esc: close").arg(HeavenStars.stars).arg(Chests.count)
    }

    // the flash of the burst
    Rectangle {
        id: flash
        anchors.fill: parent
        color: Chests.best >= 5 ? "#fff3c4" : "#ffffff"
        opacity: 0
    }
    NumberAnimation {
        id: flashOut
        target: flash
        property: "opacity"
        to: 0
        duration: Motion.ms(500)
        easing.type: Easing.OutQuad
    }

    // presses: the next beat; Esc closes (not while it is still closed: a misclick)
    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                if (win.phase !== "idle" && win.phase !== "shake" && win.phase !== "burst")
                    Chests.close();
            } else if (win.phase !== "done")
                win.advance();
            event.accepted = true;
        }
    }
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: if (win.phase !== "done")
            win.advance()
    }
    RightClickGuard {}
}
