.pragma library

// Pixel icons as ASCII bitmaps.
//   '#' ink / outline      'o' accent (pink)     'x' accent2 (cyan)
//   'y' accent3 (yellow)   'w' white highlight   'f' face / body
//   'r' danger             '.' transparent
const icons = {
    camera: [
        "...###...",
        "#########",
        "#fffffoo#",
        "#ff###ff#",
        "#f#www#f#",
        "#f#www#f#",
        "#ff###ff#",
        "#########"
    ],
    document: [
        "#######..",
        "#wwwww##.",
        "#wwwwwfw#",
        "#wwwwwww#",
        "#w####ww#",
        "#wwwwwww#",
        "#w####ww#",
        "#wwwwwww#",
        "#########"
    ],
    heart: [
        ".##...##.",
        "#wo#.#oo#",
        "#ooo#ooo#",
        "#ooooooo#",
        ".#ooooo#.",
        "..#ooo#..",
        "...#o#...",
        "....#...."
    ],
    fire: [
        "....#....",
        "...#r#...",
        "..#rr#.#.",
        ".#rryr##.",
        ".#ryyyr#.",
        "#rryyyrr#",
        "#ryywyyr#",
        ".#ryyyr#.",
        "..#####.."
    ],
    chat: [
        ".#######.",
        "#wwwwwww#",
        "#wowowow#",
        "#wwwwwww#",
        ".##w####.",
        "..#w#....",
        "..##....."
    ],
    // Y2K workspace sprites (Settings → Workspaces → Desk sprite), the heart's size
    cd: [
        "..#####..",
        ".#wwxxo#.",
        "#wxxyyoo#",
        "#xxy#yoo#",
        "#xy#.#oo#",
        "#xxy#yox#",
        "#oxxyyxx#",
        ".#ooxxx#.",
        "..#####.."
    ],
    sparkleStar: [
        "....#....",
        "...#w#...",
        "...#o#...",
        ".##ooo##.",
        "#ooowooo#",
        ".##ooo##.",
        "...#o#...",
        "...#o#...",
        "....#...."
    ],
    heartBroken: [
        ".##...##.",
        "#wo#.#oo#",
        "#oo#.#oo#",
        "#ooo#.oo#",
        ".#oo#oo#.",
        "..#o#o#..",
        "...#.#...",
        "....#...."
    ],
    // a heart with the demon's horns (hell's salute at the end of a song)
    heartHorns: [
        "r.......r",
        "rr.....rr",
        ".r##.##r.",
        "#wo#.#oo#",
        "#ooo#ooo#",
        "#ooooooo#",
        ".#ooooo#.",
        "..#ooo#..",
        "...#o#...",
        "....#...."
    ],
    heartSmall: [
        ".#.#.",
        "#o#o#",
        "#ooo#",
        ".#o#.",
        "..#.."
    ],
    pill: [
        "..########..",
        ".#wooo#fff#.",
        "#ooooo#ffff#",
        "#ooooo#ffff#",
        ".#oooo#fff#.",
        "..########.."
    ],
    star: [
        "....#....",
        "...#y#...",
        "####y####",
        "#yyyyyyy#",
        ".#yyyyy#.",
        "..#yyy#..",
        ".#yy#yy#.",
        ".##...##."
    ],
    sparkle: [
        "...o...",
        "...o...",
        "..ooo..",
        "ooowooo",
        "..ooo..",
        "...o...",
        "...o..."
    ],
    // the Start / launcher calculator
    calc: [
        "#########",
        "#fffffff#",
        "#f#####f#",
        "#f#wwo#f#",
        "#f#####f#",
        "#fffffff#",
        "#fwfwfof#",
        "#fffffff#",
        "#fwfwfxf#",
        "#fffffff#",
        "#########"
    ],
    gear: [
        "....###....",
        ".##.#o#.##.",
        ".#o#ooo#o#.",
        "..#ooooo#..",
        "###o###o###",
        "#ooo#.#ooo#",
        "###o###o###",
        "..#ooooo#..",
        ".#o#ooo#o#.",
        ".##.#o#.##.",
        "....###...."
    ],
    monitor: [
        "############",
        "#xxxxxxxxxx#",
        "#xwxxxxxxxx#",
        "#xxwxxxxxxx#",
        "#xxxxxxxxxx#",
        "#xxxxxxxxxx#",
        "############",
        ".....##.....",
        "....####....",
        "..########.."
    ],
    keyboard: [
        "#############",
        "#fffffffffff#",
        "#foxoxoxoxof#",
        "#fffffffffff#",
        "#fxoxoxoxoxf#",
        "#fffffffffff#",
        "#ffoooooooff#",
        "#fffffffffff#",
        "#############"
    ],
    mouse: [
        "..###..",
        ".#o#f#.",
        "#oo#ff#",
        "#oo#ff#",
        "#######",
        "#fffff#",
        "#fffff#",
        "#fffff#",
        "#fffff#",
        ".#fff#.",
        "..###.."
    ],
    chip: [
        "..#.#.#.#..",
        ".#########.",
        "##ooooooo##",
        ".#ooooooo#.",
        "##oo###oo##",
        ".#oo#x#oo#.",
        "##oo###oo##",
        ".#ooooooo#.",
        "##ooooooo##",
        ".#########.",
        "..#.#.#.#.."
    ],
    speaker: [
        ".....#.....",
        "....##...#.",
        "####o#.#..#",
        "#oo#o#..#.#",
        "#oo#o#..#.#",
        "#oo#o#..#.#",
        "####o#.#..#",
        "....##...#.",
        ".....#....."
    ],
    speakerMute: [
        ".....#.....",
        "....##.....",
        "####o#.r..r",
        "#oo#o#..rr.",
        "#oo#o#..rr.",
        "#oo#o#.r..r",
        "####o#.....",
        "....##.....",
        ".....#....."
    ],
    mic: [
        "..###..",
        ".#owo#.",
        ".#ooo#.",
        ".#ooo#.",
        "#.###.#",
        "#.....#",
        ".#...#.",
        "..###..",
        "...#...",
        "..###.."
    ],
    micMute: [
        "..###..r",
        ".#owo#r.",
        ".#ooor..",
        ".#oor#..",
        "#.#r#.#.",
        "#.r...#.",
        ".r#...#.",
        "r.###...",
        "...#....",
        "..###..."
    ],
    bell: [
        "....#....",
        "...###...",
        "..#ooo#..",
        ".#owooo#.",
        ".#ooooo#.",
        ".#ooooo#.",
        "#ooooooo#",
        "#########",
        "...#o#...",
        "....#...."
    ],
    bellOff: [
        "....#...r",
        "...###.r.",
        "..#ooor..",
        ".#owor#..",
        ".#oor#o#.",
        ".#or#oo#.",
        "#or#oooo#",
        "#r#######",
        "r..#o#...",
        "....#...."
    ],
    music: [
        "...#######",
        "...#ooooo#",
        "...#######",
        "...#.....#",
        "...#.....#",
        "...#.....#",
        ".###...###",
        "#oo#..#oo#",
        "#oo#..#oo#",
        ".##....##."
    ],
    lock: [
        "..#####..",
        ".#.....#.",
        ".#.....#.",
        ".#.....#.",
        "#########",
        "#ooooooo#",
        "#ooo#ooo#",
        "#ooo#ooo#",
        "#ooooooo#",
        "#########"
    ],
    power: [
        ".....#.....",
        "..##.#.##..",
        ".#...#...#.",
        "#....#....#",
        "#....#....#",
        "#.........#",
        "#.........#",
        ".#.......#.",
        "..##...##..",
        "....###...."
    ],
    moon: [
        "..###....",
        ".#yy#....",
        "#yy#.....",
        "#yy#.....",
        "#yyy#....",
        "#yyyy###.",
        ".#yyyyyy#",
        "..######."
    ],
    sun: [
        ".....y.....",
        ".y...y...y.",
        "..y.....y..",
        "....yyy....",
        "...yyyyy...",
        "yy.yyyyy.yy",
        "...yyyyy...",
        "....yyy....",
        "..y.....y..",
        ".y...y...y.",
        ".....y....."
    ],
    logout: [
        "######.....",
        "#oooo#.....",
        "#oooo#..#..",
        "#oooo#..##.",
        "#ooow######",
        "#oooo#..##.",
        "#oooo#..#..",
        "#oooo#.....",
        "######....."
    ],
    refresh: [
        "...#####...",
        "..#.....#.#",
        ".#.......##",
        "#.......###",
        "#..........",
        "#.........#",
        "..........#",
        "###.......#",
        "##.......#.",
        "#.#.....#..",
        "...#####..."
    ],
    folder: [
        "#####.......",
        "#yyyy#######",
        "#yyyyyyyyyy#",
        "############",
        "#yyyyyyyyyy#",
        "#yyyyyyyyyy#",
        "#yyyyyyyyyy#",
        "#yyyyyyyyyy#",
        "############"
    ],
    plug: [
        "..#...#..",
        "..#...#..",
        "#########",
        "#ooooooo#",
        "#owooooo#",
        ".#ooooo#.",
        "..#ooo#..",
        "...###...",
        "....#....",
        "....#...."
    ],
    image: [
        "############",
        "#xxxxxxxxxx#",
        "#xxxxxxxwwx#",
        "#xxxxxxxwwx#",
        "#xxxxxxxxxx#",
        "#xxx#xxxxxx#",
        "#xx#o#xx#xx#",
        "#x#ooo##o#x#",
        "##ooooooooo#",
        "############"
    ],
    palette: [
        "...#####...",
        ".##fffff##.",
        "#ffofffxff#",
        "#fffffffff#",
        "#fyfff##ff#",
        "#ffff#..#f#",
        ".#fff#..#f#",
        "..#ffwff##.",
        "...######.."
    ],
    layers: [
        "....#######",
        "....#xxxxx#",
        "..#######x#",
        "..#ooooo#x#",
        "#######o#x#",
        "#fffff#o###",
        "#fffff#o#..",
        "#fffff###..",
        "#######...."
    ],
    package: [
        "...#####...",
        ".##ooxoo##.",
        "#ooooxoooo#",
        "###########",
        "#ffffxffff#",
        "#ffffxffff#",
        "#ffffxffff#",
        "#ffffxffff#",
        "###########"
    ],
    terminal: [
        "############",
        "#oooooooooo#",
        "############",
        "#ffffffffff#",
        "#f#ffffffff#",
        "#ff#fffffff#",
        "#f#ff###fff#",
        "#ffffffffff#",
        "#ffffffffff#",
        "############"
    ],
    window: [
        "##########",
        "#oooooo#w#",
        "##########",
        "#ffffffff#",
        "#ffffffff#",
        "#ffffffff#",
        "#ffffffff#",
        "##########"
    ],
    calendar: [
        "..#.....#..",
        "###########",
        "#ooooooooo#",
        "###########",
        "#fffffffff#",
        "#f#f#f#f#f#",
        "#fffffffff#",
        "#f#f#o#f#f#",
        "#fffffffff#",
        "###########"
    ],
    info: [
        "..#####..",
        ".#xxwxx#.",
        "#xxxxxxx#",
        "#xxxwxxx#",
        "#xxxwxxx#",
        "#xxxwxxx#",
        "#xxxwxxx#",
        ".#xxxxx#.",
        "..#####.."
    ],
    warn: [
        ".....#.....",
        "....#y#....",
        "....#y#....",
        "...#y#y#...",
        "...#y#y#...",
        "..#yy#yy#..",
        "..#yyyyy#..",
        ".#yyy#yyy#.",
        "#yyyyyyyyy#",
        "###########"
    ],
    trash: [
        "...###...",
        "#########",
        ".#ooooo#.",
        ".#o#o#o#.",
        ".#o#o#o#.",
        ".#o#o#o#.",
        ".#o#o#o#.",
        ".#ooooo#.",
        "..#####.."
    ],
    search: [
        "..####....",
        ".#xxxx#...",
        "#xwxxxx#..",
        "#xxxxxx#..",
        "#xxxxxx#..",
        ".#xxxx#...",
        "..####o#..",
        "......#o#.",
        ".......#o#",
        "........##"
    ],
    check: [
        "........#",
        ".......##",
        "#.....##.",
        "##...##..",
        ".##.##...",
        "..###....",
        "...#....."
    ],
    close: [
        "##...##",
        "###.###",
        ".#####.",
        "..###..",
        ".#####.",
        "###.###",
        "##...##"
    ],
    minimize: [
        ".......",
        ".......",
        ".......",
        ".......",
        ".......",
        "######.",
        "######."
    ],
    maximize: [
        "#######",
        "#######",
        "#.....#",
        "#.....#",
        "#.....#",
        "#.....#",
        "#######"
    ],
    plus: [
        "..#..",
        "..#..",
        "#####",
        "..#..",
        "..#.."
    ],
    minus: [
        ".....",
        ".....",
        "#####",
        ".....",
        "....."
    ],
    arrowRight: [
        "#....",
        "##...",
        "#o#..",
        "#oo#.",
        "#ooo#",
        "#oo#.",
        "#o#..",
        "##...",
        "#...."
    ],
    arrowLeft: [
        "....#",
        "...##",
        "..#o#",
        ".#oo#",
        "#ooo#",
        ".#oo#",
        "..#o#",
        "...##",
        "....#"
    ],
    arrowDown: [
        "#########",
        ".#ooooo#.",
        "..#ooo#..",
        "...#o#...",
        "....#...."
    ],
    arrowUp: [
        "....#....",
        "...#o#...",
        "..#ooo#..",
        ".#ooooo#.",
        "#########"
    ],
    play: [
        "#.....",
        "##....",
        "#o#...",
        "#oo#..",
        "#ooo#.",
        "#oo#..",
        "#o#...",
        "##....",
        "#....."
    ],
    pause: [
        "###.###",
        "#o#.#o#",
        "#o#.#o#",
        "#o#.#o#",
        "#o#.#o#",
        "#o#.#o#",
        "###.###"
    ],
    next: [
        "#....#.#",
        "##...#.#",
        "#o#..#.#",
        "#oo#.#.#",
        "#o#..#.#",
        "##...#.#",
        "#....#.#"
    ],
    prev: [
        "#.#....#",
        "#.#...##",
        "#.#..#o#",
        "#.#.#oo#",
        "#.#..#o#",
        "#.#...##",
        "#.#....#"
    ],
    pin: [
        "..###..",
        ".#ooo#.",
        "#owooo#",
        "#ooooo#",
        ".#ooo#.",
        "..#o#..",
        "...#...",
        "...#...",
        "...#..."
    ],
    bot: [
        ".yyyyyyy.",
        ".........",
        ".#######.",
        "#fffffff#",
        "#f#fff#f#",
        "#fffffff#",
        "#offfffo#",
        ".#######.",
        "..#...#.."
    ],
    // the same face while the demon rules: horns where the halo was
    botHorns: [
        "r.......r",
        "rr.....rr",
        ".#######.",
        "#fffffff#",
        "#f#fff#f#",
        "#fffffff#",
        "#offfffo#",
        ".#######.",
        "..#...#.."
    ],
    // in hell itself: a mask, not a face — hollow eyes with an ember in each, a shut slit
    // for a mouth, the horns grown longer (claude.exe on hell's desktop)
    botHell: [
        "r.......r",
        "rr.....rr",
        ".r#####r.",
        "#fffffff#",
        "#f##f##f#",
        "#fw#f#wf#",
        "#fffffff#",
        "#ff###ff#",
        ".#######.",
        "..#...#.."
    ],
    gauge: [
        "...#####...",
        ".##ooyxx##.",
        "#oo....#xx#",
        "#o....#..x#",
        "#....#....#",
        "#...###...#",
        "###########"
    ],
    skull: [
        "..#####..",
        ".#wwwww#.",
        "#wwwwwww#",
        "#w##w##w#",
        "#w#rw#rw#",
        "#wwwwwww#",
        ".#ww#ww#.",
        "..#w#w#..",
        "..#####.."
    ],
    // the angel watching (the diary's bookmark, modules/diary/DiaryTab)
    eye: [
        "...#####...",
        "..#ooooo#..",
        ".#oo###oo#.",
        "#oo#www#oo#",
        "#oo#w##ooo#",
        ".#oo###oo#.",
        "..#ooooo#..",
        "...#####..."
    ],
    pentagram: [
        "...#####...",
        "..##.o.##..",
        ".#..ooo..#.",
        "##..o.o..##",
        "#ooooooooo#",
        "#.ooo.ooo.#",
        "#..oo.oo..#",
        "##.ooooo.##",
        ".#ooo.ooo#.",
        "..##...##..",
        "...#####..."
    ],
    ghost: [
        "..#####..",
        ".#fffff#.",
        "#fffffff#",
        "#f#fff#f#",
        "#fffffff#",
        "#ffoffof#",
        "#fffffff#",
        "#fffffff#",
        "#f#f#f#f#",
        ".#.#.#.#."
    ],
    // the cobwebs' spider on its thread (Settings → Windows → Cobwebs)
    spider: [
        "....#....",
        "....#....",
        "#..###..#",
        ".#.#o#.#.",
        "..#####..",
        "####o####",
        "..#####..",
        ".#.###.#.",
        "#...#...#"
    ],
    wifi: [
        "..#####..",
        ".#ooooo#.",
        "#o.....o#",
        "..#####..",
        ".#o...o#.",
        "...###...",
        "...#o#...",
        "....#...."
    ],
    wifiOff: [
        "r.#####..",
        ".r.....#.",
        "#.r....o#",
        "..#r###..",
        ".#o.r.o#.",
        "...##r...",
        "...#o#r..",
        "....#..r."
    ],
    // bar network indicators: Wi-Fi by signal (wifi = full), wired, Bluetooth off
    wifi1: [
        ".........",
        ".........",
        ".........",
        ".........",
        ".........",
        "...###...",
        "...#o#...",
        "....#...."
    ],
    wifi2: [
        ".........",
        ".........",
        ".........",
        "..#####..",
        ".#o...o#.",
        "...###...",
        "...#o#...",
        "....#...."
    ],
    ethernet: [
        ".#######.",
        "#fffffff#",
        "#f#o#o#f#",
        "#fffffff#",
        "#fff#fff#",
        ".##f#f##.",
        "...#o#...",
        "...###..."
    ],
    bluetoothOff: [
        "r..#...",
        ".r.##..",
        ".#r#x#.",
        "..#r#..",
        "...#r..",
        "..###r.",
        ".#.#x#r",
        "...##..",
        "...#..."
    ],
    bluetooth: [
        "...#...",
        "...##..",
        ".#.#x#.",
        "..###..",
        "...#...",
        "..###..",
        ".#.#x#.",
        "...##..",
        "...#..."
    ],
    gamepad: [
        ".#########.",
        "#fffffffff#",
        "#f#ffffxff#",
        "####fffoyf#",
        "#f#ffffxff#",
        "#fffffffff#",
        "#ff##.##ff#",
        ".##.....##."
    ],
    cursor: [
        "#.......",
        "##......",
        "#w#.....",
        "#ww#....",
        "#www#...",
        "#wwww#..",
        "#wwwww#.",
        "#ww####.",
        "#w#w#...",
        "##..#w#.",
        ".....##."
    ],
    download: [
        "...###...",
        "...#o#...",
        "...#o#...",
        ".###o###.",
        "..#ooo#..",
        "...#o#...",
        "#...#...#",
        "#.......#",
        "#########"
    ],
    grid: [
        "###.###.###",
        "#o#.#x#.#y#",
        "###.###.###",
        "...........",
        "###.###.###",
        "#x#.#y#.#o#",
        "###.###.###",
        "...........",
        "###.###.###",
        "#y#.#o#.#x#",
        "###.###.###"
    ],
    // laptops (services/Power, Backlight, Gestures): the battery, a charger's bolt, eco's leaf,
    // the touchpad, a fingerprint, rotation, airplane mode, the laptop, hell's coal heart
    battery: [
        "#########.",
        "#wooo...#.",
        "#oooo...##",
        "#oooo...##",
        "#oooo...##",
        "#oooo...#.",
        "#########."
    ],
    bolt: [
        "....yyy",
        "...yyy.",
        "..yyy..",
        ".yyyyyy",
        "yyyyyy.",
        "..yyy..",
        ".yyy...",
        "yyy...."
    ],
    // Wellbeing (Settings → Wellbeing, 2026-10-08)
    clock: [
        "..#####..",
        ".#wwwww#.",
        "#www#www#",
        "#www#www#",
        "#www##ww#",
        "#wwwwwww#",
        "#wwwwwww#",
        ".#wwwww#.",
        "..#####.."
    ],
    drop: [
        "....#....",
        "...#x#...",
        "..#xxx#..",
        ".#xxxxx#.",
        "#xxwxxxx#",
        "#xwxxxxx#",
        "#xxxxxxx#",
        ".#xxxxx#.",
        "..#####.."
    ],
    leaf: [
        ".....####",
        "...##xxx#",
        "..#xxxxx#",
        ".#xx#xx#.",
        ".#x#xxx#.",
        "..#xxx#..",
        ".#.###...",
        "#........"
    ],
    touchpad: [
        "###########",
        "#fffffffff#",
        "#fffffffff#",
        "#fffffffff#",
        "#fffffffff#",
        "###########",
        "#ffff#ffff#",
        "###########"
    ],
    fingerprint: [
        "..#####..",
        ".#.....#.",
        "#..###..#",
        "#.#...#.#",
        "#.#.#.#.#",
        "#.#.#.#.#",
        "#.#.#.#.#",
        "..#.#.#.#",
        "....#.#..",
        "......#.."
    ],
    rotate: [
        "..####..#",
        ".#....#.#",
        "#......##",
        "#....####",
        "#........",
        "#.......#",
        ".#.....#.",
        "..#####.."
    ],
    plane: [
        ".....#.....",
        "....#o#....",
        "....#o#....",
        ".###ooo###.",
        "#ooooooooo#",
        ".###ooo###.",
        "....#o#....",
        "...#ooo#...",
        "...#####..."
    ],
    laptop: [
        ".#########.",
        ".#xxxxxxx#.",
        ".#xwxxxxx#.",
        ".#xxxxxxx#.",
        ".#xxxxxxx#.",
        ".#########.",
        "###########",
        ".#########."
    ],
    coal: [
        ".##...##.",
        "#oy#.#oo#",
        "#ooo#oyo#",
        "#oyooooo#",
        ".#oooyo#.",
        "..#oyo#..",
        "...#o#...",
        "....#...."
    ]
};

