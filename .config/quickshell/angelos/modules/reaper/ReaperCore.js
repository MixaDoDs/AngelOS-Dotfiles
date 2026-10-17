.pragma library

// «Смерть на смене» (modules/reaper/ReaperWindow), after Peace, Death!: souls come one by one,
// the player sends each to Heaven, Hell or Limbo by what it carries. Every day adds a rule; the
// rules are in priority order — the first one a soul matches decides, none: Heaven.
// tests/reaper/run.sh checks this file.

const rules = [
    { "id": "mask",   "day": 5, "to": "limbo",  "ru": "без лица → Чистилище", "en": "no face → Limbo" },
    { "id": "halo",   "day": 2, "to": "heaven", "ru": "нимб → Рай",           "en": "halo → Heaven" },
    { "id": "horns",  "day": 3, "to": "hell",   "ru": "рога → Ад",            "en": "horns → Hell" },
    { "id": "cross",  "day": 7, "to": "heaven", "ru": "крест → Рай",          "en": "cross → Heaven" },
    { "id": "cat",    "day": 6, "to": "heaven", "ru": "с котом → Рай",        "en": "with a cat → Heaven" },
    { "id": "knife",  "day": 1, "to": "hell",   "ru": "нож → Ад",             "en": "knife → Hell" },
    { "id": "bottle", "day": 4, "to": "hell",   "ru": "бутылка → Ад",         "en": "bottle → Hell" }
];
const lastDay = 7;

function active(day) {
    return rules.filter(r => r.day <= day);
}
function newRule(day) {
    return rules.find(r => r.day === day) || null;
}
// the shift: souls to sort, seconds, mistakes allowed (the third one ends it)
function quota(day) {
    return 6 + 2 * day;
}
function seconds(day) {
    return Math.min(60, 40 + 5 * day);
}
const mistakes = 3;

// {to, rule} — where the soul goes and the rule that sent it (null: nothing matched)
function verdict(soul, day) {
    const r = active(day).find(r => soul[r.id]);
    return { "to": r ? r.to : "heaven", "rule": r };
}

// a soul: the things it has (only of rules already in play, so nothing unexplained shows) and a
// look (ReaperArt.tints)
function make(day, rnd) {
    rnd = rnd || Math.random;
    const s = { "look": Math.floor(rnd() * 3) };
    for (const r of active(day))
        s[r.id] = rnd() < 0.3;
    // one hand: a knife or a bottle
    if (s.knife && s.bottle)
        s[rnd() < 0.5 ? "knife" : "bottle"] = false;
    return s;
}

// ---- the sprite: a little ghost, 18×24 art pixels for PxIcon, in ReaperArt.colors ----
const body = [
    "..................",
    "..................",
    "..................",
    "..................",
    "......######......",
    "....##ssssss##....",
    "...#ssssssssss#...",
    "..#ssssssssssss#..",
    "..#ssssssssssss#..",
    "..#sssxxssxxsss#..",
    "..#sssxxssxxsss#..",
    "..#ssoossssooss#..",
    "..#ssssssssssss#..",
    ".#ssssssssssssss#.",
    "#ss#ssssssssss#ss#",
    "#ss#ssssssssss#ss#",
    ".##ssssssssssss##.",
    "..#ssssssssssss#..",
    "..#ssssssssssss#..",
    "..#ssssssssssss#..",
    "..#tsssssssssst#..",
    "..#ttssssssssst#..",
    "..#tst#ssss#tst#..",
    "...###.####.###..."
];
// [x, y, rows]: a char draws in its colour, '-' cuts a hole, '.' leaves it
const parts = {
    "halo": [5, 0, [".yyyyyy.", "y......y", ".yyyyyy."]],
    "horns": [3, 2, ["r..........r", "rr........rr", ".rr......rr."]],
    "mask": [5, 9, ["ssssssss", "ssssssss", "ssssssss"]],
    "cross": [7, 15, [".yy.", "yyyy", ".yy.", ".yy."]],
    "knife": [0, 6, ["K.", "KK", "KK", "KK", "KK", "Kq", "qq", "qq"]],
    "bottle": [0, 16, [".#.", "#B#", "BBB", "BwB", "BBB", "###"]],
    "cat": [11, 14, ["#O...O#", "#OO#OO#", "OOOOOOO", "OxOOOxO", "OOOrOOO", "#OOOOO#", ".#####."]]
};

function put(rows, p) {
    const [x, y, art] = p;
    for (let j = 0; j < art.length; j++) {
        const row = rows[y + j].split("");
        for (let i = 0; i < art[j].length; i++)
            if (art[j][i] === "-")
                row[x + i] = ".";
            else if (art[j][i] !== ".")
                row[x + i] = art[j][i];
        rows[y + j] = row.join("");
    }
}
function sprite(s) {
    const rows = body.slice();
    for (const id of ["halo", "horns", "mask", "cross", "knife", "bottle", "cat"])
        if (s[id])
            put(rows, parts[id]);
    return rows;
}
