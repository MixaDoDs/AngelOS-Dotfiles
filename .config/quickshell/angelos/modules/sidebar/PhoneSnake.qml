pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// Snake on the phone's screen (PhoneScreen): 2 4 6 8 or the arrows, 5 or OK to start and to
// pause. The walls wrap round, like the 3310's; it speeds up as it grows. The best score is
// the save's (save.json → phone.snake); 30 is an achievement. Runs only while the lid is up.
Item {
    id: root

    required property var phone
    readonly property int k: Theme.u
    readonly property int cols: 22
    readonly property int rows: 15
    readonly property real cell: Math.max(1, Math.floor(Math.min(width / cols, (height - k * 10) / rows)))
    readonly property color ink: phone.screenInk

    property var snake: []
    property var dir: [1, 0]
    property var want: [1, 0]
    property var food: [10, 7]
    property int score: 0
    property string state: "ready"             // ready | play | pause | over
    readonly property int best: Story.phone ? Story.phone.snake || 0 : 0
    readonly property var soft: ["", state === "play" ? I18n.t("Пауза", "Pause") : I18n.t("Играть", "Play"), I18n.t("Выход", "Exit")]

    function reset() {
        snake = [[6, 7], [5, 7], [4, 7]];
        dir = [1, 0];
        want = [1, 0];
        score = 0;
        place();
    }
    function place() {
        for (let n = 0; n < 200; n++) {
            const f = [Math.floor(Math.random() * cols), Math.floor(Math.random() * rows)];
            if (!snake.some(s => s[0] === f[0] && s[1] === f[1])) {
                food = f;
                return;
            }
        }
    }
    function turn(d) {
        // no turning straight back into itself
        if (d[0] !== -dir[0] || d[1] !== -dir[1])
            want = d;
    }
    function key(k) {
        const d = {
            "2": [0, -1],
            "up": [0, -1],
            "8": [0, 1],
            "down": [0, 1],
            "4": [-1, 0],
            "left": [-1, 0],
            "6": [1, 0],
            "right": [1, 0]
        }[k];
        if (d) {
            if (state === "play")
                turn(d);
            return true;
        }
        if (k === "5" || k === "ok" || k === "call") {
            if (state === "ready" || state === "over") {
                reset();
                state = "play";
            } else
                state = state === "play" ? "pause" : "play";
            return true;
        }
        return false;
    }
    Component.onCompleted: reset()
    Timer {
        interval: Math.max(70, 170 - root.score * 3)
        running: root.state === "play" && root.visible && Sidebar.open
        repeat: true
        onTriggered: root.step()
    }
    function step() {
        dir = want;
        const h = snake[0];
        const n = [(h[0] + dir[0] + cols) % cols, (h[1] + dir[1] + rows) % rows];
        if (snake.some((s, i) => i < snake.length - 1 && s[0] === n[0] && s[1] === n[1])) {
            state = "over";
            PhoneLine.play("die", 0.6);
            if (score > best && Story.phone)
                Story.phone.snake = score;
            if (score >= 30)
                Achievements.note("phone.snake30");
            canvas.requestPaint();
            return;
        }
        const ate = n[0] === food[0] && n[1] === food[1];
        snake = [n].concat(ate ? snake : snake.slice(0, -1));
        if (ate) {
            score++;
            PhoneLine.play("eat", 0.5);
            place();
        }
        canvas.requestPaint();
    }

    Row {
        id: bar
        width: parent.width
        PxText {
            width: parent.width / 2
            text: I18n.t("Счёт ", "Score ") + root.score
            kind: "tiny"
            color: root.ink
        }
        PxText {
            width: parent.width / 2
            horizontalAlignment: Text.AlignRight
            text: I18n.t("Рекорд ", "Best ") + root.best
            kind: "tiny"
            color: root.phone.trim
        }
    }
    Canvas {
        id: canvas
        anchors.horizontalCenter: parent.horizontalCenter
        y: bar.height + root.k
        width: root.cols * root.cell + 2
        height: root.rows * root.cell + 2
        renderStrategy: Canvas.Cooperative
        onPaint: {
            const c = getContext("2d"), s = root.cell;
            c.reset();
            c.fillStyle = Qt.alpha(root.phone.trim, 0.12);
            c.fillRect(0, 0, width, height);
            c.strokeStyle = root.phone.trim;
            c.lineWidth = 1;
            c.strokeRect(0.5, 0.5, width - 1, height - 1);
            c.fillStyle = root.ink;
            for (const p of root.snake)
                c.fillRect(1 + p[0] * s, 1 + p[1] * s, s - 1, s - 1);
            c.fillStyle = root.phone.trim;
            c.fillRect(1 + root.food[0] * s, 1 + root.food[1] * s, s - 1, s - 1);
        }
        Component.onCompleted: requestPaint()
    }
    PxText {
        visible: root.state !== "play"
        anchors.centerIn: canvas
        horizontalAlignment: Text.AlignHCenter
        text: root.state === "over" ? I18n.t("Конец игры\nСчёт: ", "Game over\nScore: ") + root.score + "\n" + I18n.t("5 — ещё раз", "5 to play again") : root.state === "pause" ? I18n.t("Пауза", "Paused") : I18n.t("ЗМЕЙКА\n5 — начать\n2 4 6 8 — рулить", "SNAKE\n5 to start\n2 4 6 8 to steer")
        kind: "tiny"
        color: root.ink
        style: Text.Outline
        styleColor: root.phone.hell ? Theme.hellBody : Theme.face
    }
}
