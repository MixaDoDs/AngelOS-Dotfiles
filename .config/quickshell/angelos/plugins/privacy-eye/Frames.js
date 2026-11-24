.pragma library
// The eye on the 11×8 grid of the built-in "eye" icon (widgets/Icons.js):
// '#' ink, 'o' accent, 'w' highlight, '.' empty.

const open = [
    "...#####...",
    "..#ooooo#..",
    ".#oo###oo#.",
    "#oo#www#oo#",
    "#oo#w##ooo#",
    ".#oo###oo#.",
    "..#ooooo#..",
    "...#####..."
];
const wide = [
    "...#####...",
    "..#ooooo#..",
    ".#o#####o#.",
    "#o##www##o#",
    "#o##w####o#",
    ".#o#####o#.",
    "..#ooooo#..",
    "...#####..."
];
const lookLeft = [
    "...#####...",
    "..#ooooo#..",
    ".#o###ooo#.",
    "#o#www#ooo#",
    "#o#w##oooo#",
    ".#o###ooo#.",
    "..#ooooo#..",
    "...#####..."
];
const lookRight = [
    "...#####...",
    "..#ooooo#..",
    ".#ooo###o#.",
    "#ooo#www#o#",
    "#ooo#w##oo#",
    ".#ooo###o#.",
    "..#ooooo#..",
    "...#####..."
];
// the lids close in from above and below: the iris stays until the slit is gone
const h6 = [
    "...........",
    "..#######..",
    ".#oo###oo#.",
    "#oo#www#oo#",
    "#oo#w##ooo#",
    ".#oo###oo#.",
    "..#######..",
    "..........."
];
const h4 = [
    "...........",
    "...........",
    ".#########.",
    "#oo#www#oo#",
    "#oo#w##ooo#",
    ".#########.",
    "...........",
    "..........."
];
const slit = [
    "...........",
    "...........",
    "...........",
    ".#########.",
    "#ooo###ooo#",
    ".#########.",
    "...........",
    "..........."
];
const line = [
    "...........",
    "...........",
    "...........",
    "...........",
    "###########",
    "...........",
    "...........",
    "..........."
];
const asleep = [
    "...........",
    "...........",
    "...........",
    "#.........#",
    ".#.......#.",
    "..#######..",
    ".#..#.#..#.",
    "..........."
];

// [frame, ms] — the last frame is where the eye rests
const close = [
    [open, 60], [h6, 45], [h4, 45], [slit, 60], [line, 80], [asleep, 0]
];
const wake = [
    [asleep, 60], [line, 50], [slit, 45], [h4, 45], [h6, 45],
    [wide, 160], [lookLeft, 170], [lookRight, 170], [open, 0]
];
