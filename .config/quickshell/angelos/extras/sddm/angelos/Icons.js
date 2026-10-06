// Pixel icons of angelOS (widgets/Icons.js), the few the login screen draws.
// # ink, o fill, x fill2, y fill3, w light, f body, r bad, . nothing
.pragma library

var icons = {
    "heart": [
        ".##...##.",
        "#wo#.#oo#",
        "#ooo#ooo#",
        "#ooooooo#",
        ".#ooooo#.",
        "..#ooo#..",
        "...#o#...",
        "....#...."
    ],
    "heartBroken": [
        ".##...##.",
        "#wo#.#oo#",
        "#oo#.#oo#",
        "#ooo#.oo#",
        ".#oo#oo#.",
        "..#o#o#..",
        "...#.#...",
        "....#...."
    ],
    "heartSmall": [
        ".#.#.",
        "#o#o#",
        "#ooo#",
        ".#o#.",
        "..#.."
    ],
    "sparkle": [
        "...o...",
        "...o...",
        "..ooo..",
        "ooowooo",
        "..ooo..",
        "...o...",
        "...o..."
    ],
    "sparkleStar": [
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
    "power": [
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
    "moon": [
        "..###....",
        ".#yy#....",
        "#yy#.....",
        "#yy#.....",
        "#yyy#....",
        "#yyyy###.",
        ".#yyyyyy#",
        "..######."
    ],
    "refresh": [
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
    "lock": [
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
    "keyboard": [
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
    "arrowLeft": [
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
    "arrowRight": [
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
    "chat": [
        ".#######.",
        "#wwwwwww#",
        "#wowowow#",
        "#wwwwwww#",
        ".##w####.",
        "..#w#....",
        "..##....."
    ],
    "eye": [
        "...#####...",
        "..#ooooo#..",
        ".#oo###oo#.",
        "#oo#www#oo#",
        "#oo#w##ooo#",
        ".#oo###oo#.",
        "..#ooooo#..",
        "...#####..."
    ],
    "ghost": [
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
    "play": [
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
    "monitor": [
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
    ]
};

function get(name) {
    return icons[name] || icons.heart;
}
