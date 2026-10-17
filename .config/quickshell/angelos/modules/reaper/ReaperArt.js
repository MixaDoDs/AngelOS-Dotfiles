.pragma library

// The pictures of «Смерть на смене» (ReaperWindow): Death's office on a 200×112 art-pixel grid —
// Heaven's door on the left, Hell's on the right, the hatch to Limbo in the floor, the door the
// queue comes through, the Boss's eye on the monitor — and everyone in it. Rows in the Icons.js
// alphabet for PxIcon, each char a colour of `colors` ('.' nothing); the room is built in code,
// the people drawn by hand. tests/reaper/run.sh checks the sizes.

const W = 200, H = 112;

// a fixed night palette: the game is a picture in its own frame, not the theme's
const colors = {
    "#": "#0e0b14",
    "a": "#2b2342", "b": "#342a4e", "c": "#221a35", "C": "#1a1428",
    "d": "#3b2f52", "e": "#33284a",
    "g": "#e8c25a", "G": "#a8842e",
    "h": "#fff4c8", "H": "#ffe08a",
    "j": "#7a1a26", "J": "#521019", "k": "#2a2430",
    "l": "#2a0810", "L": "#c0391b",
    "m": "#4a4460", "M": "#2e2a3c", "n": "#0f0d16", "N": "#1a1722",
    "p": "#e9e2cf", "q": "#5a3d2b", "Q": "#3d2a1e", "u": "#7a5640",
    "s": "#d6e0f5", "t": "#8f9abb",
    "z": "#1b1626", "Z": "#3c3356", "Y": "#ece4cf",
    "K": "#c9cfdc", "O": "#f0a040", "B": "#4fae6a", "P": "#4f7a3c", "R": "#8c1424",
    "r": "#e0303a", "y": "#ffd85a", "F": "#ff9a2a", "o": "#ff8ab8", "x": "#2a1d4a",
    "w": "#ffffff", "v": "#6d6585", "V": "#a39bbb", "T": "#efe6d0"
};
// soul tints by look (the 's' of a soul): blue, green, lilac
const tints = ["#d6e0f5", "#d8f0da", "#eadcf7"];

// where things stand, [x, y(, w, h)] in art pixels
const at = {
    "heaven": [12, 8, 31, 56],
    "hell": [157, 8, 31, 56],
    "back": [88, 26, 25, 38],
    "screen": [85, 5, 31, 15],
    "clock": [62, 10],
    "candle": [36, 82],
    "hatch": [88, 80, 25, 6],
    "stand": [91, 56],          // a soul (18×24) in front of Death
    "queue": [91, 39],          // the next one, in the back door
    "death": [85, 87],
    "scythe": [66, 38],
    "bubble": [114, 40]
};

// ---- drawing on a grid ----
function grid(w, h, c) {
    const g = [];
    for (let y = 0; y < h; y++)
        g.push(new Array(w).fill(c));
    return g;
}
function set(g, x, y, c) {
    if (y >= 0 && y < g.length && x >= 0 && x < g[0].length)
        g[y][x] = c;
}
function fill(g, x, y, w, h, c) {
    for (let j = y; j < y + h; j++)
        for (let i = x; i < x + w; i++)
            set(g, i, j, c);
}
function stamp(g, x, y, rows) {
    for (let j = 0; j < rows.length; j++)
        for (let i = 0; i < rows[j].length; i++)
            if (rows[j][i] !== ".")
                set(g, x + i, y + j, rows[j][i]);
}
// a door's shape: a rectangle with a round top
function inArch(i, j, w) {
    const r = (w - 1) / 2, dy = j - r;
    return dy >= 0 || (i - r) * (i - r) + dy * dy <= r * r + r * 0.5;
}
function arch(g, x, y, w, h, c) {
    for (let j = 0; j < h; j++)
        for (let i = 0; i < w; i++)
            if (inArch(i, j, w))
                set(g, x + i, y + j, c);
}
function rows(g) {
    return g.map(r => r.join(""));
}
function ellipse(g, cx, cy, a, b, c) {
    for (let j = 0; j < g.length; j++)
        for (let i = 0; i < g[0].length; i++)
            if (((i - cx) / a) ** 2 + ((j - cy) / b) ** 2 <= 1)
                g[j][i] = c;
}

