pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets
import "../../bar/parts/RunnerSprites.js" as Sprites

// The race of the stream's chat (services/StreamChat.race, scripts/stream-chat.py): a pixel race
// track of its own for every stream — the session's name is the seed, so the same stream keeps
// its track through a restart, the next one gets a new one (its shape, the land around it, the
// name) — and the writers as little cats on it, the further the more they wrote (the leader near
// the finish), in each viewer's colour (StreamChat.furOf: «!pink» in the chat picks it).
//   S  the track and the first three
//   M  the track, the first five
//   L  a bigger track, the first ten
Item {
    id: root

    property string screenName
    property var widget
    property string size: "m"
    property string frameKind: "window"
    property bool face: true
    readonly property bool passive: true

    readonly property bool hellish: Theme.hell
    readonly property color ink: hellish ? Theme.hellText : Theme.text
    readonly property color inkDim: hellish ? Theme.hellTextDim : Theme.textDim
    readonly property var race: StreamChat.race
    readonly property var leaders: race ? (race.top || []).slice(0, size === "s" ? 3 : size === "l" ? 10 : 5) : []
    readonly property int lead: leaders.length ? Math.max(1, leaders[0][1]) : 1
    readonly property var medal: ["#ffd23f", "#d8e0ec", "#e0904a"]

    // the track, in art pixels (one art pixel = Theme.u)
    readonly property int cols: size === "s" ? 110 : size === "l" ? 190 : 150
    readonly property int rows: size === "s" ? 46 : size === "l" ? 72 : 58
    readonly property var track: build(race ? race.session : "warm-up", cols, rows)

    implicitWidth: cols * Theme.u
    implicitHeight: col.implicitHeight

    // ---- the track generator ----
    function seedOf(s) {
        let h = 2166136261;
        s = String(s);
        for (let i = 0; i < s.length; i++)
            h = Math.imul(h ^ s.charCodeAt(i), 16777619);
        return h >>> 0;
    }
    function rng(seed) {
        // mulberry32
        let a = seed >>> 0;
        return () => {
            a = (a + 0x6D2B79F5) >>> 0;
            let t = a;
            t = Math.imul(t ^ (t >>> 15), t | 1);
            t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
            return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
        };
    }
    // the land around: ground g, road a, its middle line l, curbs c/v, the finish k/z; the rest are
    // the land's own things, drawn small from its `things`
    readonly property var lands: [
        {
            "ru": "луг",
            "en": "meadow",
            "colors": {
                "g": "#3d6b3a",
                "a": "#45454f",
                "l": "#f2f2f2",
                "c": "#e04848",
                "v": "#f2f2f2",
                "t": "#2a8a3a",
                "b": "#7a5230",
                "f": "#ffd84d",
                "p": "#ff7eb6"
            },
            "things": [[".t.", "ttt", "ttt", ".b."], ["tt", "tt"], ["f"], ["p"], [".t.", "ttt", ".b."]]
        },
        {
            "ru": "пустыня",
            "en": "desert",
            "colors": {
                "g": "#d6b06a",
                "a": "#6e5b4a",
                "l": "#fff1c4",
                "c": "#b8452f",
                "v": "#f0dfb0",
                "t": "#4f9a4a",
                "r": "#8d7a66",
                "b": "#e8c98a"
            },
            "things": [[".t.", "tt.", ".tt", ".t."], ["t.t", "ttt", ".t."], [".r.", "rrr"], ["b"], ["bb"]]
        },
        {
            "ru": "неон",
            "en": "neon",
            "colors": {
                "g": "#15132b",
                "a": "#2b2848",
                "l": "#ff4fd8",
                "c": "#5fe0ff",
                "v": "#ff4fd8",
                "s": "#fff3a0",
                "n": "#7dffc8",
                "m": "#b07cff"
            },
            "things": [["s"], [".s.", "sss", ".s."], ["nnn", "n.n"], ["m", "m", "m"], ["n"]]
        },
        {
            "ru": "снег",
            "en": "snow",
            "colors": {
                "g": "#dfe8f0",
                "a": "#5a616c",
                "l": "#ffd84d",
                "c": "#d84a4a",
                "v": "#ffffff",
                "t": "#2f6d4a",
                "b": "#6b4a30",
                "r": "#9fb0c0"
            },
            "things": [[".t.", "ttt", ".t.", "ttt", ".b."], [".r.", "rrr"], ["r"], [".t.", "ttt", ".b."]]
        },
        {
            "ru": "лава",
            "en": "lava",
            "colors": {
                "g": "#2a1010",
                "a": "#3d2222",
                "l": "#ff7a1a",
                "c": "#ff3b1f",
                "v": "#ffd23f",
                "s": "#e8dccb",
                "o": "#ff7a1a",
                "y": "#ffd23f"
            },
            "things": [["sss", "s.s", ".s."], [".o.", "oyo", "oyo"], ["o"], ["yo"]]
        }
    ]
    readonly property var adjectives: [["Кошачий", "Cat"], ["Мурчащий", "Purring"], ["Хвостатый", "Tail"], ["Ночной", "Night"], ["Бешеный", "Mad"], ["Пушистый", "Fluffy"], ["Лунный", "Moon"], ["Голодный", "Hungry"], ["Сонный", "Sleepy"], ["Турбо", "Turbo"]]
    readonly property var nouns: [["серпантин", "Serpentine"], ["дрифт", "Drift"], ["круг", "Loop"], ["каньон", "Canyon"], ["трек", "Track"], ["тоннель", "Tunnel"], ["виток", "Coil"], ["разгон", "Rush"]]

    function build(session, W, H) {
        const R = rng(seedOf(session));
        const land = lands[Math.floor(R() * lands.length)];
        const adj = adjectives[Math.floor(R() * adjectives.length)], noun = nouns[Math.floor(R() * nouns.length)];
        const k1 = 2 + Math.floor(R() * 2), k2 = k1 + 1 + Math.floor(R() * 2);
        const a1 = 0.12 + R() * 0.14, a2 = 0.05 + R() * 0.1, p1 = R() * 6.283, p2 = R() * 6.283;
        const cx = W / 2, cy = H / 2, rx = W / 2 - 6, ry = H / 2 - 6;
        // the middle of the road: a closed loop, pinched here and there
        const path = [];
        for (let i = 0; i < 480; i++) {
            const th = i / 480 * 6.283;
            const r = 1 - a1 * (0.5 + 0.5 * Math.sin(k1 * th + p1)) - a2 * (0.5 + 0.5 * Math.sin(k2 * th + p2));
            const x = Math.round(cx + rx * r * Math.cos(th)), y = Math.round(cy + ry * r * Math.sin(th));
            const last = path[path.length - 1];
            if (!last || last[0] !== x || last[1] !== y)
                path.push([x, y]);
        }
        const g = [];
        for (let y = 0; y < H; y++)
            g.push(new Array(W).fill("g"));
        const near = new Uint8Array(W * H);
        function disk(x0, y0, rad, put) {
            for (let y = y0 - rad; y <= y0 + rad; y++)
                for (let x = x0 - rad; x <= x0 + rad; x++)
                    if (x >= 0 && y >= 0 && x < W && y < H && (x - x0) * (x - x0) + (y - y0) * (y - y0) <= rad * rad + 1)
                        put(x, y);
        }
        path.forEach((p, i) => disk(p[0], p[1], 7, (x, y) => near[y * W + x] = 1));
        path.forEach((p, i) => disk(p[0], p[1], 4, (x, y) => g[y][x] = Math.floor(i / 3) % 2 ? "c" : "v"));
        path.forEach(p => disk(p[0], p[1], 3, (x, y) => g[y][x] = "a"));
        path.forEach((p, i) => {
            if (i % 8 < 4)
                g[p[1]][p[0]] = "l";
        });
        // the finish across the road where the loop starts (its right side, the road going down)
        const f = path[0];
        for (let y = f[1] - 1; y <= f[1] + 1; y++)
            for (let x = f[0] - 3; x <= f[0] + 3; x++)
                if (y >= 0 && y < H && x >= 0 && x < W)
                    g[y][x] = (x + y) % 2 ? "k" : "z";
        // the land's things, away from the road
        for (let n = 0; n < W * H / 120; n++) {
            const t = land.things[Math.floor(R() * land.things.length)];
            const x0 = Math.floor(R() * (W - 4)), y0 = Math.floor(R() * (H - 5));
            let free = true;
            for (let y = 0; y < t.length && free; y++)
                for (let x = 0; x < t[y].length && free; x++)
                    free = !near[(y0 + y) * W + x0 + x] && g[y0 + y][x0 + x] === "g";
            if (!free)
                continue;
            for (let y = 0; y < t.length; y++)
                for (let x = 0; x < t[y].length; x++)
                    if (t[y][x] !== ".")
                        g[y0 + y][x0 + x] = t[y][x];
        }
        return {
            "rows": g.map(r => r.join("")),
            "path": path,
            "colors": Object.assign({
                "k": "#111111",
                "z": "#f5f5f5"
            }, land.colors),
            "name": I18n.t(adj[0] + " " + noun[0], adj[1] + " " + noun[1]),
            "land": I18n.t(land.ru, land.en)
        };
    }

    // the cats' legs move only while the stream is on and someone is racing
    property int tick: 0
    Timer {
        interval: 140
        repeat: true
        running: root.visible && StreamMode.onAir && root.leaders.length > 0
        onTriggered: root.tick++
    }

    Column {
        id: col
        width: root.width
        spacing: Theme.u * 3

        Row {
            width: parent.width
            spacing: Theme.u * 3
            PxText {
                id: title
                kind: "title"
                color: root.ink
                text: root.track.name
            }
            PxText {
                anchors.baseline: title.baseline
                width: parent.width - title.width - parent.spacing
                elide: Text.ElideRight
                kind: "tiny"
                color: root.inkDim
                text: root.track.land + (root.race ? " · " + I18n.t("пишут: ", "writing: ") + root.race.writers : "")
            }
        }

        Item {
            width: parent.width
            height: root.rows * Theme.u
            PxIcon {
                bitmap: root.track.rows
                palette: root.track.colors
                pixel: Theme.u
            }
            // the racers, the last first so the leader is drawn on top
            Repeater {
                model: root.leaders.slice().reverse()
                PxIcon {
                    id: cat
                    required property var modelData
                    required property int index
                    readonly property int place: root.leaders.length - 1 - index
                    readonly property var path: root.track.path
                    // the leader near the finish, the others as far as their messages took them
                    // (the ones level: one behind the other)
                    property real at: Math.max(0, Math.min(0.9, 0.9 * modelData[1] / root.lead) * (path.length - 1) - place * 6)
                    Behavior on at {
                        NumberAnimation {
                            duration: 1400
                            easing.type: Easing.OutCubic
                        }
                    }
                    readonly property var p: path[Math.round(at)] || [0, 0]
                    readonly property var q: path[Math.min(path.length - 1, Math.round(at) + 3)] || p
                    // a lane each: the ones level don't stand on each other
                    readonly property int lane: place % 3 - 1
                    readonly property real nx: -(q[1] - p[1])
                    readonly property real ny: q[0] - p[0]
                    readonly property real nl: Math.max(1, Math.hypot(nx, ny))
                    bitmap: Sprites.run[(root.tick + place) % 4]
                    pixel: Theme.u
                    ink: StreamChat.furOf(modelData[0], modelData[2])
                    x: (p[0] + lane * 2 * nx / nl) * Theme.u - width / 2
                    y: (p[1] + lane * 2 * ny / nl) * Theme.u - height + Theme.u * 2
                    // facing the way it goes
                    transform: Scale {
                        origin.x: cat.width / 2
                        xScale: cat.q[0] < cat.p[0] ? -1 : 1
                    }
                }
            }
            PxText {
                visible: !root.leaders.length
                anchors.centerIn: parent
                kind: "tiny"
                color: "#ffffff"
                style: Text.Outline
                styleColor: "#000000"
                text: I18n.t("Старт — с первым сообщением в чате", "Starts with the first chat message")
            }
        }

        // the table
        Repeater {
            model: root.leaders
            Row {
                id: line
                required property var modelData
                required property int index
                width: col.width
                spacing: Theme.u * 3
                PxText {
                    id: num
                    width: Theme.u * 14
                    kind: "tiny"
                    color: line.index < 3 ? root.medal[line.index] : root.inkDim
                    text: "#" + (line.index + 1)
                }
                PxIcon {
                    id: face
                    anchors.verticalCenter: parent.verticalCenter
                    bitmap: Sprites.run[0]
                    pixel: Math.max(1, Theme.u - 1)
                    ink: StreamChat.furOf(line.modelData[0], line.modelData[2])
                }
                PxText {
                    width: line.width - num.width - face.width - count.width - line.spacing * 3
                    elide: Text.ElideRight
                    kind: "tiny"
                    color: root.ink
                    text: line.modelData[0]
                }
                PxText {
                    id: count
                    kind: "tiny"
                    color: root.ink
                    text: "×" + line.modelData[1]
                }
            }
        }

        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            kind: "tiny"
            color: root.inkDim
            text: I18n.t("Цвет своего кота — в чат: !розовый, !blue, !#ff66cc", "Your cat's colour — in the chat: !pink, !синий, !#ff66cc")
        }
    }
}
