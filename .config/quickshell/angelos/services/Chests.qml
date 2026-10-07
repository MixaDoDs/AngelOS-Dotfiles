pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Heaven's prayers as chests (modules/chest/ChestOverlay): the same prayer as ever
// (HeavenStars.pull: the odds, the pity, the album, the skins), opened like a Vampire Survivors /
// Megabonk chest — it shakes, its glow may climb blue → purple → gold, the lid flies, a beam in
// the rarity's colour, a reel of prizes that slows down onto yours. Ten at once fan out.
//   free     the day's free prayer (HeavenStars.freeWishToday) is a chest of its own; a
//            notification says it is waiting once a day, 3 minutes into the session
//   stars    160 ✦ a chest (×10 for 1600 ✦)
//   lock     the unlock's prayer (Lock.qml) only shows the falling star's colour on the lock:
//            its prize waits here and opens when the desktop is back
// Start → Chests, Settings → Heaven: stars, `angelos chest`.
Singleton {
    id: root

    property bool open: false
    property var results: []            // HeavenStars.pull() outputs, this opening
    property string source: ""          // free | stars | lock
    property var pendingLock: null       // the unlock's prize, until the desktop is back

    readonly property int cost: HeavenStars.wishCost
    readonly property bool freeReady: Config.lock.wish && HeavenStars.loaded && HeavenStars.freeWishToday
    readonly property int affordable: Math.floor(HeavenStars.stars / cost)
    readonly property int count: (freeReady ? 1 : 0) + affordable
    // the best rarity in this opening (the glow climbs to it)
    readonly property int best: results.reduce((m, r) => Math.max(m, r.stars || 3), 3)

    function openOne() {
        if (open || Shell.locked)
            return false;
        let paid = "";
        if (freeReady && HeavenStars.payWish(true))
            paid = "free";
        else if (HeavenStars.spend(cost))
            paid = "stars";
        if (!paid)
            return false;
        results = [HeavenStars.pull(false)];
        source = paid;
        open = true;
        return true;
    }
    function openTen() {
        if (open || Shell.locked || !HeavenStars.spend(cost * 10))
            return false;
        const out = [];
        for (let i = 0; i < 10; i++)
            out.push(HeavenStars.pull(false));
        results = out;
        source = "stars";
        open = true;
        return true;
    }
    // the free one if there is one, else one for stars (the notification, `angelos chest`)
    function openBest() {
        return openOne();
    }
    // the show only: the same odds, nothing paid or counted (`angelos chest demo|demo10`)
    function demo(n) {
        if (open)
            return false;
        const out = [];
        for (let i = 0; i < (n || 1); i++)
            out.push(HeavenStars.pull(true));
        results = out;
        source = "demo";
        open = true;
        return true;
    }
    function fromLock(r) {
        pendingLock = r;
    }
    function close() {
        open = false;
    }
    // the desktop is back after an unlock that prayed: its chest comes up
    Connections {
        target: Shell
        function onLockedChanged() {
            if (!Shell.locked && root.pendingLock)
                lockChest.restart();
        }
    }
    Timer {
        id: lockChest
        interval: 1400
        onTriggered: {
            if (!root.pendingLock || Shell.locked)
                return;
            if (root.open) {
                restart();
                return;
            }
            root.results = [root.pendingLock];
            root.pendingLock = null;
            root.source = "lock";
            root.open = true;
        }
    }

    // ---- once a day: "the day's chest is waiting" ----
    Timer {
        interval: 3 * 60 * 1000
        repeat: true
        running: Config.ready && Story.enabled && !Shell.dev && Quickshell.env("ANGELOS_TEST") !== "1"
        onTriggered: {
            const day = new Date().toDateString();
            if (!root.freeReady || Shell.locked || Shell.setupLocked || root.open || Config.lock.chestNotified === day || StreamMode.active)
                return;
            Config.lock.chestNotified = day;
            notifier.command = ["notify-send", "-a", "angelOS", "-h", "string:x-angelos-sound:stars", "-i", Quickshell.shellDir + "/data/icons/heaven-star.svg", "--wait", "-A", "open=" + I18n.t("Открыть сундук", "Open the chest"), I18n.t("Сундук дня ждёт ✦", "The day's chest is waiting ✦"), I18n.t("Бесплатная молитва: карточка в альбом или скин ангела. Может выпасть и 5★…", "A free prayer: a card for the album or one of the angel's skins. A 5★ may drop…")];
            notifier.running = true;
        }
    }
    Process {
        id: notifier
        stdout: SplitParser {
            onRead: line => {
                if (line.trim() === "open")
                    root.openOne();
            }
        }
    }
}