// ---- the room ----
let _room = null;
function room() {
    if (_room)
        return _room;
    const g = grid(W, H, "a");
    // wallpaper dots, wainscot, floor tiles
    for (let y = 4; y < 50; y += 8)
        for (let x = (y / 8 % 2) * 4 + 2; x < W; x += 8)
            set(g, x, y, "b");
    fill(g, 0, 50, W, 14, "c");
    fill(g, 0, 50, W, 1, "C");
    for (let x = 5; x < W; x += 10)
        fill(g, x, 51, 1, 13, "C");
    fill(g, 0, 64, W, H - 64, "d");
    fill(g, 0, 64, W, 1, "C");
    [70, 78, 88].forEach((y, n) => {
        fill(g, 0, y, W, 1, "e");
        for (let x = n * 7; x < W; x += 22)
            fill(g, x, y + 1, 1, [7, 9, 8][n], "e");
    });
    // Heaven: gold frame, light inside (its rays: heavenLight); Hell: iron frame, embers
    const [hx, hy, hw, hh] = at.heaven;
    arch(g, hx - 1, hy - 1, hw + 2, hh + 1, "#");
    arch(g, hx, hy, hw, hh, "g");
    arch(g, hx + 2, hy + 2, hw - 4, hh - 2, "G");
    arch(g, hx + 3, hy + 3, hw - 6, hh - 3, "h");
    const [fx, fy, fw, fh] = at.hell;
    arch(g, fx - 1, fy - 1, fw + 2, fh + 1, "#");
    arch(g, fx, fy, fw, fh, "k");
    for (let j = 0; j < fh; j += 4)
        for (let i = (j / 4 % 2) * 3; i < fw; i += 6)
            if (inArch(i, j, fw))
                set(g, fx + i, fy + j, "M");
    arch(g, fx + 3, fy + 3, fw - 6, fh - 3, "l");
    fill(g, fx + 3, fy + fh - 6, fw - 6, 6, "J");
    // the back door, the queue comes out of it; a lamp over it
    const [bx, by, bw, bh] = at.back;
    fill(g, bx - 1, by - 1, bw + 2, bh + 1, "#");
    fill(g, bx, by, bw, bh, "M");
    fill(g, bx + 2, by + 2, bw - 4, bh - 2, "n");
    // the Boss's monitor, hanging on a cable
    fill(g, 100, 0, 1, 2, "M");
    fill(g, 82, 2, 37, 21, "#");
    fill(g, 83, 3, 35, 19, "m");
    fill(g, 84, 21, 33, 1, "M");
    fill(g, 112, 20, 3, 1, "r");
    // the clock's case (its face: clock()), «employee of the month» (a skull, of course)
    fill(g, at.clock[0] - 1, at.clock[1] - 1, 15, 15, "Q");
    fill(g, 130, 8, 16, 20, "q");
    fill(g, 131, 9, 14, 18, "p");
    stamp(g, 134, 10, ["..####..", ".#YYYY#.", "#Y##Y##Y", "#Y##Y##Y", "#YYYYYYY", ".#Y#Y#Y.", "..#####."].map(r => r.length < 8 ? r + "." : r));
    fill(g, 133, 20, 10, 1, "t");
    fill(g, 133, 22, 7, 1, "t");
    fill(g, 133, 24, 9, 1, "t");
    // the hatch in the floor
    const [ax, ay, aw, ah] = at.hatch;
    const hatch = grid(aw, ah, ".");
    ellipse(hatch, (aw - 1) / 2, (ah - 1) / 2, aw / 2, ah / 2, "M");
    ellipse(hatch, (aw - 1) / 2, (ah - 1) / 2, aw / 2 - 2, ah / 2 - 1, "k");
    stamp(g, ax, ay, rows(hatch));
    fill(g, ax + 12, ay + 1, 1, ah - 2, "M");
    // the desk across the bottom: papers, a stamp, a candle
    fill(g, 0, 95, W, 1, "#");
    fill(g, 0, 96, W, 2, "u");
    fill(g, 0, 98, W, 1, "Q");
    fill(g, 0, 99, W, H - 99, "q");
    for (let x = 24; x < W; x += 50)
        fill(g, x, 99, 1, H - 99, "Q");
    fill(g, 0, 104, W, 1, "Q");
    stamp(g, 150, 88, ["#############", "#ppppppppppp#", "#pttttttttp#.", "#ppppppppppp#", "#ptttttttppp#", "#ppppppppppp#", "#pttttppppp#.", "#############"]);
    stamp(g, 170, 86, ["..##..", ".#qq#.", ".#qq#.", "..qq..", "######", "#rrrr#", "######", "......", "......"]);
    stamp(g, at.candle[0] - 2, 94, ["#######", "#QQQQQ#"]);
    fill(g, at.candle[0], 88, 3, 6, "T");
    fill(g, at.candle[0] - 1, 88, 1, 6, "#");
    fill(g, at.candle[0] + 3, 88, 1, 6, "#");
    _room = rows(g);
    return _room;
}