function get(name) {
    return icons[name] || icons.heart;
}

function names() {
    return Object.keys(icons);
}

// Builds a crisp SVG data URI; runs of equal cells are merged into one rect.
// `name` may also be an array of rows (custom bitmap, e.g. from a plugin)
// Every PxIcon asks for its SVG again whenever a theme colour changes, and most
// icons share a handful of palettes, so the encoded documents are memoized.
const _cache = new Map();
const CACHE_LIMIT = 4000;

function svg(name, colors, hollow) {
    let tint = "";
    for (const k of Object.keys(colors).sort())
        tint += k + colors[k];
    const key = (Array.isArray(name) ? name.join("/") : name) + "|" + (hollow ? 1 : 0) + "|" + tint;
    const hit = _cache.get(key);
    if (hit)
        return hit;
    const result = build(name, colors, hollow);
    if (_cache.size >= CACHE_LIMIT)
        _cache.clear();
    _cache.set(key, result);
    return result;
}

function build(name, colors, hollow) {
    const rows = Array.isArray(name) ? name : get(name);
    const h = rows.length;
    let w = 0;
    for (const r of rows)
        w = Math.max(w, r.length);
    let body = "";
    for (let y = 0; y < h; y++) {
        const row = rows[y];
        let x = 0;
        while (x < row.length) {
            const ch = row[x];
            let run = 1;
            while (x + run < row.length && row[x + run] === ch)
                run++;
            if (ch !== "." && ch !== " " && !(hollow && ch !== "#")) {
                const col = colors[ch] || colors["#"];
                body += `<rect x="${x}" y="${y}" width="${run}" height="1" fill="${col}"/>`;
            }
            x += run;
        }
    }
    const doc = `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}" shape-rendering="crispEdges">${body}</svg>`;
    return {
        url: "data:image/svg+xml;utf8," + encodeURIComponent(doc),
        width: w,
        height: h
    };
}
