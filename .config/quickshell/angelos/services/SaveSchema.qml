import QtQuick
import Quickshell.Io

// The player's save: ~/.config/angelos/save.json, next to settings.json and apart from it
// (services/Story loads it). Settings are how the desktop is set up; the save is what the
// player did and where the story is. It survives shell restarts and project updates —
// the installer and updates never touch it; `angelos game reset` (or Settings → System,
// developer mode) starts it over.
JsonAdapter {
    property int version: 1
    property double createdAt: 0

    // who rules the corner and what came with her (was settings.json → y2k.*)
    property JsonObject player: JsonObject {
        property string character: "angel"  // angel | demon
        property double demonSince: 0       // ms; she fell
        property double lastPlea: 0         // ms; the last try to get out of hell (one per 10 minutes)
        property double wheelAt: 0          // the Wheel of Hell's last spin (one per 20 minutes)
        property double cursedUntil: 0      // the wheel's cursed cursor: another hell cursor until then
        property string cursedWas: ""       // the hell cursor it replaced
        property var pranks: []             // the demon's pranks this fall [{id, key, old, new, at, undone}]
        property double nextPrank: 0        // ms; not before
        property int returns: 0             // times the angel came back from hell; 3 open the portal
        property var angelSaved: null       // the theme mode kept while the demon rules ({mode}; older saves: heaven's wallpaper too)
        property var hellWall: null         // hell's wallpaper {circle, picked, fallback, outputs, workspaces}: the circle's painting or the player's pick in it (C2)
        // how cold the angel is towards the player (story/game.json → angel): the throws' chill,
        // the last throw and the last thaw (ms), the cold route (for good) and when it began
        property int chill: 0
        property double lastThrow: 0
        property double thawAt: 0
        property bool coldRoute: false
        property double coldSince: 0
        property bool coldSeen: false       // the cold route's scene has played
        // her step past cold (story/game.json → angel.fallen): the betrayals counted, a trip down
        // that will change her (marked as it begins), changed (for good) and since when
        property int betrayals: 0
        property bool fallenDue: false
        property bool fallen: false
        property double fallenSince: 0
        property bool fallenSeen: false     // her first words after it have been said
        // her diary read behind her back (services/Diary → watch, story/diary.json → watch):
        // trust left (-1 = not set yet: the rules' start), times caught, the diary hidden in
        // Settings since the first time, the trust marks already crossed (each chills her once)
        property int trust: -1
        property int diaryCaught: 0
        property bool diaryHidden: false
        property var trustMarks: []
    }

    // the story's variables: the sins the player's choices weigh (limbo lust gluttony greed
    // wrath heresy violence fraud treachery — one per circle) and whatever flags the scenes set
    property var vars: ({})

    // hell
    property JsonObject hell: JsonObject {
        property string circle: ""          // the circle the player is in ("" = not in hell)
        property var path: []               // the circles of this fall, in the order seen
        property var fallCircles: []        // circles a fall began in: each once, then all over again
        property int falls: 0
        property int attempts: 0            // tries to get out from this circle
        property int silences: 0            // trials answered with silence, this fall
        property bool limbo: false          // the limbo outcome: neither here nor there
        property double limboSince: 0
        property bool pact: false           // signed: something of hers stays in heaven
        property bool amnesty: false        // fell under the old rules (before the circles): let out at the next start
        property var outcomes: []           // [{kind: stars|pact|limbo|amnesty, circle, at}]
        property var close: ({})            // each circle's demon and the player: {circle: {points, talkAt, giftAt, stayAt}}
    }

    // the achievements (services/Achievements, story/achievements.json): only while the game is on.
    // got: {id: ms} earned; items: heaven's things they gave ({item: ms}, kept even if the
    // list changes later); counts: {event: n, "event:key": n}; kinds: {event: [keys]} (the
    // different keys seen: Start's looks, the circles); since: ms the counting began; diary: the
    // Angel's diary pages read and announced
    property JsonObject achievements: JsonObject {
        property var got: ({})
        property var items: ({})
        property var counts: ({})
        property var kinds: ({})
        property double since: 0
        property var diary: ({})            // the Angel's diary (services/Diary): {read: {page: ms}, seen: {page: ms}}
    }

    // every choice the player made: [{scene, node, choice, tone, at}] (the last 400)
    property var choices: []
    // the novel's progress (was ~/.local/state/angelos/novel.json) and the running scene
    property var novel: null
}