// Heaven's light behind its door: rays that slide (`phase`), clouds at the bottom
function heavenLight(phase) {
    const [, , w, h] = at.heaven;
    const g = grid(w - 6, h - 3, ".");
    for (let j = 0; j < g.length; j++)
        for (let i = 0; i < g[0].length; i++)
            if (inArch(i, j, w - 6))
                g[j][i] = (i + j + phase * 2) % 7 < 2 ? "H" : "h";
    stamp(g, 0, g.length - 6, ["...ww......ww....ww..ww.", ".wwwww...wwwwww.wwwwwww..", "wwwwwwwwwwwwwwwwwwwwwwwww", "wwwwwwwwwwwwwwwwwwwwwwwww", "wwwwwwwwwwwwwwwwwwwwwwwww", "wwwwwwwwwwwwwwwwwwwwwwwww"]);
    return rows(g);
}
// the doors themselves, shut: Heaven's pale with a gold cross, Hell's planks and iron bands
let _doors = null;
function doors() {
    if (_doors)
        return _doors;
    const w = at.heaven[2] - 6, h = at.heaven[3] - 3;
    const sky = grid(w, h, ".");
    arch(sky, 0, 0, w, h, "p");
    for (let j = 0; j < h; j++)
        set(sky, (w - 1) / 2, j, sky[j][(w - 1) / 2] === "p" ? "T" : ".");
    stamp(sky, (w - 1) / 2 - 3, 12, ["...gg...", "...gg...", "gggggggg", "gggggggg", "...gg...", "...gg...", "...gg...", "...gg..."].map(r => r.slice(0, 7) + (r.length > 7 ? "" : "")));
    fill(sky, 3, 30, w - 6, 1, "T");
    fill(sky, 3, 42, w - 6, 1, "T");
    fill(sky, w - 5, 34, 2, 2, "G");
    const fire = grid(w, h, ".");
    arch(fire, 0, 0, w, h, "j");
    for (let i = 3; i < w; i += 4)
        for (let j = 0; j < h; j++)
            if (fire[j][i] === "j")
                fire[j][i] = "J";
    [10, 26, 44].forEach(y => {
        fill(fire, 0, y, w, 2, "k");
        for (let i = 2; i < w; i += 5)
            set(fire, i, y, "K");
    });
    fill(fire, 3, 34, 2, 2, "y");
    _doors = {
        "heaven": rows(sky),
        "hell": rows(fire)
    };
    return _doors;
}
// light spilling on the floor from an open door `w` wide: a checker of `c`, widening toward us
function spill(c, w, h) {
    const g = grid(w + h, h, ".");
    for (let j = 0; j < h; j++)
        for (let i = Math.floor((h - j) / 2); i < w + Math.ceil((h + j) / 2); i++)
            if ((i + j) % 2 === 0 && (j > 1 || i % 4 === 0))
                g[j][i] = c;
    return rows(g);
}

// Hell behind its open door: flames licking up, a new shape each `phase`
function fire(phase) {
    const [, , w, h] = at.hell;
    const g = grid(w - 6, h - 3, ".");
    const W2 = w - 6, H2 = h - 3;
    for (let i = 0; i < W2; i++) {
        const n = Math.sin(i * 1.7 + phase * 2.3) + Math.sin(i * 0.6 - phase * 1.1) + Math.sin(i * 3.1 + phase);
        const top = Math.round(H2 - 16 - n * 5);
        for (let j = Math.max(0, top); j < H2; j++)
            g[j][i] = j - top < 2 ? "y" : j - top < 6 ? "F" : j > H2 - 5 ? "R" : "L";
    }
    for (let j = 0; j < H2; j++)
        for (let i = 0; i < W2; i++)
            if (!inArch(i, j, W2))
                g[j][i] = ".";
    let seed = 3 + phase * 7;
    for (let n = 0; n < 5; n++) {
        seed = (seed * 9301 + 49297) % 233280;
        set(g, seed % W2, Math.floor(seed / W2) % (H2 - 22) + 4, "y");
    }
    return rows(g);
}

