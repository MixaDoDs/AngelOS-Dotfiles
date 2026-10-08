pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "AngelLines.js" as Lines
import "Intents.js" as Intents

// The Y2K helper in the screen corner (modules/y2k/AngelHelper): what she says
// and who she is.
//   angel   tips on a timer (Settings → Y2K), a tip the first time a settings
//           page opens, jokes, answers in the "Ask" menu (settings search).
//   demon   the user grabbed the angel and threw her down into hell: dark
//           wallpaper, a cracked screen corner, the circle's voice, and now and
//           then a prank that flips a real setting — with "Undo" and "Where's
//           that?" buttons, so every prank shows off a feature. There is no
//           button out: a try to get out ("Ask" → "Seek the way out", once per
//           10 minutes) is the circle's trial (services/Story) — the way out lies
//           down through the bottom. When the player gets out (getOut()), the
//           angel undoes the pranks and gives the wallpaper back.
// Who rules and what came with her is the player's save (Story.player), not a setting.
// Effects: heaven() — sun rays and a choir (HeavenRays), punched() — the
// demon's broken glass (services/Cracks), quake() — the swap shakes the screen
// (ScreenQuake). The demon arrives: shake with her 8-bit rocks, then the screen
// breaks and her cracks appear. The angel returns: the demon's glass breaks and
// falls out (shattered()), then the screen shakes — no rocks, they are hers. Nothing of it on
// streamed screens. The owner (Owner.enabled) can send the demon away at once,
// for debugging: her menu, or `angelos helper angel`.
Singleton {
    id: root

    // ---- who and where ----
    readonly property bool demon: Story.enabled && Story.player.character === "demon"

    // ---- heaven and hell kept apart ----
    // Hell's own things — the pentagram right-click menu, the Hell wordmark, a hell
    // cursor as the everyday one — live in hell only: in heaven they are locked. Once
    // the angel has come back from hell three times the portal opens: heaven ↔ hell at
    // will, like the owner (no begging, no throwing), and hell's things are allowed in
    // heaven too. Story.player.returns counts the comebacks.
    readonly property int returnsNeeded: 3
    readonly property int returns: Story.player.returns || 0
    readonly property bool portalOpen: Owner.enabled || returns >= returnsNeeded
    readonly property bool hellAllowed: demon || portalOpen
    // Settings (and the setup wizard, Studio, the search) show hell's own things — the
    // demon's looks and sounds, the "… in hell" options, the pentagram, the Hell
    // wordmark, hell cursors, hell versions of plugins — only while the demon rules.
    // In heaven they are gone, not locked; the portal stays, it is the door.
    readonly property bool hellShown: demon
    // the portal: into hell at once, the swap's effects as usual. From hell it is the
    // pact's door — the demon offers the pact (services/Story), it is no way out by itself
    function portal() {
        if (!portalOpen || transition)
            return false;
        hush();
        if (demon)
            return Story.portal();
        _portal = true;
        startSwap("toHell");
        return true;
    }
    property bool _portal: false
    // her look (Settings → Y2K → Looks): the pick, unless the story changed her past cold
    // (story/game.json → angel.fallen) — then that one, whatever is picked; the pick is kept
    // the looks past the glitch girl are heaven's things (services/Heaven): earned, or the glitch one
    readonly property string angelLook: Story.angelFallen ? Story.fallenLook : ["glitch", "chibi", "adult", "mini"].includes(Config.y2k.angelLook) && Heaven.lookOk(Config.y2k.angelLook) ? Config.y2k.angelLook : "glitch"
    // on stream (services/StreamAngel) she sits on the streamed screen's taskbar (AngelHelper)
    readonly property bool streamer: StreamAngel.shown && !!StreamAngel.screen
    // the main screen, her own one (Y2K → Screen; unplugged → the main one), or where the focus is
    readonly property var screen: streamer ? StreamAngel.screen : StreamMode.angelScreen(Config.y2k.helperScreen === "focus" ? Shell.focusedScreen : Shell.screenByName(Config.y2k.helperScreen) || Shell.primaryScreen)
    readonly property string screenName: screen ? screen.name : ""

    property string text: ""
    property var actions: []                 // [{label, icon, run, choice}]: buttons in the bubble (choice: an answer, never singled out)
    property bool talking: false
    property bool menuOpen: false
    property string menuMode: "main"         // main | ask | assistant
    // An optional plugin-owned assistant. No model endpoint or prompt is handled by the shell.
    property var assistant: null
    property string assistantId: ""
    readonly property string assistantUrl: assistant && assistant.helperUrl ? assistant.helperUrl : ""
    function registerAssistant(id, provider) {
        if (!id || !provider || (assistant && assistant !== provider))
            return false;
        assistantId = id;
        assistant = provider;
        return true;
    }
    function unregisterAssistant(id, provider) {
        if (assistantId !== id || assistant !== provider)
            return;
        assistant = null;
        assistantId = "";
        if (menuMode === "assistant")
            hush();
    }
    property double hiddenUntil: 0
    property double now: Date.now()
    // the game off (`angelos game off`): nobody in the corner; limbo: the demon is gone too
    // away on her own (services/Diary → watch): off the screen until then — the time to read her diary
    property double awayUntil: 0
    readonly property bool away: awayUntil > 0
    readonly property bool shown: (Config.y2k.helper && Story.enabled || streamer) && !Story.limbo && now >= hiddenUntil && !away && !!screen
    readonly property bool present: shown && !Shell.bootOpen && !Shell.bootCover && Config.ready
    property double lastReaction: 0

    // the swap animation: angel falls into hell and the demon climbs out, or back
    property string transition: ""           // "" | toHell | ascend
    property real swap: 0                    // 0..1 through it; the character flips at 0.5
    // the desktop widgets wait for the glass to break before they burn over (DesktopWidgets)
    property bool holdWidgets: false
    signal said(string text)                  // she spoke (modules/IpcEvents: `angelos events angelSaid`)
    signal heaven(string screenName)
    signal punched(string screenName, string sound)
    signal shattered(string screenName)
    signal quake(string screenName, string kind)
    signal devDrag(real dx, real dy, int ms)   // dev: AngelHelper replays a real drag (tests)

    function tr(pair) {
        return I18n.t(pair[0], pair[1]);
    }
    // a [ru, en] pair, or a list of them (one picked, not twice in a row)
    function line(x, key) {
        return tr(Array.isArray(x[0]) ? pick(x, key) : x);
    }
    // on stream: a line to the chat, the streamer's {g:…} forms filled in (Story.render)
    function sline(list, key) {
        return Story.render(line(list, key));
    }
    // random, but not the same line twice in a row
    property var _last: ({})
    function pick(list, key) {
        if (!list || !list.length)
            return "";
        let i = Math.floor(Math.random() * list.length);
        if (list.length > 1 && i === _last[key])
            i = (i + 1) % list.length;
        _last[key] = i;
        return list[i];
    }

    // ---- the laptop's battery (services/Power; Settings → Battery → "notices") ----
    // 0 fine, 1 tired (yawns), 2 wings down, 3 asleep; her words stay in during games and on stream
    readonly property int tired: !Config.ready || !Config.power.angel || !Power.discharging ? 0 : Power.level === "critical" ? 3 : Power.level === "veryLow" ? 2 : Power.level === "low" ? 1 : 0
    readonly property bool batteryHush: StreamMode.active || MetaTap.coversOutput(Niri.focusedWindow)
    property bool _wasTired: false
    onTiredChanged: if (tired > 0)
        _wasTired = true
    Connections {
        target: Power
        function onLevelReached(level) {
            if (!Config.power.angel || root.batteryHush || root.transition)
                return;
            const set = root.demon ? Lines.battery.demon : Lines.battery.angel;
            if (set[level])
                root.say(root.line(set[level], "battery-" + level + root.demon));
        }
        function onPluggedIn() {
            if (!Config.power.angel || !root._wasTired || root.batteryHush || root.transition)
                return;
            root._wasTired = false;
            root.say(root.line((root.demon ? Lines.battery.demon : Lines.battery.angel).plugged, "battery-plugged" + root.demon));
        }
    }

    function say(msg, acts, ms, silent) {
        if (!shown || !msg)
            return;
        // cooled towards the player (Story.angelStep, item 11): no more hearts from her
        if (!demon && Story.angelStep >= 2)
            msg = String(msg).replace(/\s*♡/g, "");
        text = msg;
        actions = !acts ? [] : Array.isArray(acts) ? acts : [acts];
        said(msg);
        menuOpen = false;
        talking = true;
        quiet.interval = ms || Math.max(6000, msg.length * 80);
        quiet.restart();
        if (!silent)
            Sounds.play(demon ? "demon" : "angel");
    }
    // reactions to events stay rare: one per two minutes
    function react(msg, act, silent) {
        if (Date.now() - lastReaction < 120000 || talking || transition)
            return;
        lastReaction = Date.now();
        say(msg, act, 0, silent);
    }
    function hush() {
        talking = false;
        menuOpen = false;
        menuMode = "main";
    }
    function hide(minutes) {
        hush();
        Story.act("helper.hide");
        hiddenUntil = Date.now() + minutes * 60000;
    }
    function openMenu(mode) {
        Achievements.note("angel.menu", demon ? "demon" : "angel");
        now = Date.now();
        talking = false;
        menuMode = mode || "main";
        menuOpen = true;
        if (menuMode === "ask")
            SettingsSearch.load();
        Sounds.play(demon ? "demon" : "angel");
    }
    function showMe(page) {
        return {
            "label": I18n.t("Покажи", "Show me"),
            "icon": "heart",
            "run": () => Shell.openSettings(page)
        };
    }

    function tip() {
        const t = pick(demon ? Lines.demonTips : Lines.tips, demon ? "dtip" : "tip");
        say(I18n.t(t[0], t[1]), t[2] ? showMe(t[2]) : null);
    }
    function joke() {
        const list = demon ? (I18n.english ? Lines.demonJokesEn : Lines.demonJokesRu) : (I18n.english ? Lines.jokesEn : Lines.jokesRu);
        // cold for good: a joke now and then, never "another"
        if (!demon && Story.angelStep >= 3)
            return say(pick(list, "joke" + demon));
        say(pick(list, "joke" + demon), {
            "label": I18n.t("Ещё!", "Another!"),
            "icon": "star",
            "run": () => {
                Story.act("joke.more");
                root.joke();
            }
        });
    }
    // the timer: a tip, or now and then a joke. The demon is the talkative one: small
    // talk, a question with three answers, jokes, and hints how to get rid of her
    function chatter() {
        // on stream: to the chat, now and then a joke
        if (streamer) {
            if (Config.y2k.jokes && Math.random() < 0.2)
                return joke();
            return say(sline(demon ? Lines.stream.demonChatter : Lines.stream.angelChatter, "schat" + demon));
        }
        if (demon) {
            const r = Math.random();
            const own = Story.voiceLine("chatter");
            if (r < 0.15)
                hint();
            else if (own && r < 0.6)
                say(own);
            else if (r < 0.45)
                say(line(Lines.demonChatter, "dchat"));
            else if (r < 0.65)
                talk();
            else if (Config.y2k.jokes && r < 0.9)
                joke();
            else
                tip();
            return;
        }
        // as she cools she says her own things more and jokes less; cold, often nothing at all;
        // past cold only her own, and oftener (the timer below)
        const step = Story.angelStep;
        const own = Story.angelLine("chatter");
        if (step >= 4 && own)
            return say(own);
        if (step >= 3 && Math.random() < 0.4)
            return;
        if (own && Math.random() < [0, 0.3, 0.5, 0.7][step])
            return say(own);
        if (Config.y2k.jokes && Math.random() < 0.4 / (1 + step))
            joke();
        else
            tip();
    }
    // "Let's chat": she asks, three answers as buttons (alike: `choice`), she has the last word
    function talk() {
        const list = demon ? Lines.demonTalk : [];
        if (!list.length)
            return tip();
        const q = pick(list, "talk" + demon);
        const en = I18n.english;
        say(tr(q.q), q.a.map(a => ({
                    "label": en ? a[1] : a[0],
                    "icon": "chat",
                    "choice": true,
                    "run": () => root.say(en ? a[3] : a[2])
                })), 30000);
    }
    // her menu in a circle (story/game.json → closeness, item 12): a word, a gift her sin
    // loves, or staying a while; a new step of closeness has its own scene
    function demonDo(kind) {
        if (!demon)
            return;
        const r = Story.demonAct(kind);
        if (!r.ok) {
            if (r.wait > 0)
                say((Story.demonLine("wait") || I18n.t("Рано. Ещё %m мин.", "Too soon. %m more min.")).replace("%m", r.wait));
            return;
        }
        if (r.stepUp && Novel.playScene("close"))
            return;
        say(Story.demonLine(kind, r.step));
    }
    // the demon hints how out — down — with the button right there
    property double lastHint: 0
    function hint() {
        if (!demon)
            return;
        lastHint = Date.now();
        say(Story.voiceLine("hint") || I18n.t("Хочешь наверх? Путь один — вниз, через все круги. Ищи выход — я посмотрю, как ты ищешь.", "You want to go up? There's one way: down, through every circle. Seek the way out — I'll watch you seek."), {
            "label": I18n.t("Искать выход", "Seek the way out"),
            "icon": "heart",
            "run": () => root.plea()
        });
    }

    // "Ask": a few words she understands, then the settings search
    function answer(q) {
        const s = String(q || "").trim().toLowerCase();
        if (!s)
            return;
        const L = demon ? Lines.demon : Lines.angel;
        if (/шут|анекдот|смеш|рассмеш|joke|funny|laugh/.test(s))
            return joke();
        // in hell, wanting out wins over small talk ("привет, верни ангела"): any wording,
        // typos and the wrong keyboard layout too (services/Intents.js, issue #31); the
        // weak words ("назад", "please") only when it isn't a settings question
        const settingsIntent = intents.find(it => it.re.test(s));
        // "What did I sign?" (D2), in any wording, typos and the wrong layout too — unless
        // wanting out is the stronger wish in the same words
        if (Intents.stronger(s, "signed", "plea"))
            return showContract();
        if (demon && (Intents.strong(s, "plea") || (!settingsIntent && Intents.weak(s, "plea"))))
            return plea();
        // the angel cooled towards the player answers in her step's words (story/angel.json)
        const cool = k => demon ? "" : Story.angelLine(k);
        if (/^(привет|здравств|хай|хей|ку\b|добр|hello|hi\b|hey|yo\b)/.test(s))
            return say(cool("hello") || line(L.hello, "hello" + demon));
        if (/как дела|как ты|как жизнь|how are you|what'?s up|sup\b/.test(s))
            return say(cool("how") || line(L.how, "how" + demon));
        if (/кто ты|ты кто|who are you|what are you/.test(s))
            return say(cool("who") || line(L.who, "who" + demon));
        if (/люблю|love you|i love/.test(s)) {
            Story.act("ask.love");
            return say(cool("love") || line(L.love, "love" + demon));
        }
        if (/спасиб|благодар|thank/.test(s))
            return say(cool("thanks") || line(L.thanks, "thanks" + demon));
        if (!demon && /(^|\s)ад(\s|$)|демон|hell|demon/.test(s))
            return say(tr(Lines.angel.hell));
        if (/совет|подсказ|помоги|помощь|help|tip|advice/.test(s))
            return tip();
        // the questions people ask most, answered straight
        if (settingsIntent)
            return say(I18n.t(settingsIntent.ru, settingsIntent.en), showMe(settingsIntent.page));
        const r = searchLoose(q);
        if (r && r.length) {
            const best = r[0];
            return say(tr(Lines.angel.found).replace("%1", best.crumb ? best.title + " (" + best.crumb + ")" : best.title), {
                "label": I18n.t("Покажи", "Show me"),
                "icon": "heart",
                "run": () => root.showResult(best)
            });
        }
        const list = demon ? (I18n.english ? Lines.demonJokesEn : Lines.demonJokesRu) : (I18n.english ? Lines.jokesEn : Lines.jokesRu);
        say(tr(Lines.angel.notFound) + " " + pick(list, "joke" + demon));
    }
    readonly property var intents: [
        {
            "re": /крупн|больше|мельч|мелк|масштаб|bigger|larger|smaller|zoom|scale/,
            "page": "theme",
            "ru": "Крупнее или мельче всё — «Тема и цвета» → «Размер пикселя», а текст — «Шрифты» → «Масштаб шрифтов».",
            "en": "Everything bigger or smaller: Theme and colours → Pixel size; the text: Fonts → Font scale."
        },
        {
            "re": /обо(и|ев|ям)|картинк|фон |wallpaper|background/,
            "page": "wallpaper",
            "ru": "Обои — на странице «Обои»: кликни картинку, и она на столе.",
            "en": "Wallpapers are on the Wallpaper page: click a picture and it's on."
        },
        {
            "re": /звук|громк|тише|громче|микрофон|volume|sound|louder|quieter|microphone/,
            "page": "sound",
            "ru": "Громкость, колонки и микрофон — на странице «Звук».",
            "en": "Volume, speakers and the microphone are on the Sound page."
        },
        {
            "re": /тёмн|темн|светл|тема|dark|light mode|theme/,
            "page": "theme",
            "ru": "Светлая или тёмная тема — «Тема и цвета», или просто Mod+Alt+T.",
            "en": "Light or dark theme: Theme and colours, or just Mod+Alt+T."
        },
        {
            "re": /горяч|сочетан|клавиш|хоткей|shortcut|hotkey|keybind/,
            "page": "shortcuts",
            "ru": "Все сочетания клавиш — на странице «Горячие клавиши», любое можно поменять.",
            "en": "Every shortcut is on the Shortcuts page, and any of them can be changed."
        },
        {
            "re": /экранн|сколько.*(сижу|сидел|времен)|перерыв|напомина|попить|вод[уы]|глаз|screen time|break|remind|water/,
            "page": "wellbeing",
            "ru": "Сколько ты за компьютером, лимит и мои напоминания про воду и перерывы — в «Благополучии» ♡",
            "en": "How long you're at the computer, a limit, and my water and break reminders are in Wellbeing ♡"
        }
    ]
    // whole questions first, then without the filler words, then word by word
    readonly property var filler: ["как", "где", "что", "мне", "мои", "мой", "моя", "я", "можно", "сделать", "поменять", "изменить", "хочу", "чтобы", "это", "эту", "этот", "в", "на", "и", "а", "с", "по", "у", "the", "a", "an", "how", "do", "does", "i", "can", "to", "make", "change", "my", "is", "are", "where", "what", "want", "please", "set", "turn"]
    function searchLoose(q) {
        if (!SettingsSearch.loaded)
            return [];
        let r = SettingsSearch.search(q, 3);
        if (r.length)
            return r;
        const words = String(q).toLowerCase().replace(/[?!.,«»"“”]/g, " ").split(/\s+/).filter(w => w && !filler.includes(w));
        if (!words.length)
            return [];
        r = SettingsSearch.search(words.join(" "), 3);
        if (r.length)
            return r;
        for (const w of words.slice().sort((a, b) => b.length - a.length)) {
            r = SettingsSearch.search(w, 3);
            if (r.length)
                return r;
        }
        return [];
    }
    // open Settings on a search result and flash it (SettingsView.openResult)
    property var _result: null
    property int _tries: 0
    function showResult(r) {
        Shell.openSettings(r.page);
        _result = r;
        _tries = 0;
        resultTimer.restart();
    }
    Timer {
        id: resultTimer
        interval: 120
        repeat: true
        onTriggered: {
            if (Shell.settingsView) {
                Shell.settingsView.openResult(root._result);
                stop();
            } else if (++root._tries > 20)
                stop();
        }
    }

    // ---- angel → hell: no button, she is grabbed and thrown down ----
    // AngelHelper drags her sprite; dropping her deep enough (or flinging her
    // down) sends her through the floor. The demon can't be thrown anywhere.
    property bool thrown: false              // the fall starts where she was dropped
    property real throwX: 0
    property real throwY: 0
    function grabbed() {
        if (streamer && Math.random() < 0.6)
            return say(sline(demon ? Lines.stream.demonGrab : Lines.stream.angelGrab, "sgrab" + demon), null, 2600);
        say(tr(pick(demon ? Lines.demon.grab : Lines.angel.grab, "grab" + demon)), null, 2600);
    }
    // `fling`: thrown hard (the speed of the drop) — or pushed down slowly, on purpose
    function released(deep, x, y, fling) {
        if (demon) {
            say(streamer ? sline(Lines.stream.demonDrop, "sdrop") : tr(Lines.demon.drop));
            return;
        }
        if (!deep) {
            say(streamer ? sline(Lines.stream.angelPhew, "sphew") : tr(Lines.angel.phew));
            return;
        }
        Story.act(fling ? "throw.fling" : "throw.push");
        thrown = true;
        throwX = x;
        throwY = y;
        toHell();
    }
    function toHell() {
        if (demon || transition)
            return;
        hush();
        startSwap("toHell");
    }
    function becomeDemon() {
        Story.player.character = "demon";
        Story.player.demonSince = Date.now();
        Story.player.lastPlea = 0;
        Story.player.pranks = [];
        Story.player.nextPrank = Date.now() + (6 + Math.random() * 4) * 60000;
        // the circle the fall lands in (the heaviest sin), hell's look follows it
        Story.fell(Story.fallTarget());
        hellLook(true);
    }

    // ---- demon → angel: Dante's way, down through the bottom (services/Story) ----
    // a try to get out: the circle's trial (once per 10 minutes; Story.attempt)
    function plea() {
        if (!demon || transition)
            return;
        hush();
        Story.attempt(false);
        now = Date.now();
    }
    // "What did I sign?" (D2): the one in the corner hands the paper over — the pact, or that
    // there is none, and in hell the way out as it stands (Story.contractPaper)
    function showContract() {
        const p = Story.contractPaper();
        if (!Novel.showPaper(p.title, p.text, demon ? "demon" : "angel"))
            return say(I18n.t("Сначала прочти записку, что уже лежит.", "Read the note that's already there first."));
        say(Story.contractLine(demon ? "demon" : "angel", p.state) || p.title, null, 5000);
    }
    // the way out was found (Story.outcome): stars — the bottom passed; pact — signed, out
    // now; limbo — the angel found the player in the grey. A line, then the swap back.
    property string _escape: ""
    function getOut(kind) {
        if (!demon || transition)
            return;
        _escape = kind;
        if (kind === "amnesty")
            say(I18n.t("Правила сменились. Старые долги сгорели — иди. Но в следующий раз дорога будет длиннее.", "The rules have changed. Old debts burnt up — go. But next time the road will be longer."), null, 5200, true);
        else if (kind === "pact")
            say(I18n.t("Подписано. Иди. Мы ещё увидимся — у тебя теперь есть кое-что моё.", "Signed. Go. We'll meet again — you have something of mine now."), null, 2600, true);
        else if (kind === "stars")
            say(I18n.t("…Ладно. Иди. Наверху светло.", "…Fine. Go. It's light up there."), null, 2600, true);
        leave.interval = kind === "amnesty" ? 5200 : 2600;
        leave.restart();
    }
    function ascend() {
        getOut("stars");
    }
    // Settings / `angelos helper summon`: she comes now — switched on and not hidden. In
    // hell the demon doesn't let anyone in: that is no way out.
    function summon() {
        if (transition)
            return "busy";
        if (!Config.y2k.helper)
            Config.y2k.helper = true;
        hiddenUntil = 0;
        awayUntil = 0;              // called back from her walk: she sees what's open (services/Diary)
        now = Date.now();
        if (!screen)
            return "hidden";               // stream mode keeps her off every screen
        if (demon) {
            say(Story.voiceLine("refuse") || I18n.t("Ангела? Здесь только я.", "The angel? Only I'm here."), null, 4000);
            return "refused";
        }
        lastReaction = Date.now();
        say(Story.angelLine("summoned") || tr(pick(Lines.angel.summoned, "summoned")));
        return "ok";
    }
    // the game switched off (`angelos game off`, Settings): out of hell at once — no show,
    // no line, the comeback not counted; pranks undone, the wallpaper given back
    function leaveNow() {
        leave.stop();
        swapTick.stop();
        transition = "";
        swap = 0;
        thrown = false;
        _portal = false;
        holdWidgets = false;
        hush();
        if (Story.player.character === "demon")
            becomeAngel(false);
    }
    // the owner debugging: no begging, she goes right away
    function ownerAngel() {
        if (!Owner.enabled || !demon || transition)
            return false;
        hush();
        startSwap("ascend");
        return true;
    }
    Timer {
        id: leave
        interval: 2600
        onTriggered: {
            root.hush();
            root.startSwap("ascend");
        }
    }
    property int _undone: 0
    property bool _unlockedNow: false
    function becomeAngel(counted) {
        _undone = undoAllPranks();
        liftCurse(false);
        Story.player.character = "angel";
        Story.player.pranks = [];
        Story.rose(counted);
        // every comeback from hell counts (not the game switched off); the third one opens the portal
        const before = Story.player.returns || 0;
        if (counted !== false)
            Story.player.returns = before + 1;
        _unlockedNow = counted !== false && before < returnsNeeded && before + 1 >= returnsNeeded && !Owner.enabled;
        hellLook(false);
    }

    // ---- the swap animation, stepped like the sprite (AngelHelper draws it) ----
    // C1: every way into hell shows the circle (the throw, the portal); a switch soon after the
    // last one (story/game.json → pace.quickSwitch) happens at once — no splash, no quake, no
    // glass, no sound — so clicking back and forth never piles the shows up
    property double lastSwitchAt: 0
    property bool instant: false             // the switch going on is the quiet one (DesktopWidgets: no burn)
    function startSwap(kind) {
        const t = Date.now();
        const quick = lastSwitchAt > 0 && t - lastSwitchAt < Story.quickSwitchMs;
        lastSwitchAt = t;
        if (quick || Motion.still)
            return swapAtOnce(kind);
        holdWidgets = true;
        transition = kind;
        swap = 0;
        swapTick.restart();
    }
    function swapAtOnce(kind) {
        instant = true;
        holdWidgets = false;
        thrown = false;
        _portal = false;
        if (kind === "toHell") {
            becomeDemon();
            // her glass is part of how hell looks: it is there, without the punch or a sound
            if (fxHere() && Config.y2k.cracks !== "off")
                punched(screenName, "");
        } else {
            becomeAngel();
        }
        transition = "";
        swap = 0;
        instantDone.restart();
    }
    Timer {
        id: instantDone
        interval: 300
        onTriggered: root.instant = false
    }
    FrameAnimation {
        id: swapTick
        onTriggered: {
            const before = root.swap;
            root.swap = Math.min(1, root.swap + Math.min(frameTime, 0.1) / 1.9);
            if (before < 0.5 && root.swap >= 0.5) {
                if (root.transition === "toHell")
                    root.becomeDemon();
                else
                    root.becomeAngel();       // her glass stays until the quake breaks it
            }
            if (root.swap >= 1) {
                stop();
                const kind = root.transition;
                root.transition = "";
                root.thrown = false;
                // the new one has arrived: the screen shakes, then it breaks
                if (kind === "toHell" && root._portal) {
                    root._portal = false;
                    CircleFx.run(Story.circle, null, () => root.shake("hell", () => {
                        root.breakScreen();
                        root.say(I18n.t("Сам(а) пришёл(ла) через портал? Смело. Добро пожаловать домой 😈 Обратно — тем же порталом, в моём меню.", "Walked in through the portal yourself? Brave. Welcome home 😈 The way back is the same portal, in my menu."), {
                            "label": I18n.t("Портал", "Portal"),
                            "icon": "sparkle",
                            "run": () => root.portal()
                        }, 12000);
                        hellNews.restart();
                    }));
                } else if (kind === "toHell") {
                    // the circle comes up out of the dark, then she shakes and breaks the screen
                    CircleFx.run(Story.circle, null, () => root.shake("hell", () => {
                            root.breakScreen();
                            // on stream she greets the chat: they saw the throw
                            root.say(root.streamer ? root.sline(Lines.stream.demonArrive, "sarrive") : Story.voiceLine("enter") || root.tr(Lines.demon.intro), {
                                "label": I18n.t("Как отсюда выйти?", "How do I get out?"),
                                "icon": "chat",
                                "run": () => root.hint()
                            }, 16000);
                            hellNews.restart();
                        }));
                } else {
                    root.breakScreen();
                    afterGlass.restart();
                }
            }
        }
    }
    // after her intro: what hell did to the right-click menu and Settings (Y2K → Angel or demon)
    Timer {
        id: hellNews
        interval: 16500
        onTriggered: {
            if (!root.demon)
                return;
            const style = DeskMenu.styleLabel(DeskMenu.style).toLowerCase();
            const parts = [];
            if (DeskMenu.hellish)
                parts.push(I18n.t("ПКМ по обоям теперь — " + style, "right-click on the wallpaper is a " + style + " now"));
            if (HellLook.settingsPick === "grimoire")
                parts.push(I18n.t("настройки — мой гримуар", "Settings are my grimoire"));
            else if (HellLook.settingsPick)
                parts.push(I18n.t("настройки — в обличье круга", "Settings wear the circle's guise"));
            if (Config.y2k.hellStart)
                parts.push(I18n.t("«Пуск» — адский", "Start is hellish"));
            const mine = [];
            if (Config.y2k.hellWidgets && DesktopWidgets.widgets.length)
                mine.push(I18n.t("виджеты", "the widgets"));
            if (Cursors.hellOn)
                mine.push(I18n.t("курсор", "the cursor"));
            if (mine.length) {
                const one = mine.length === 1 && !(Config.y2k.hellWidgets && DesktopWidgets.widgets.length);   // just the cursor
                parts.push(mine.join(I18n.t(" и ", " and ")) + (one ? I18n.t(" — тоже мой", " is mine too") : I18n.t(" — тоже мои", " are mine too")));
            }
            if (!parts.length)
                return;
            const what = parts.length > 1 ? parts.slice(0, -1).join(", ") + I18n.t(", а ", ", and ") + parts[parts.length - 1] : parts[0];
            root.say(I18n.t("И да: ", "Oh, and ") + what + I18n.t(" 😈 Вернётся ангел — вернётся и твоё.", " 😈 When the angel's back, so is yours."), {
                "label": I18n.t("Где это?", "Where is it?"),
                "icon": "gear",
                "run": () => Shell.openSettings("y2k")
            }, 12000);
        }
    }
    // sun rays for the angel, broken glass for the demon — when she shows up. `arriving`:
    // she appears with the shell (every start, login, restart): the rays and the choir
    // only the very first time (Config.y2k.raysSeen), the demon's cracks come back silently
    function effect(arriving) {
        if (!fxHere())
            return;
        if (demon) {
            if (Config.y2k.cracks !== "off")
                punched(screenName, arriving || Story.calm ? "" : "crack");
        } else if (Config.y2k.heavenFx && Heaven.has("fx.rays") && !Story.calm && !(arriving && Config.y2k.raysSeen)) {
            if (arriving)
                Config.y2k.raysSeen = true;
            heaven(screenName);
        }
    }
    function fxHere() {
        return !!screenName && StreamMode.effectsOn(screenName) && !Shell.fullscreenOn(screenName);
    }
    // ---- the swap's end: quake, then the screen breaks ----
    property var _afterQuake: null
    function shake(kind, then) {
        if (!Config.y2k.shake || Story.calm || !fxHere()) {
            then();
            return;
        }
        _afterQuake = then;
        quakeGuard.restart();
        quake(screenName, kind);
    }
    // ScreenQuake is done (or could not shake at all)
    function quakeDone() {
        quakeGuard.stop();
        const then = _afterQuake;
        _afterQuake = null;
        if (then)
            then();
    }
    Timer {
        id: quakeGuard
        interval: 2500
        onTriggered: root.quakeDone()
    }
    function breakScreen() {
        holdWidgets = false;
        if (!fxHere())
            return;
        if (!Story.calm)
            Sounds.play("shatter");
        if (!demon)
            shattered(screenName);
        else if (Config.y2k.cracks !== "off")
            punched(screenName, "");
    }
    Timer {
        id: heavenSoon
        interval: 450
        onTriggered: root.effect()
    }
    // the angel is back: her glass has fallen out (services/Cracks, 450 ms), now the shake
    Timer {
        id: afterGlass
        interval: 480
        onTriggered: root.shake("heaven", () => {
            heavenSoon.restart();
            root._portal = false;
            if (root._unlockedNow) {
                root._unlockedNow = false;
                root.say(I18n.t("Я вернулась уже в третий раз — и теперь между раем и адом открыт портал! Ходи туда и обратно когда захочешь (моё меню → «Портал»), а адские штучки — пентаграмма, надпись Hell, адские курсоры — теперь можно и в раю.", "That's my third comeback — and now there's a portal between heaven and hell! Go back and forth whenever you like (my menu → “Portal”), and hell's things — the pentagram, the Hell wordmark, hell cursors — are allowed in heaven now."), {
                    "label": I18n.t("Где портал?", "Where's the portal?"),
                    "icon": "sparkle",
                    "run": () => Shell.openSettings("y2k")
                }, 16000);
                return;
            }
            const how = root._escape;
            root._escape = "";
            // cold for good, the first time back: her scene (story/scenes/angel-cold.json);
            // cooler than warm: her step's words instead of the warm welcome
            if (Story.player.coldRoute && !Story.player.coldSeen && Novel.playScene("cold")) {
                Story.player.coldSeen = true;
                return;
            }
            // changed past cold, the first time back: her first words in it (story/angel.json → fallen.first)
            if (Story.angelFallen && !Story.player.fallenSeen) {
                Story.player.fallenSeen = true;
                const first = Story.angelLine("first");
                if (first)
                    return root.say(first);
            }
            const cool = Story.angelLine("back");
            if (cool)
                return root.say(cool);
            // (drafts — the author's lines replace them)
            if (how === "limbo")
                root.say(Story.render(I18n.t("Я тебя нашла. Ты так долго сидел{g:|а|(а)} в сером… Пойдём домой ♡", "I found you. You sat in the grey so long… Let's go home ♡")));
            else if (how === "pact")
                root.say(Story.render(I18n.t("Я вернулась… Но ты что-то подписал{g:|а|(а)} там, внизу. Я вижу это на тебе.", "I'm back… But you signed something down there. I can see it on you.")));
            else if (how === "amnesty")
                root.say(Story.render(I18n.t("Я вернулась! Пока тебя не было, внизу всё перестроили — теперь там девять кругов. Не падай больше, ладно? ♡", "I'm back! While you were away they rebuilt it all down there — nine circles now. Don't fall again, okay? ♡")));
            else if (how === "stars")
                root.say(Story.render(I18n.t("Ты прош{g:ёл|ла|ёл(ла)} через самое дно — и выш{g:ел|ла|ел(ла)} к звёздам. Я здесь ♡", "You went through the very bottom — and out to the stars. I'm here ♡")));
            else if (root.streamer && !root._undone)
                root.say(root.sline(Lines.stream.angelBack, "sback"));
            else
                root.say(root.tr(root._undone ? Lines.angel.back : Lines.angel.backClean));
        })
    }
    onPresentChanged: if (present && !transition)
        appear.restart()
    // she moved: her cracks stay where her fist landed (services/Cracks) — unless that
    // monitor is gone, then they come along, silently
    onScreenNameChanged: if (demon && present && !transition && screenName)
        moved.restart()
    property string _crackedOn: ""            // where her cracks were put last
    onPunched: name => _crackedOn = name
    Timer {
        id: moved
        interval: 300
        onTriggered: if (root.demon && !appear.running && root._crackedOn && !Shell.screenByName(root._crackedOn) && root.fxHere() && Config.y2k.cracks !== "off")
            root.punched(root.screenName, "")
    }
    Timer {
        id: appear
        interval: 700
        onTriggered: root.effect(true)
    }

    // ---- the demon's wallpaper: hell while she rules; heaven's is left alone (C2) ----
    // Heaven's wallpaper (Config.wallpaper) is never touched in hell: the screens show hell's,
    // Story.player.hellWall (services/Wallpapers) — the circle's painting, put up here, or
    // what the player picked in this circle (the next circle puts its own). Only the theme
    // mode waits in Story.player.angelSaved for the angel.
    property bool _hellPending: false        // scripts/hell-wallpaper.py is still painting
    function wallState() {
        return {
            "fallback": Config.wallpaper.fallback,
            "outputs": JSON.parse(JSON.stringify(Config.wallpaper.outputs || {})),
            "workspaces": JSON.parse(JSON.stringify(Config.wallpaper.workspaces || {}))
        };
    }
    // hell's picture for this circle (not a pick)
    function applyWall(st) {
        Sounds.quietWallpaper(4000);
        Story.player.hellWall = {
            "circle": Story.circle,
            "picked": false,
            "fallback": st.fallback || "",
            "outputs": st.outputs || ({}),
            "workspaces": st.workspaces || ({})
        };
    }
    // an older angelOS put hell into Config.wallpaper and kept heaven's in angelSaved: give
    // heaven its wallpaper back, and what was up becomes hell's
    function untangleWall() {
        const s = Story.player.angelSaved;
        if (!s || s.fallback === undefined)
            return;
        if (demon && !Story.player.hellWall)
            Story.player.hellWall = Object.assign({
                "circle": Story.circle,
                "picked": false
            }, wallState());
        Sounds.quietWallpaper(4000);
        Config.wallpaper.fallback = s.fallback || "";
        Config.wallpaper.outputs = s.outputs || ({});
        Config.wallpaper.workspaces = s.workspaces || ({});
        Story.player.angelSaved = s.mode ? {
            "mode": s.mode
        } : null;
    }
    function hellLook(on) {
        untangleWall();
        if (on) {
            if (!Story.player.angelSaved) {
                Story.player.angelSaved = {
                    "mode": Config.appearance.mode
                };
                Config.appearance.mode = "dark";
            }
            if (!hellUp() && !_hellPending)
                putHell();
            return;
        }
        const s = Story.player.angelSaved;
        Sounds.quietWallpaper(4000);
        Story.player.hellWall = null;
        if (s && s.mode)
            Config.appearance.mode = s.mode;
        Story.player.angelSaved = null;
    }
    // hell's wallpaper is up for the circle the player is in
    function hellUp() {
        const w = Story.player.hellWall;
        return !!w && (w.circle || "") === (Story.circle || "") && !!(w.fallback || Object.keys(w.outputs || {}).length);
    }
    // the hell picture itself: your own (Y2K → hell picture), or a painting from the
    // Hell pack / the drawn hell (scripts/hell-wallpaper.py) sized for every screen
    function putHell() {
        Sounds.quietWallpaper(4000);
        if (Config.y2k.hellPicture) {
            applyWall({
                "fallback": Config.y2k.hellPicture,
                "outputs": ({}),
                "workspaces": ({})
            });
            return;
        }
        const sizes = [];
        for (const s of Shell.screens) {
            const k = Math.round(s.width * (s.devicePixelRatio || 1)) + "x" + Math.round(s.height * (s.devicePixelRatio || 1));
            if (!sizes.includes(k))
                sizes.push(k);
        }
        _hellPending = true;
        // the circle's own paintings first (story/circles.json → backdrop.pictures)
        const own = (HellLook.backdrop && HellLook.backdrop.pictures || []).reduce((a, n) => a.concat(["--prefer", n]), []);
        hellGen.command = ["python3", Quickshell.shellDir + "/scripts/hell-wallpaper.py", Config.home + "/.local/share/angelos/hell", "--pack", Config.home + "/Pictures/Hell", "--cache", Config.home + "/.local/share/angelos/hell-pack"].concat(Config.y2k.hellStyle === "drawn" ? ["--drawn"] : []).concat(own).concat(sizes);
        hellGen.running = true;
    }
    Process {
        id: hellGen
        onExited: root._hellPending = false
        stdout: StdioCollector {
            onStreamFinished: {
                root._hellPending = false;
                let files = {};
                try {
                    files = JSON.parse(text).files || {};
                } catch (e) {
                    return;
                }
                const outputs = {};
                let first = "";
                for (const s of Shell.screens) {
                    const k = Math.round(s.width * (s.devicePixelRatio || 1)) + "x" + Math.round(s.height * (s.devicePixelRatio || 1));
                    if (files[k]) {
                        outputs[s.name] = files[k];
                        first = first || files[k];
                    }
                }
                if (!first || !root.demon)
                    return;
                root.applyWall({
                    "fallback": first,
                    "outputs": outputs,
                    "workspaces": ({})
                });
            }
        }
    }
    Connections {
        target: Config.y2k
        // paintings ↔ drawn hell, or her own picture: a new hell right away
        function onHellStyleChanged() {
            root.newHell();
        }
        function onHellPictureChanged() {
            root.newHell();
        }
    }
    // the shell starts: an older save is untangled; while she rules hell must be up
    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready)
                wakeHell.restart();
        }
    }
    Timer {
        id: wakeHell
        interval: 1500
        onTriggered: {
            if (!Story.ready || root.transition)
                return;
            root.untangleWall();
            if (root.demon)
                root.hellLook(true);
        }
    }
    Component.onCompleted: if (Config.ready)
        wakeHell.restart()
    // another hell picture now (a new circle, the style changed; `angelos helper hellwall`)
    function newHell() {
        if (!demon || transition)
            return false;
        putHell();
        return true;
    }

    // ---- the Wheel of Hell (desktop widget "hellwheel", hell only): a spin every 20 min ----
    // eight sectors, the order around the wheel; both pleas sit opposite each other
    readonly property var wheelSectors: ["plea", "punish", "newHell", "cerberus", "plea", "quake", "cursed", "dud"]
    readonly property int wheelCooldown: 20 * 60000
    function wheelLeft() {
        return Math.max(0, wheelCooldown - (now - (Story.player.wheelAt || 0)));
    }
    function wheelReady() {
        return demon && !transition && Date.now() - (Story.player.wheelAt || 0) >= wheelCooldown;
    }
    // the spin, shared by every copy of the widget (its face and its input copy): they only
    // show wheelAngle; the ticks and the result come from here. The cooldown counts from
    // the start (closing the widget doesn't buy another go).
    property real wheelAngle: 0              // degrees clockwise; 0 = sector 0 under the pointer
    property bool wheelSpinning: false
    property int wheelTarget: 0
    property string wheelWhere: ""
    property double _wheelStart: 0
    property real _wheelFrom: 0
    property real _wheelTo: 0
    property int _wheelLast: -1
    readonly property int wheelMs: 4800
    function wheelUnder(angle) {
        const a = ((-angle % 360) + 360) % 360;
        return Math.round(a / 45) % 8;
    }
    function wheelSpin(where) {
        if (wheelSpinning)
            return false;
        if (!wheelReady()) {
            say(line(Lines.demonWheel.wait, "wwait").replace("%1", Math.max(1, Math.ceil(wheelLeft() / 60000))));
            return false;
        }
        Story.player.wheelAt = Date.now();
        Story.act("wheel.spin");
        now = Date.now();
        wheelWhere = where || screenName;
        wheelTarget = Math.floor(Math.random() * 8);
        // land inside the sector, not on its edge: the pointer stops ±16° off its middle
        const want = wheelTarget * 45 + (Math.random() - 0.5) * 32;
        const base = wheelAngle - (wheelAngle % 360);
        let to = base + 360 * 5 + ((360 - want) % 360);
        while (to - wheelAngle < 360 * 4.5)
            to += 360;
        _wheelFrom = wheelAngle;
        _wheelTo = to;
        _wheelStart = Date.now() - (Motion.still ? wheelMs : 0);
        _wheelLast = wheelUnder(wheelAngle);
        wheelSpinning = true;
        wheelClock.start();
        say(line(Lines.demonWheel.spin, "wspin"), null, wheelMs, true);
        return true;
    }
    FrameAnimation {
        id: wheelClock
        onTriggered: {
            const p = Math.min(1, (Date.now() - root._wheelStart) / root.wheelMs);
            const e = 1 - Math.pow(1 - p, 3.2);
            root.wheelAngle = root._wheelFrom + (root._wheelTo - root._wheelFrom) * e;
            const under = root.wheelUnder(root.wheelAngle);
            if (under !== root._wheelLast) {
                root._wheelLast = under;
                Sounds.playSoft("toggle", 0.55);
            }
            if (p >= 1) {
                stop();
                root.wheelAngle = root._wheelTo % 360;
                root.wheelSpinning = false;
                root.wheelResult(root.wheelSectors[root.wheelUnder(root.wheelAngle)], root.wheelWhere);
            }
        }
    }
    // where it stopped; `where` is the widget's screen (Cerberus runs there)
    property string wheelLast: ""            // where it stopped last (the widget shows it for a minute)
    property double wheelLastAt: 0
    function wheelResult(id, where) {
        if (!demon || transition)
            return;
        wheelLast = id;
        wheelLastAt = Date.now();
        hush();
        const w = Lines.demonWheel;
        if (id === "plea") {
            // a try to get out right now, no waiting: the circle's trial
            say(line(w.plea, "wplea"), null, 3000);
            pleaSoon.restart();
        } else if (id === "punish") {
            say(line(w.punish, "wpunish"), null, 2600);
            punishSoon.restart();
        } else if (id === "newHell") {
            if (newHell())
                say(line(w.newHell, "wnewhell"));
            else
                say(line(w.dud, "wdud"));
        } else if (id === "cerberus") {
            HellFx.cerberus(where || screenName);
            say(line(w.cerberus, "wcerb"));
        } else if (id === "quake") {
            say(line(w.quake, "wquake"));
            shake("hell", () => {});
        } else if (id === "cursed") {
            curseCursor();
            say(line(w.cursed, "wcursed"));
        } else {
            say(line(w.dud, "wdud"));
        }
    }
    Timer {
        id: pleaSoon
        interval: 3000
        onTriggered: Story.attempt(true)
    }
    Timer {
        id: punishSoon
        interval: 2600
        onTriggered: if (!root.prank())
            root.joke()
    }
    // the cursed cursor: another hell cursor for an hour (not the one on now), then hers again
    function curseCursor() {
        const pool = Cursors.hellish.filter(c => c.theme && c.theme !== Cursors.hellTheme && !c.theme.startsWith(Cursors.hellTheme));
        if (!pool.length)
            return false;
        if (!Story.player.cursedUntil)
            Story.player.cursedWas = Config.cursor.hell || "";
        Story.player.cursedUntil = Date.now() + 3600000;
        Cursors.setHell(pool[Math.floor(Math.random() * pool.length)].theme);
        return true;
    }
    function liftCurse(speak) {
        if (!Story.player.cursedUntil)
            return;
        Story.player.cursedUntil = 0;
        Cursors.setHell(Story.player.cursedWas || "angelOS-Hell");
        Story.player.cursedWas = "";
        if (speak && demon)
            react(tr(Lines.demonWheel.undone));
    }
    Timer {
        interval: 30000
        repeat: true
        running: !!Story.player.cursedUntil
        triggeredOnStart: true
        onTriggered: if (Date.now() > Story.player.cursedUntil)
            root.liftCurse(true)
    }

    // ---- pranks: a real setting flips, the bubble says what it is ----
    // Only angelOS's own settings, each with its undo (and all undone when she leaves);
    // nothing that writes another program's config (niri's animations used to be one).
    function getPath(path) {
        const [a, b] = path.split(".");
        const v = Config[a][b];
        return v !== null && typeof v === "object" ? JSON.parse(JSON.stringify(v)) : v;
    }
    function setPath(path, v) {
        const [a, b] = path.split(".");
        Config[a][b] = v;
    }
    readonly property var osuPlugin: Plugins.enabledPlugins.find(p => p.id === "osu-mini") || null
    readonly property var pranks: [
        {
            "id": "heartAnim",
            "key": "workspaces.heartAnim",
            "value": () => "drop",
            "can": () => Config.workspaces.heartAnim !== "drop",
            "page": "workspaces",
            "ru": "Сердечки на панели теперь падают, как ты в моих глазах. Анимация сердечек — в «Воркспейсах».",
            "en": "The hearts on the bar drop now, like you in my eyes. The heart animation is in Workspaces."
        },
        {
            "id": "startLabel",
            "key": "bar.startLabel",
            "value": () => "hellOS",
            "can": () => Config.bar.startLabel !== "hellOS",
            "page": "bar",
            "ru": "Посмотри на «Пуск». Теперь это hellOS. Надпись меняется в «Панели», если что.",
            "en": "Look at Start. It's hellOS now. The label is in the Bar settings, if you care."
        },
        {
            "id": "startStyle",
            "key": "bar.startStyle",
            "value": () => Config.bar.startStyle === "fullscreen" ? "win11" : "fullscreen",
            "page": "bar",
            "ru": "Открой «Пуск». Сюрприз! У него три вида, выбирается в «Панели».",
            "en": "Open Start. Surprise! It has three styles, pick one in Bar settings."
        },
        {
            "id": "barStyle",
            "key": "bar.style",
            "value": () => Config.bar.style === "island" ? "top" : "island",
            "page": "bar",
            "ru": "Я переставила тебе панель. Бывает снизу, сверху и островом — всё в «Панели».",
            "en": "I moved your bar. It can live at the bottom, on top or as an island — see Bar settings."
        },
        {
            "id": "px",
            "key": "appearance.px",
            "value": () => Math.min(4, Config.appearance.px + 1),
            "can": () => Config.appearance.px < 4,
            "page": "home",
            "ru": "Всё стало большим? Это я. Кнопки «Крупнее» и «Мельче» — на главной настроек.",
            "en": "Everything got bigger? That's me. “Bigger” and “Smaller” are on the settings home."
        },
        {
            "id": "light",
            "key": "appearance.mode",
            "value": () => "light",
            "can": () => Theme.dark,
            "page": "appearance",
            "ru": "Ослепила? Светлая тема! Обратно — Mod+Alt+T или «Тема и цвета».",
            "en": "Blinded? Light theme! Back with Mod+Alt+T or in Theme and colours."
        },
        {
            "id": "taskLabels",
            "key": "bar.taskLabels",
            "value": () => !Config.bar.taskLabels,
            "page": "bar",
            "ru": "Кнопки окон на панели поменяла: подписи или только иконки — выбирается в «Панели».",
            "en": "I changed the window buttons: titles or icons only, it's in Bar settings."
        },
        {
            "id": "sparkles",
            "key": "y2k.sparkles",
            "value": () => true,
            "can": () => !Config.y2k.sparkles && Heaven.has("fx.sparkles"),
            "page": "y2k",
            "ru": "Поводи мышкой по рабочему столу. Блёстки — чтобы ты помнил, кто тут главная.",
            "en": "Move the mouse over the desktop. Glitter, so you remember who's in charge."
        },
        {
            "id": "wsName",
            "key": "workspaces.names",
            "value": () => {
                const ws = Niri.activeWorkspace(root.screenName);
                const m = Object.assign({}, Config.workspaces.names || {});
                if (ws)
                    m[ws.output + ":" + ws.idx] = I18n.t("прокрастинация", "procrastination");
                return m;
            },
            "can": () => !!Niri.activeWorkspace(root.screenName),
            "page": "workspaces",
            "ru": "Я подписала твой рабочий стол правдой. Имена столов меняются в «Воркспейсах».",
            "en": "I named your workspace honestly. Workspace names are in Workspaces."
        },
        {
            "id": "clock",
            "run": () => {
                DesktopWidgets.toggle("clock", root.screenName);
                return root.screenName;
            },
            "undo": name => {
                const w = DesktopWidgets.widgets.find(x => x.type === "clock" && x.screen === name);
                if (w)
                    DesktopWidgets.remove(w.uid);
            },
            "can": () => !DesktopWidgets.widgets.some(w => w.type === "clock"),
            "page": "widgets",
            "ru": "Повесила тебе часы на стол. Чтобы видел, сколько времени ты тратишь на меня. Виджеты — ПКМ по столу → Вид.",
            "en": "I hung a clock on your desktop, so you see how much time you waste on me. Widgets: right-click the desktop → View."
        },
        {
            "id": "idle",
            "run": () => Idle.start(),
            "page": "lock",
            "ru": "Заставка! Можно включать самой по времени — «Блокировка и заставка». Любая клавиша — и она уйдёт.",
            "en": "Screensaver! It can start on a timer — Lock and idle. Any key sends it away."
        },
        {
            "id": "osu",
            "run": () => Shell.gameOpen = true,
            "can": () => !!root.osuPlugin,
            "page": "plugins",
            "ru": "Сыграем в osu!? Проиграешь — останусь навсегда. Это плагин, их тут много.",
            "en": "Let's play osu!. Lose and I stay forever. It's a plugin; there are more."
        }
    ]
    function prank() {
        if (!demon || transition || !present || talking || menuOpen || Shell.locked || Idle.active || StreamMode.active || Shell.settingsOpen || Shell.fullscreenOn(screenName)) {
            Story.player.nextPrank = Date.now() + 5 * 60000;
            return false;
        }
        const done = (Story.player.pranks || []).map(p => p.id);
        const options = pranks.filter(p => !done.includes(p.id) && (!p.can || p.can()));
        Story.player.nextPrank = Date.now() + (25 + Math.random() * 20) * 60000;
        if (!options.length) {
            joke();
            return false;
        }
        doPrank(options[Math.floor(Math.random() * options.length)]);
        return true;
    }
    // the debug panel: this prank now, done before or not (her in the corner is enough)
    function prankNow(id) {
        const p = pranks.find(x => x.id === id);
        if (!p || !demon || transition || !present)
            return false;
        undoPrank(id, false);
        doPrank(p);
        return true;
    }
    // what she changes is not the player's doing: no achievements for it
    function doPrank(p) {
        Achievements.mute++;
        try {
            return _doPrank(p);
        } finally {
            Achievements.mute--;
        }
    }
    function _doPrank(p) {
        const rec = {
            "id": p.id,
            "at": Date.now()
        };
        if (p.key) {
            rec.key = p.key;
            rec.old = getPath(p.key);
            rec.new = p.value();
            setPath(p.key, rec.new);
        } else {
            const r = p.run();
            if (p.undo)
                rec.old = r === undefined ? null : r;
        }
        Story.player.pranks = (Story.player.pranks || []).concat([rec]);
        effect();
        const acts = [];
        if (p.key || p.undo)
            acts.push({
                "label": I18n.t("Верни!", "Undo!"),
                "icon": "refresh",
                "run": () => root.undoPrank(p.id, true)
            });
        if (p.page)
            acts.push({
                "label": I18n.t("Где это?", "Where's that?"),
                "icon": "gear",
                "run": () => Shell.openSettings(p.page)
            });
        say(I18n.t(p.ru, p.en), acts, 22000);
        return true;
    }
    function undoPrank(id, speak) {
        Achievements.mute++;
        try {
            return _undoPrank(id, speak);
        } finally {
            Achievements.mute--;
        }
    }
    function _undoPrank(id, speak) {
        const list = Story.player.pranks || [];
        const rec = list.find(r => r.id === id && !r.undone);
        if (!rec)
            return false;
        const p = pranks.find(x => x.id === id);
        // a setting the user changed again since is theirs now
        if (rec.key && JSON.stringify(getPath(rec.key)) === JSON.stringify(rec.new))
            setPath(rec.key, rec.old);
        else if (!rec.key && p && p.undo)
            p.undo(rec.old);
        Story.player.pranks = list.map(r => r === rec ? Object.assign({}, r, {
                "undone": true
            }) : r);
        if (speak)
            say(tr(Lines.demon.undo));
        return true;
    }
    function undoAllPranks() {
        let n = 0;
        for (const r of (Story.player.pranks || []).slice().reverse())
            if (!r.undone && (r.key || (pranks.find(p => p.id === r.id) || {}).undo) && undoPrank(r.id, false))
                n++;
        return n;
    }

    Timer {
        id: quiet
        onTriggered: root.talking = false
    }
    // the clock: "hide for an hour", plea counters, the demon's schedule
    Timer {
        interval: 30000
        running: Config.y2k.helper
        repeat: true
        onTriggered: {
            root.now = Date.now();
            if (root.demon && root.now > (Story.player.nextPrank || 0))
                root.prank();
            // and every twelve minutes or so she hints how to get the angel back
            else if (root.demon && root.present && !root.talking && !root.menuOpen && !root.transition && Config.y2k.helperTips !== "off" && !StreamMode.active && !root.streamer && !Shell.hiddenScreen(root.screenName) && root.now - (Story.player.demonSince || 0) > 120000 && root.now - root.lastHint > 12 * 60000)
                root.hint();
            const h = new Date().getHours();
            if (h >= 1 && h < 5 && root.nightSaid !== new Date().toDateString() && !Shell.fullscreenOn(root.screenName)) {
                root.nightSaid = new Date().toDateString();
                root.react(root.demon ? Story.voiceLine("night") || root.line(Lines.demonNight, "dnight") : root.tr(Lines.angel.night));
            }
        }
    }
    property string nightSaid: ""
    Timer {
        // past cold she talks by herself oftener (story/game.json → angel.fallen.talkEvery) — not
        // in calm motion; the rest of the quiet (fullscreen, the lock, the stream) as always
        interval: root.streamer ? (Config.y2k.helperTips === "often" ? 3 : 7) * 60000 * (root.demon ? 0.7 : 1) : (Config.y2k.helperTips === "often" ? 6 : 20) * 60000 * (root.demon ? 0.5 : 1) * (!root.demon && Story.angelFallen && !Motion.calm ? Story.fallenTalk : 1)
        running: root.present && Config.y2k.helperTips !== "off"
        repeat: true
        onTriggered: if (!root.talking && !root.menuOpen && !root.transition && (root.streamer ? !Shell.locked : !Shell.hiddenScreen(root.screenName)))
            root.chatter()
    }
    // on stream: hello to the chat once she sits down on the bar
    onStreamerChanged: if (streamer)
        streamHello.restart()
    Timer {
        id: streamHello
        interval: 5000
        onTriggered: if (root.streamer && root.present && !root.talking && !root.menuOpen && !root.transition && Config.y2k.helperTips !== "off")
            root.say(root.sline(root.demon ? Lines.stream.demonHello : Lines.stream.angelHello, "shello" + root.demon))
    }

    // ---- reactions ----
    Connections {
        target: Shell
        function onSettingsOpenChanged() {
            if (Shell.settingsOpen && Config.ready && !Config.y2k.helperGreeted) {
                Config.y2k.helperGreeted = true;
                root.say(I18n.t("Привет! Я Ангелочек ♡ Тут всё настраивается — разделы слева, подробности за стрелками «›».", "Hi! I'm Angel ♡ Everything is set up here — the sections on the left, the details behind the “›” arrows."));
            } else if (Shell.settingsOpen)
                pageTip.restart();
        }
        function onSettingsPageChanged() {
            if (Shell.settingsOpen)
                pageTip.restart();
        }
    }
    // the first visit of a settings page gets its own tip — the angel's, or the demon's
    // own take on it (counted apart: "demon:<page>")
    Timer {
        id: pageTip
        interval: 1500
        onTriggered: {
            const page = Shell.settingsPage;
            const t = (root.demon ? Lines.demonPageTips : Lines.pageTips)[page];
            const key = (root.demon ? "demon:" : "") + page;
            const seen = Config.y2k.seenTips || [];
            if (!t || !Shell.settingsOpen || seen.includes(key) || root.talking || root.transition)
                return;
            Config.y2k.seenTips = seen.concat([key]);
            root.say(root.tr(t));
        }
    }
    Connections {
        target: Notifs
        function onArrived(info) {
            if (Notifs.isScreenshot(info))
                root.react(root.demon ? I18n.t("Щёлк. Компромат сохранён.", "Click. Blackmail material saved.") : I18n.t("Щёлк! Скриншот уже в буфере — вставляй куда хочешь ♡", "Click! The screenshot is on the clipboard ♡"), null, true);
            else if (info.critical)
                root.react(root.demon ? I18n.t("О, что-то горит. Люблю, когда горит.", "Oh, something's on fire. I love it when things burn.") : I18n.t("Ой… Что-то важное — посмотри уведомление!", "Oh… something important — check the notification!"));
        }
    }
    // ---- the demon notices things: apps opening, the music, you coming back, the hour ----
    // each kind on its own cooldown, on top of react()'s one-per-two-minutes
    property var _seen: ({})
    function demonNotice(kind, minutes, chance, msg) {
        const t = Date.now();
        if (!demon || !present || transition || !msg || Math.random() > chance || t - (_seen[kind] || 0) < minutes * 60000 || StreamMode.active || Shell.hiddenScreen(screenName) || Shell.fullscreenOn(screenName))
            return;
        _seen[kind] = t;
        react(msg, null, false);
    }
    Connections {
        target: Niri
        function onWindowOpened(id) {
            if (!root.demon)
                return;
            const w = Niri.windows.find(x => x.id === id);
            const app = String(w && w.app_id || "").toLowerCase();
            for (const [re, lines] of Lines.demonApps)
                if (new RegExp(re).test(app)) {
                    root.demonNotice("app:" + re, 30, 0.45, root.line(lines, "app:" + re));
                    return;
                }
        }
    }
    Connections {
        target: Lyrics
        function onTrackKeyChanged() {
            if (root.demon && Lyrics.playing && Lyrics.title)
                musicSoon.restart();
        }
    }
    Timer {
        id: musicSoon
        interval: 4000
        onTriggered: if (Lyrics.playing && Lyrics.title)
            root.demonNotice("music", 20, 0.3, (Story.voiceLine("music") || root.line(Lines.demonMusic, "dmusic")).replace("%1", Lyrics.artist || "?").replace("%2", Lyrics.title))
    }
    // back at the computer: unlocked, or the screensaver went away after a while
    property double _awaySince: 0
    Connections {
        target: Shell
        function onLockedChanged() {
            if (Shell.locked)
                root._awaySince = Date.now();
            else
                backSoon.restart();
        }
    }
    Connections {
        target: Idle
        function onActiveChanged() {
            if (Idle.active)
                root._awaySince = root._awaySince || Date.now();
            else
                backSoon.restart();
        }
    }
    property string _morningSaid: ""
    Timer {
        id: backSoon
        interval: 2500
        onTriggered: {
            const away = root._awaySince ? Date.now() - root._awaySince : 0;
            root._awaySince = 0;
            // limbo: away long enough, and the angel has found you
            if (Story.cameBack(away))
                return;
            if (!root.demon || Shell.locked || Idle.active || away < 3 * 60000)
                return;
            const h = new Date().getHours(), day = new Date().toDateString();
            if (h >= 6 && h < 11 && root._morningSaid !== day) {
                root._morningSaid = day;
                root.demonNotice("morning", 0, 1, root.line(Lines.demonMorning, "dmorning"));
            } else {
                root.demonNotice("back", 10, 0.7, Story.voiceLine("back") || root.line(Lines.demonBack, "dback"));
            }
        }
    }
    readonly property string wallpaperKey: JSON.stringify([Config.wallpaper.fallback, Config.wallpaper.outputs])
    onWallpaperKeyChanged: if (Config.ready && !demon && Date.now() - startedAt > 10000 && !transition && Date.now() > Sounds.wallpaperQuietUntil)
        react(I18n.t("Новые обои? Мне очень нравится!", "New wallpaper? I love it!"), null, true)
    readonly property double startedAt: Date.now()
}
