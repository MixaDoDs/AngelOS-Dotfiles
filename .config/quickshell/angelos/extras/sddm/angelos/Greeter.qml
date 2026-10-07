import QtQuick

// What every look but the stream shares (the stream keeps its own copy): theme.conf, the
// palette, the language, the art pixel, the fonts, the user and session, the clock, the
// login call and its answer. Put one in a look: `Greeter { id: g }`, then g.pal, g.t(), g.submit(pw).
Item {
    id: g

    width: 0
    height: 0
    visible: false

    function conf(key, fallback) {
        const v = typeof config !== "undefined" && config ? config[key] : undefined;
        return v === undefined || v === null || String(v) === "" ? fallback : String(v);
    }
    readonly property var pal: ({
            "desk": conf("desk", "#2a1b3d"),
            "face": conf("face", "#3a2350"),
            "faceAlt": conf("faceAlt", "#4a2c66"),
            "sunken": conf("sunken", "#1d1230"),
            "edge": conf("edge", "#140c20"),
            "hi": conf("hi", "#5c3a80"),
            "lo": conf("lo", "#1d1230"),
            "text": conf("text", "#fdf3ff"),
            "textDim": conf("textDim", "#c7b2d8"),
            "titleText": conf("titleText", "#ffffff"),
            "accent": conf("accent", "#ff5fa2"),
            "accent2": conf("accent2", "#c9a0ff"),
            "accent3": conf("accent3", "#ffd36a"),
            "danger": conf("danger", "#ff4f6d"),
            "title1": conf("title1", "#ff5fa2"),
            "title2": conf("title2", "#c9a0ff")
        })
    readonly property bool ru: conf("language", Qt.locale().name.indexOf("ru") === 0 ? "ru" : "en") === "ru"
    function t(r, e) {
        return ru ? r : e;
    }
    readonly property string suffix: ["exe", "sh", "bin"].indexOf(conf("suffix", "")) >= 0 ? conf("suffix", "") : "exe"
    function exe(name) {
        return name + "." + suffix;
    }

    // the screen this look fills (set by the look: its own size)
    property real screenW: 1920
    property real screenH: 1080
    // one art pixel: 2 on 1080p, 3 on 1440p, 4 on 4K — by the short side
    readonly property int u: Math.max(1, Math.round(Math.min(screenW, screenH) / 540))
    readonly property bool portrait: screenH > screenW * 1.1

    FontLoader {
        id: titleLoader
        source: Qt.resolvedUrl("fonts/PixeloidSans.ttf")
    }
    FontLoader {
        id: bodyLoader
        source: Qt.resolvedUrl("fonts/CozetteVector.ttf")
    }
    FontLoader {
        id: gothicLoader
        source: Qt.resolvedUrl("fonts/Jacquard12Hell-Regular.ttf")
    }
    readonly property string titleFont: titleLoader.status === FontLoader.Ready ? titleLoader.name : "monospace"
    readonly property string bodyFont: bodyLoader.status === FontLoader.Ready ? bodyLoader.name : titleFont
    readonly property string gothicFont: gothicLoader.status === FontLoader.Ready ? gothicLoader.name : titleFont
    // pixel fonts are sharp only at whole multiples of their cell
    function titlePx(n) {
        return 9 * Math.max(1, Math.round(n * u / 2 / 9));
    }
    function bodyPx(n) {
        return 13 * Math.max(1, Math.round(n * u / 2 / 13));
    }
    function gothicPx(n) {
        return 12 * Math.max(1, Math.round(n * u / 2 / 12));
    }

    // ---- who and what ----
    property int userIndex: typeof userModel !== "undefined" && userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property int sessionIndex: typeof sessionModel !== "undefined" && sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    readonly property int userCount: typeof userModel !== "undefined" ? userModel.count || userModel.rowCount() : 0
    readonly property int sessionCount: typeof sessionModel !== "undefined" ? sessionModel.rowCount() : 0
    ListView {
        id: users
        // never seen, but sized: a ListView of no size makes no delegates to read
        width: 100
        height: 100
        opacity: 0
        enabled: false
        model: typeof userModel !== "undefined" ? userModel : null
        currentIndex: g.userIndex
        delegate: Item {
            required property string name
            required property string realName
            required property string icon
            property string login: name
            property string shown: realName || name
            property string face: icon
        }
    }
    ListView {
        id: sessions
        width: 100
        height: 100
        opacity: 0
        enabled: false
        model: typeof sessionModel !== "undefined" ? sessionModel : null
        currentIndex: g.sessionIndex
        delegate: Item {
            required property string name
            property string shown: name
        }
    }
    readonly property string login: users.currentItem ? users.currentItem.login : (typeof userModel !== "undefined" ? userModel.lastUser : "")
    readonly property string userShown: users.currentItem ? users.currentItem.shown : login
    readonly property string userFace: users.currentItem && users.currentItem.face ? users.currentItem.face : ""
    readonly property string sessionShown: sessions.currentItem ? sessions.currentItem.shown : ""
    readonly property string layoutShort: {
        if (typeof keyboard === "undefined" || !keyboard || !keyboard.layouts || keyboard.layouts.length === 0)
            return "";
        const l = keyboard.layouts[keyboard.currentLayout];
        return l ? String(l.shortName || "").toUpperCase() : "";
    }
    readonly property bool caps: typeof keyboard !== "undefined" && keyboard ? !!keyboard.capsLock : false
    function nextUser(step) {
        if (userCount > 1)
            userIndex = (userIndex + step + userCount) % userCount;
    }
    function nextSession() {
        if (sessionCount > 1)
            sessionIndex = (sessionIndex + 1) % sessionCount;
    }

    readonly property var power: [
        {
            "icon": "moon",
            "label": t("сон", "sleep"),
            "can": typeof sddm !== "undefined" && sddm.canSuspend,
            "run": () => sddm.suspend()
        },
        {
            "icon": "refresh",
            "label": t("перезагрузка", "restart"),
            "can": typeof sddm !== "undefined" && sddm.canReboot,
            "run": () => sddm.reboot()
        },
        {
            "icon": "power",
            "label": t("выключение", "shut down"),
            "can": typeof sddm !== "undefined" && sddm.canPowerOff,
            "run": () => sddm.powerOff()
        }
    ].filter(b => b.can || typeof sddm === "undefined")

    property bool busy: false
    property bool live: false
    property int fails: 0
    property string status: ""
    signal failed
    signal succeeded

    function submit(password) {
        if (busy)
            return;
        busy = true;
        status = t("проверяю…", "checking…");
        if (typeof sddm !== "undefined")
            sddm.login(g.login, password, g.sessionIndex);
    }
    Connections {
        target: typeof sddm !== "undefined" ? sddm : null
        ignoreUnknownSignals: true
        function onLoginFailed() {
            g.busy = false;
            g.fails++;
            g.status = "";
            g.failed();
        }
        function onLoginSucceeded() {
            g.status = "";
            g.live = true;
            g.succeeded();
        }
    }

    // ---- time ----
    property date now: new Date()
    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: g.now = new Date()
    }
    // seconds, smooth (shaders and drifting things run on it)
    property real secs: 0
    NumberAnimation on secs {
        from: 0
        to: 3600
        duration: 3600 * 1000
        loops: Animation.Infinite
    }
    readonly property int hour: now.getHours()
    readonly property string greeting: hour < 5 ? t("доброй ночи", "good night") : hour < 12 ? t("доброе утро", "good morning") : hour < 18 ? t("добрый день", "good afternoon") : t("добрый вечер", "good evening")
    function dateText() {
        return Qt.locale(ru ? "ru_RU" : "en_US").toString(now, "dddd, d MMMM");
    }
    function clockText(blink) {
        return Qt.formatTime(now, "HH") + (blink && now.getSeconds() % 2 ? " " : ":") + Qt.formatTime(now, "mm");
    }

    // ---- the wallpaper the desktop keeps in step (walls/), for the looks that show it ----
    readonly property var wallCandidates: {
        const own = portrait ? "walls/tall.jpg" : "walls/wide.jpg", other = portrait ? "walls/wide.jpg" : "walls/tall.jpg";
        return [own, other, conf("background", "")].filter(f => f !== "");
    }
}