// the hatch open: a hole, Limbo's grey fog rising (`phase`)
function hole(phase) {
    const [, , w, h] = at.hatch;
    const g = grid(w, h + 14, ".");
    const top = grid(w, h, ".");
    ellipse(top, (w - 1) / 2, (h - 1) / 2, w / 2, h / 2, "M");
    ellipse(top, (w - 1) / 2, (h - 1) / 2, w / 2 - 2, h / 2 - 1, "n");
    stamp(g, 0, 14, rows(top));
    let seed = 7 + phase * 13;
    const rnd = () => (seed = (seed * 9301 + 49297) % 233280) / 233280;
    for (let n = 0; n < 14; n++) {
        const x = 4 + Math.floor(rnd() * (w - 8)), y = 16 - Math.floor(rnd() * 16);
        set(g, x, y, n % 3 ? "v" : "V");
        set(g, x + 1, y, "v");
    }
    return rows(g);
}

// the wall clock, its hand at `step` of 12 (the shift's time running out)
function clock(step) {
    const g = grid(13, 13, ".");
    ellipse(g, 6, 6, 6.5, 6.5, "#");
    ellipse(g, 6, 6, 5.5, 5.5, "p");
    set(g, 6, 1, "r");
    set(g, 11, 6, "t");
    set(g, 6, 11, "t");
    set(g, 1, 6, "t");
    const a = step / 12 * 2 * Math.PI;
    for (let r = 0; r <= 4; r += 0.5)
        set(g, Math.round(6 + Math.sin(a) * r), Math.round(6 - Math.cos(a) * r), "#");
    return rows(g);
}

// the Boss on the monitor: an eye, the lid `open` 0..1, the pupil `look` -1..1 aside, `down` 0..1;
// `angry` reddens the screen. Off: a dark screen and its scanlines.
function eye(open, look, down, angry) {
    const [, , w, h] = at.screen;
    const g = grid(w, h, angry ? "R" : "n");
    for (let j = 1; j < h; j += 2)
        fill(g, 0, j, w, 1, angry ? "J" : "N");
    if (open === null)
        return rows(g);
    const cx = (w - 1) / 2, cy = (h - 1) / 2, a = 13, b = Math.max(0.6, 6 * open);
    ellipse(g, cx, cy, a + 1, b + 1, "#");
    ellipse(g, cx, cy, a, b, "w");
    if (open > 0.3) {
        const ix = Math.round(cx + look * 6), iy = Math.round(cy + down * 2);
        for (let j = 0; j < h; j++)
            for (let i = 0; i < w; i++) {
                if (g[j][i] !== "w")
                    continue;
                const d = (i - ix) ** 2 + (j - iy) ** 2;
                if (d <= 2.5)
                    g[j][i] = "n";
                else if (d <= 13)
                    g[j][i] = "r";
            }
        set(g, ix - 1, iy - 2, "w");
    }
    return rows(g);
}

const flame = [
    [".y.", ".y.", "yFy", "yFy", ".F."],
    ["..y", ".y.", "yFy", "yFy", ".F."],
    ["...", "y..", ".yy", "yFy", ".F."]
];

// Death from behind, at the desk: the hood, its seam, the shoulders
const death = [
    "...........########...........",
    ".........##zzzzzzzz##.........",
    "........#ZzzzzzzzzzzZ#........",
    ".......#ZzzzzzZZzzzzzZ#.......",
    "......#ZzzzzzzZZzzzzzzZ#......",
    "......#ZzzzzzzZZzzzzzzZ#......",
    ".....#ZzzzzzzzZZzzzzzzzZ#.....",
    ".....#ZzzzzzzzZZzzzzzzzZ#.....",
    ".....#ZzzzzzzzZZzzzzzzzZ#.....",
    ".....#ZzzzzzzzzzzzzzzzzZ#.....",
    ".....#zzzzzzzzzzzzzzzzzz#.....",
    "......#zzzzzzzzzzzzzzzz#......",
    "....##zzzzzzzzzzzzzzzzzz##....",
    "..##ZZzzzzzzzzzzzzzzzzzzZZ##..",
    ".#ZZzzzzzzzzzzzzzzzzzzzzzzZZ#.",
    "#Zzzzzzzzzzzzzzzzzzzzzzzzzzzz#",
    "#Zzzzzzzzzzzzzzzzzzzzzzzzzzzz#",
    "#zzzzzzzzzzzzzzzzzzzzzzzzzzzz#",
    "#zzzzzzzzzzzzzzzzzzzzzzzzzzzz#",
    "#zzzzzzzzzzzzzzzzzzzzzzzzzzzz#",
    "#zzzzzzzzzzzzzzzzzzzzzzzzzzzz#",
    "#zzzzzzzzzzzzzzzzzzzzzzzzzzzz#",
    "#zzzzzzzzzzzzzzzzzzzzzzzzzzzz#",
    "#zzzzzzzzzzzzzzzzzzzzzzzzzzzz#",
    "#zzzzzzzzzzzzzzzzzzzzzzzzzzzz#"
];
// her scythe, leaning on the left, a bony hand on it; `glint` flashes the blade
function scythe(glint) {
    const art = [
        "......#########.........",
        "...###KKKKKKKKK###......",
        ".##KKKKKKKKKKKKKKK##....",
        "#KKKwwwwwwwwwwKKKKKq#...",
        "#Kww##########wwKKqq#...",
        ".##..........##wKqq#....",
        "...............#qq#.....",
        "...............#qq#.....",
        "...............#qq#....."
    ];
    const g = grid(24, 62, ".");
    stamp(g, 0, 0, glint ? art.map(r => r.replace(/K/g, "w")) : art);
    for (let j = 9; j < 62; j++)
        stamp(g, 15 - Math.floor((j - 9) / 18), j, ["#qQ#"]);
    stamp(g, 12, 50, [".YYY", "YYYY", "YYY.", ".#.."]);
    return rows(g);
}

// ---- the visitors, 18×24 like the souls ----
const people = {
    // Чума: the plague doctor's hat, beak and goggles, a green cloak
    "plague": [
        "..................",
        ".....########.....",
        ".....#kkkkkk#.....",
        ".....#kkkkkk#.....",
        "...############...",
        "....#PPPPPPPP#....",
        "....#wwwwwwww#....",
        "....#wrrwwrrw#....",
        "....#wrrwwrrw#....",
        "....#wwwwwwwwww##.",
        ".....#wwwwwwwwwww#",
        "......#wwww######.",
        "....##PPPPPP##....",
        "...#PPPPPPPPPP#...",
        "..#PP#PPPPPP#PP#..",
        "..#PP#PPPPPP#PP#..",
        "..#ww#PPPPPP#ww#..",
        "...##PPPPPPPP##...",
        "....#PPPPPPPP#....",
        "...#PPPPPPPPPP#...",
        "...#PPPPPPPPPP#...",
        "..#PPPPPPPPPPPP#..",
        "..#PPPPPPPPPPPP#..",
        "..##############.."
    ],
    // Голод: thin as a rake, hollow eyes, an empty fork
    "famine": [
        "..................",
        "..................",
        "......######......",
        ".....#tttttt#.....",
        ".....#tttttt#.....",
        ".....#xxttxx#.....",
        ".....#xxttxx#.....",
        ".....#tttttt#.....",
        "......#t##t#......",
        ".......#tt#.......",
        "......######......",
        ".....#vvvvvv#.....",
        "....#v#vvvv#v#K.K.",
        "....#v#vvvv#v#KKK.",
        "....#t#vvvv#t##K..",
        ".....#.#vv#.#.#K..",
        ".......#vv#....#..",
        ".......#vv#.......",
        ".......#vv#.......",
        "......#vvvv#......",
        "......#v##v#......",
        "......#v##v#......",
        "......#t##t#......",
        ".....##t##t##....."
    ],
    // Война: a helmet with a red crest, armour, a sword
    "war": [
        "........rr........",
        ".......rrrr.......",
        "......##rr##......",
        ".....#KKKKKK#.....",
        "....#KKKKKKKK#....",
        "....#KKKKKKKK#....",
        "....#K######K#....",
        "....#K#rr#rr#K#...",
        "....#KKKKKKKK#....",
        ".....#KK##KK#.....",
        "......######......",
        "...##RRRRRRRR##...",
        "..#RR#KKKKKK#RR#..",
        "..#RR#KKKKKK#RR#..",
        "..#RR#KKKKKK#RR#K.",
        "..#KK#KKKKKK#KK#K.",
        "...##RRRRRRRR##.K.",
        "....#RRRRRRRR#..K.",
        "....#RRRRRRRR#.#y#",
        "...#RRRRRRRRRR#.y.",
        "...#RRRRRRRRRR#...",
        "....#KK#..#KK#....",
        "....#KK#..#KK#....",
        "...####....####..."
    ]
};
