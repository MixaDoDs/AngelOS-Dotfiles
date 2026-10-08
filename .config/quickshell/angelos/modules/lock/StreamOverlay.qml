pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// NEEDY GIRL OVERDOSE "stream" on the lock screen. Everything here is invented locally;
// nothing is sent anywhere.
//   top left   LIVE, viewers (services/LockStream: nobody on day 1, ~1000–1500 by day 30),
//              time on air, the stream day, the title
//   left       the stats of the game (StreamMeters) and the webcam with the angel (StreamCam)
//   right      the chat: people with their own nicks, colours, badges and manners (caps,
//              lowercase, emotes, typos), talking at uneven moments, answering each other,
//              in waves when something happens ("F" for a mistake). It knows what you were
//              doing — the program's name, the song, the hour, never a window title — and
//              what happens while locked (notifications by program name, the next track,
//              the mouse, the replay, how you type). A poll sits on top of it.
//   top middle alerts: donations, raids, followers, subs, viewer milestones
//   clips      every mistake becomes a clip; the unlock shows them (NgoLock's highlights)
Item {
    id: root

    required property var lockScope
    property bool replaying: false
    readonly property var seen: LockStream.seen || ({})
    readonly property int day: LockStream.days
    property int viewers: 0
    property int target: 0
    property int peak: 0
    property int said: 0                       // chat messages on this stream
    property real startedAt: Date.now()
    property int elapsed: 0                    // seconds on air
    property var clips: []                     // {n, title, at}
    readonly property var camAngel: cam.visible ? cam.angel : null
    property string bestLine: ""

    // ---- people: the regulars are the same every day, the rest come and go ----
    property int seed: 1
    function rand() {
        // mulberry32: the same regulars every stream
        seed = (seed + 0x6D2B79F5) | 0;
        let t = seed;
        t = Math.imul(t ^ (t >>> 15), t | 1);
        t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    }
    readonly property var heads: ["ame", "kangel", "pixel", "net", "hiki", "sugar", "moe", "pill", "jine", "y2k", "cyber", "milk", "ghost", "neko", "usagi", "angel", "yami", "lofi", "404", "sad", "kawaii", "byte", "mochi", "star", "void", "cloud"]
    readonly property var tails: ["_fan", "chan", "_love", "girl", "_irl", "tea", "cat", "_dayo", "kun", "_uwu", "_rin", "bunny", "_x", "lord", "_desu", "", "", ""]
    property var people: []
    function makePeople() {
        seed = 20260928;
        const list = [
            {
                "nick": "first_fan",
                "style": "proper",
                "mod": false,
                "months": Math.floor(day / 30) + 1
            },
            {
                "nick": "angel_mod",
                "style": "proper",
                "mod": true,
                "months": Math.floor(day / 30) + 1
            }
        ];
        const styles = ["lower", "lower", "emote", "caps", "proper", "typo", "lower", "emote"];
        const used = {};
        while (list.length < 70) {
            let n = heads[Math.floor(rand() * heads.length)] + tails[Math.floor(rand() * tails.length)];
            if (rand() < 0.35)
                n += Math.floor(rand() * 999);
            if (used[n])
                continue;
            used[n] = true;
            list.push({
                "nick": n,
                "style": styles[Math.floor(rand() * styles.length)],
                "mod": false,
                "months": rand() < 0.3 ? 1 + Math.floor(rand() * Math.max(1, day / 7)) : 0
            });
        }
        seed = Date.now() & 0x7fffffff;
        people = list;
    }
    // how many of them are talking: one or two on a quiet day, everyone on a big one
    readonly property int chatters: viewers <= 0 ? 0 : Math.min(people.length, viewers < 4 ? viewers : Math.round(3 + Math.sqrt(viewers) * 1.6))
    function person() {
        const n = Math.max(1, chatters);
        // the regulars talk more
        const i = Math.random() < 0.35 ? Math.floor(Math.random() * Math.min(n, 6)) : Math.floor(Math.random() * n);
        return people[i] || people[0];
    }
    function colorOf(nick) {
        let h = 0;
        for (let i = 0; i < nick.length; i++)
            h = (h * 31 + nick.charCodeAt(i)) % 360;
        return Qt.hsla(h / 360, 0.75, Theme.dark ? 0.7 : 0.42, 1);
    }

    // ---- how people write ----
    readonly property var emotes: [":3", "))", ")))", "xD", "♡", "🥺", "KEKW", "OMEGALUL", "<3", "😭", "💀", "uwu", ">_<", "^^"]
    function pick(list) {
        return list[Math.floor(Math.random() * list.length)];
    }
    function typo(s) {
        if (s.length < 5)
            return s;
        const i = 1 + Math.floor(Math.random() * (s.length - 3));
        return s.slice(0, i) + s[i + 1] + s[i] + s.slice(i + 2);
    }
    function humanize(text, p) {
        let s = String(text);
        if (p.style === "lower" || (p.style !== "proper" && Math.random() < 0.4))
            s = s.toLowerCase().replace(/[.!]+$/, "");
        if (p.style === "caps" && Math.random() < 0.5)
            s = s.toUpperCase();
        if (p.style === "typo" && Math.random() < 0.35)
            s = typo(s);
        // a stretched vowel now and then: "дааа", "pleeease"
        if (Math.random() < 0.12)
            s = s.replace(/([аоеиуяaeiou])(?=[^аоеиуяaeiou]*$)/i, "$1$1$1");
        if (p.style === "emote" ? Math.random() < 0.7 : Math.random() < 0.18)
            s += " " + pick(emotes);
        return s;
    }

    // ---- the chat itself ----
    ListModel {
        id: chatModel
    }
    property var recent: []                    // the last texts, so nobody repeats them at once
    property bool scrollAnim: true
    function fill(s) {
        const d = new Date();
        return String(s).replace(/\{app\}/g, seen.app || "?").replace(/\{song\}/g, seen.song || "").replace(/\{artist\}/g, seen.artist || "").replace(/\{n\}/g, String(seen.windows || 0)).replace(/\{d\}/g, String(day)).replace(/\{layout\}/g, Niri.layoutShort || seen.layout || "").replace(/\{time\}/g, Qt.formatTime(d, "HH:mm")).replace(/\{up\}/g, Math.floor((seen.uptimeMin || 0) / 60) + I18n.t(" ч", " h"));
    }
    // kind: "" a viewer, "bot" the channel's bot, "sc" a super chat (yen)
    function post(text, kind, who, amount) {
        const k = kind || "";
        const p = who || (k === "bot" ? null : person());
        let t = fill(text);
        if (k === "" && p)
            t = humanize(t, p);
        if (k === "" && recent.includes(t))
            return;
        recent = recent.concat([t]).slice(-12);
        chatModel.append({
            "nick": k === "bot" ? "angelbot" : p.nick,
            "text": t,
            "col": k === "bot" ? String(Theme.accent) : String(colorOf(p.nick)),
            "kind": k,
            "badge": k === "bot" ? "✦" : p.mod ? "⚔" : p.months > 0 ? "★" + p.months : "",
            "amount": amount || 0
        });
        said++;
        if (k === "" && t.length > 14 && Math.random() < 0.3)
            bestLine = p.nick + ": " + t;
        if (chatModel.count > 40) {
            scrollAnim = false;
            chatModel.remove(0, chatModel.count - 40);
            Qt.callLater(() => root.scrollAnim = true);
        }
    }
    // a viewer says one of these; nobody watching — the bot says the second list, if any
    function say(lines, botLines) {
        if (viewers > 0 && lines.length)
            post(pick(lines));
        else if (botLines && botLines.length)
            post(pick(botLines), "bot");
    }
    // several people at once, a little apart: a wave
    property var queue: []
    function wave(lines, count, spread) {
        if (viewers <= 0)
            return;
        const n = Math.min(count, Math.max(1, chatters));
        const q = queue.slice();
        let at = 0;
        for (let i = 0; i < n; i++) {
            at += 120 + Math.random() * (spread || 500);
            q.push({
                "at": Date.now() + at,
                "text": pick(lines)
            });
        }
        queue = q;
        flush.start();
    }
    Timer {
        id: flush
        interval: 60
        repeat: true
        onTriggered: {
            const now = Date.now();
            const due = root.queue.filter(m => m.at <= now);
            if (due.length) {
                root.queue = root.queue.filter(m => m.at > now);
                for (const m of due)
                    root.post(m.text);
            }
            if (!root.queue.length)
                stop();
        }
    }

    // ---- what they say ----
    readonly property var idleLines: [I18n.t("ждём ангела", "waiting for angel"), "brb?", I18n.t("кто тут", "who's here"), I18n.t("какие обои красивые", "love this wallpaper"), I18n.t("пароль не подсматриваем 👀", "no peeking at the password 👀"), I18n.t("пейте воду, чат", "drink water, chat"), "OMG kawaii", I18n.t("ангел возвращайся", "angel come back"), "♡♡♡", "internet angel ✧", I18n.t("перерыв затянулся", "long break huh"), "W", "lol", I18n.t("чат живой?", "chat alive?"), I18n.t("я просто посмотреть", "just lurking"), I18n.t("всем привет", "hi all"), I18n.t("о, я успел", "oh I made it"), I18n.t("что я пропустил", "what did I miss"), I18n.t("ору с этого стрима", "this stream lmao"), I18n.t("а музыку можно громче", "turn the music up"), I18n.t("я спать скоро", "going to sleep soon"), I18n.t("у кого ещё ночь", "who else is up at night"), I18n.t("ангел лучшая", "angel is the best"), I18n.t("скучно без неё", "boring without her"), I18n.t("кто-нибудь знает когда она вернётся", "anyone know when she's back"), I18n.t("сижу с чаем", "sitting here with tea"), I18n.t("лайк поставил", "liked"), I18n.t("я с работы смотрю тихонько", "watching from work quietly")]
    readonly property var replyLines: [I18n.t("реал", "real"), "+", I18n.t("ахахах", "lmao"), I18n.t("база", "based"), I18n.t("согл", "agreed"), I18n.t("ты тут каждый день лол", "you're here every day lol"), I18n.t("привет!!", "hi!!"), I18n.t("не, ну это правда", "no but that's true"), I18n.t("чё", "what"), I18n.t("ору", "dying"), I18n.t("ты чего", "you ok"), "^", I18n.t("плюсую", "this")]
    readonly property var questionLines: [I18n.t("кто с первого дня тут?", "who's here since day one?"), I18n.t("а вы откуда все?", "where's everyone from?"), I18n.t("чат, что слушаете?", "chat, what are you listening to?"), I18n.t("кто тоже не спит?", "who else can't sleep?")]
    readonly property var emoteOnly: ["♡", "♡♡♡", "KEKW", ":3", "🥺", ")))", "uwu", "💀", "OMEGALUL", "<3 <3"]
    readonly property var loneBot: [I18n.t("зрителей: 0. все с чего-то начинали ♡", "viewers: 0. everyone starts somewhere ♡"), I18n.t("эхо… эхо…", "echo… echo…"), I18n.t("стрим идёт, даже если никто не смотрит", "the stream is on even if nobody watches"), I18n.t("день {d}. зрители придут, обещаю", "day {d}. viewers will come, promise")]
    readonly property var typingLines: [I18n.t("она печатает", "she's typing"), I18n.t("вижу сердечки", "I see hearts"), I18n.t("давай давай", "go go go"), I18n.t("чат тихо", "chat quiet"), I18n.t("вернулась!!", "she's back!!"), I18n.t("ОНА ТУТ", "SHE'S HERE")]
    readonly property var fastLines: [I18n.t("скорость печати 😳", "that typing speed 😳"), I18n.t("пальцы-молнии", "lightning fingers"), "COMBO!!", I18n.t("спидран пароля", "password speedrun")]
    readonly property var eraseLines: [I18n.t("стирает… сомневается", "erasing… doubting"), I18n.t("опечатка бывает", "typo happens"), "backspace arc", I18n.t("думай думай", "think think")]
    readonly property var capsLines: [I18n.t("КАПС", "CAPS"), I18n.t("капс включён!!", "caps lock is on!!"), I18n.t("ПОЧЕМУ МЫ КРИЧИМ", "WHY ARE WE YELLING")]
    readonly property var winLines: ["GG", "♡♡♡", I18n.t("УРА", "YAY"), I18n.t("она вернулась!!", "she's back!!"), I18n.t("с возвращением", "welcome back"), "W", "LETSGO"]
    readonly property var failLines: ["F", "F", "F", "💀", I18n.t("мимо", "miss"), "KEKW", I18n.t("ахахах", "lmao"), I18n.t("бывает", "it happens")]
    readonly property var mouseLines: [I18n.t("мышка дёрнулась 👀", "the mouse moved 👀"), I18n.t("кто-то есть?", "someone there?"), I18n.t("кот прошёл по столу", "a cat walked on the desk")]
    readonly property var replayLines: [I18n.t("о повтор", "oh a replay"), I18n.t("что там ничего не видно 😭", "can't see a thing 😭"), I18n.t("блюр спасает приватность", "blur saves privacy"), I18n.t("я помню этот момент", "I remember this"), I18n.t("клипните кто-нибудь", "someone clip it")]
    readonly property var scLines: [I18n.t("на кофе ♡", "for coffee ♡"), I18n.t("спасибо за стримы", "thanks for the streams"), I18n.t("ангел ты лучшая", "angel you're the best"), I18n.t("за обои", "for the wallpaper"), I18n.t("купи себе пиццу", "buy yourself a pizza")]

    // what was on screen when it locked: said once each, by whoever
    property var contextLeft: []
    function contextLines() {
        const s = seen;
        const out = [];
        const kindLines = ({
                "game": [I18n.t("{app} на паузе? я только зашёл", "{app} paused? just got here"), I18n.t("GG в {app}?", "GG in {app}?"), I18n.t("опять {app} до утра", "{app} till dawn again")],
                "code": [I18n.t("в {app} что-то не собирается, ушла за чаем", "something in {app} won't build, went for tea"), I18n.t("кодит в {app} ♡", "coding in {app} ♡"), I18n.t("коммит хоть сделала?", "did you at least commit?")],
                "terminal": [I18n.t("в терминале что-то крутилось 👀", "something was running in the terminal 👀"), "sudo make me a sandwich"],
                "browser": [I18n.t("вкладок открыто: да", "tabs open: yes"), I18n.t("что гуглила 👀", "what were you googling 👀")],
                "chat": [I18n.t("в {app} кто-то ждёт ответа", "someone in {app} waits for a reply"), I18n.t("не отвечай им побудь с нами", "don't answer them, stay with us")],
                "obs": [I18n.t("стример ушёл, OBS остался", "the streamer left, OBS stayed")],
                "media": [I18n.t("{app} оставила играть", "left {app} playing")],
                "files": [I18n.t("разбирала файлы… ну-ну", "sorting files… sure")],
                "art": [I18n.t("рисунок в {app} уже видели?", "seen the drawing in {app}?"), I18n.t("арт стрим!!", "art stream!!")],
                "app": [I18n.t("что за {app}", "what's {app}"), I18n.t("{app} база", "{app} is based")]
            })[s.kind] || [];
        if (kindLines.length)
            out.push(pick(kindLines));
        if (s.playing && s.song)
            out.push(pick([I18n.t("♪ {song} — бэнгер", "♪ {song} is a banger"), I18n.t("кто узнал трек? {song}", "who knows the track? {song}")]));
        if (s.windows >= 8)
            out.push(I18n.t("{n} окон открыто, это рекорд?", "{n} windows open, a record?"));
        if (s.hour >= 0 && s.hour < 5)
            out.push(pick([I18n.t("уже {time}… иди спать", "it's {time}… go to sleep"), I18n.t("ночной стрим", "night stream")]));
        else if (s.hour >= 5 && s.hour < 10)
            out.push(I18n.t("утренний стрим! доброе утро", "a morning stream! good morning"));
        if ((s.uptimeMin || 0) > 360)
            out.push(I18n.t("комп не выключался {up}", "the PC has been on for {up}"));
        if (day === 1)
            out.push(I18n.t("первый стрим!! 🎉", "first stream!! 🎉"));
        else if (Math.random() < 0.5)
            out.push(I18n.t("день {d}, я тут с первого дня", "day {d}, here since day one"));
        return out;
    }

    // ---- a stream starts ----
    Component.onCompleted: {
        makePeople();
        viewers = LockStream.rollViewers(day);
        target = viewers;
        peak = viewers;
        contextLeft = contextLines();
        post(viewers > 0 ? I18n.t("стрим начался · день {d}", "stream started · day {d}") : I18n.t("стрим начался · день {d} · пока никого", "stream started · day {d} · nobody yet"), "bot");
        if (viewers > 0)
            wave([I18n.t("привет", "hi"), I18n.t("приветик", "hiii"), "o/", I18n.t("первый", "first"), "♡"], Math.min(4, viewers), 900);
        next.restart();
    }

    // ---- the audience lives ----
    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            root.elapsed = Math.floor((Date.now() - root.startedAt) / 1000);
            if (Math.random() < 0.06)
                root.target = LockStream.rollViewers(root.day);
            const d = root.target - root.viewers;
            const before = root.viewers;
            root.viewers = Math.max(0, root.viewers + (Math.abs(d) <= 2 ? d : Math.round(d * 0.15 + (Math.random() - 0.5) * Math.max(2, root.viewers * 0.01))));
            root.peak = Math.max(root.peak, root.viewers);
            for (const m of [10, 50, 100, 500, 1000, 2000])
                if (before < m && root.viewers >= m && root.elapsed > 3)
                    root.alert("milestone", I18n.t("%1 зрителей!!", "%1 viewers!!").arg(m), I18n.t("спасибо, что вы тут ♡", "thank you for being here ♡"));
            const m = root.elapsed / 60;
            if (root.elapsed % 60 === 0 && [1, 5, 15, 30, 60, 120].includes(m))
                root.say(m === 1 ? [I18n.t("уже минуту AFK", "a minute AFK already")] : m < 30 ? [I18n.t("уже %1 мин без ангела", "%1 min without angel").arg(m), I18n.t("стример ты где??", "streamer where are you??")] : [I18n.t("%1 минут… чат засыпает 💤", "%1 minutes… chat is falling asleep 💤").arg(m)], [I18n.t("перерыв: %1 мин", "break: %1 min").arg(m)]);
            root.pollTick();
            if (Config.lock.streamAlerts && root.elapsed % 20 === 0 && root.elapsed > 0)
                root.maybeAlert();
        }
    }
    // the chat: uneven gaps, busier with more people; nobody — the bot, rarely
    Timer {
        id: next
        onTriggered: {
            root.chatter();
            const mean = root.viewers <= 0 ? 22000 : Math.max(700, 9000 / (1 + Math.log(root.viewers + 1) / Math.LN10 * 1.6));
            interval = Math.round(Math.min(mean * 3, -Math.log(1 - Math.random()) * mean) + 250);
            restart();
        }
    }
    function chatter() {
        if (viewers <= 0) {
            if (Math.random() < 0.4)
                post(pick(loneBot), "bot");
            return;
        }
        const r = Math.random();
        if (contextLeft.length && r < 0.22) {
            post(contextLeft[0]);
            contextLeft = contextLeft.slice(1);
        } else if (r < 0.42 && chatModel.count > 1) {
            // an answer to someone above
            const last = chatModel.get(chatModel.count - 1 - Math.floor(Math.random() * Math.min(3, chatModel.count - 1)));
            if (last && last.kind === "")
                post("@" + last.nick + " " + pick(replyLines));
            else
                post(pick(idleLines));
        } else if (r < 0.5) {
            post(pick(emoteOnly));
        } else if (r < 0.55) {
            post(pick(questionLines));
        } else {
            post(pick(idleLines));
        }
    }

    // ---- alerts (top middle): donations, raids, followers, subs, milestones ----
    property var alerts: []
    property var current: null
    function alert(kind, title, sub) {
        if (!Config.lock.streamAlerts)
            return;
        alerts = alerts.concat([
            {
                "kind": kind,
                "title": title,
                "sub": sub || ""
            }
        ]);
        if (!current)
            nextAlert();
    }
    function nextAlert() {
        if (!alerts.length) {
            current = null;
            return;
        }
        current = alerts[0];
        alerts = alerts.slice(1);
        alertPop.restart();
        alertLife.restart();
    }
    Timer {
        id: alertLife
        interval: 3600
        onTriggered: root.nextAlert()
    }
    function maybeAlert() {
        const r = Math.random();
        if (viewers > 150 && r < 0.18) {
            const p = person();
            const amount = pick([300, 500, 500, 1000, 2000, 5000, 10000]);
            const msg = pick(scLines);
            alert("donation", I18n.t("%1 задонатил(а) ¥%2", "%1 donated ¥%2").arg(p.nick).arg(amount), msg);
            post(msg, "sc", p, amount);
        } else if (viewers > 40 && r < 0.26) {
            const p = person();
            const n = Math.round(viewers * (0.08 + Math.random() * 0.25));
            alert("raid", I18n.t("РЕЙД! %1", "RAID! %1").arg(p.nick), I18n.t("ведёт %1 зрителей", "brings %1 viewers").arg(n));
            target += n;
            viewers += n;
            wave([I18n.t("РЕЙД", "RAID"), I18n.t("привет из рейда", "hi from the raid"), "o/", "♡"], 5, 600);
        } else if (viewers > 10 && r < 0.4) {
            const p = person();
            alert("follow", I18n.t("новый подписчик", "new follower"), p.nick + " ♡");
        } else if (viewers > 20 && r < 0.5) {
            const p = people[Math.floor(Math.random() * Math.min(10, people.length))];
            alert("sub", I18n.t("%1 с нами уже %2 мес.", "%1 subscribed for %2 months").arg(p.nick).arg(Math.max(1, p.months)), I18n.t("спасибо за поддержку ♡", "thank you for the support ♡"));
        }
    }

    // ---- polls (on top of the chat) ----
    property var poll: null           // {q, a: [labels], v: [votes], kind, done, win}
    property int pollAt: 15 + Math.floor(Math.random() * 25)
    function pollTick() {
        if (!Config.lock.streamAlerts)
            return;
        if (!poll && elapsed >= pollAt && viewers >= 3 && !lockScope.unlocking) {
            const k = lockScope.fails > 0 || Math.random() < 0.4 ? "afk" : "first";
            poll = k === "first" ? {
                "kind": k,
                "q": I18n.t("войдёт с первой попытки?", "first try?"),
                "a": [I18n.t("да", "yes"), I18n.t("нет", "no")],
                "v": [0, 0],
                "done": false,
                "win": -1,
                "until": 0
            } : {
                "kind": k,
                "q": I18n.t("сколько ещё AFK?", "how much longer AFK?"),
                "a": I18n.english ? ["< 5 min", "> 5 min"] : ["< 5 мин", "> 5 мин"],
                "v": [0, 0],
                "done": false,
                "win": -1,
                "until": elapsed + 300
            };
            post(I18n.t("опрос: %1", "poll: %1").arg(poll.q), "bot");
            return;
        }
        if (!poll)
            return;
        if (!poll.done) {
            // votes come in with the audience, leaning to the first answer
            const p = Object.assign({}, poll);
            const n = Math.round(Math.random() * Math.max(1, viewers * 0.03));
            const yes = Math.round(n * (0.45 + Math.random() * 0.3));
            p.v = [p.v[0] + yes, p.v[1] + n - yes];
            poll = p;
            if (poll.kind === "afk" && elapsed >= poll.until)
                endPoll(1);
        } else if (elapsed >= poll.until) {
            poll = null;
            pollAt = elapsed + 60 + Math.floor(Math.random() * 120);
        }
    }
    function endPoll(win) {
        if (!poll || poll.done)
            return;
        const p = Object.assign({}, poll);
        p.done = true;
        p.win = win;
        p.until = elapsed + 10;
        poll = p;
        const total = Math.max(1, p.v[0] + p.v[1]);
        post(I18n.t("опрос окончен: «%1» (%2%)", "poll over: “%1” (%2%)").arg(p.a[win]).arg(Math.round(p.v[win] / total * 100)), "bot");
        if (p.v[win] < p.v[1 - win])
            wave([I18n.t("кто ставил «%1» 💀", "who voted “%1” 💀").arg(p.a[1 - win]), I18n.t("я так и знал", "knew it"), "KEKW"], 3, 700);
    }

    // ---- what happens while locked ----
    Connections {
        target: LockStream
        function onNotifiedChanged() {
            const n = LockStream.notified;
            if (!n.length)
                return;
            const app = n[n.length - 1];
            root.say([I18n.t("%1 пишет! 📩", "%1 is texting! 📩"), I18n.t("у тебя сообщение в %1", "you've got a message in %1"), I18n.t("%1 опять спамит", "%1 is spamming again"), I18n.t("ангел, тебе в %1 пишут", "angel, %1 wants you")].map(l => l.arg(app)), [I18n.t("уведомление: %1", "notification: %1").arg(app)]);
        }
    }
    property string song: Lyrics.title
    onSongChanged: if (song)
        say([I18n.t("о следующий трек: %1", "oh next track: %1").arg(song), "♪ " + song, I18n.t("%1 — хорош", "%1 slaps").arg(song)])
    onReplayingChanged: if (replaying)
        wave(replayLines, 3, 900)

    property real _lastTyping: 0
    property real _lastErase: 0
    property bool _capsSaid: false
    property int _fastSaid: 0
    property real _firstKey: 0
    Connections {
        target: root.lockScope
        function onTyped(length, added) {
            const now = Date.now();
            if (added && length === 1)
                root._firstKey = now;
            if (!added && now - root._lastErase > 4000) {
                root._lastErase = now;
                root.say(root.eraseLines);
                return;
            }
            if (added && length >= 6 && root._fastSaid < 1 && (now - root._firstKey) / length < 140) {
                root._fastSaid++;
                root.wave(root.fastLines, 2, 400);
                return;
            }
            if (root.lockScope.caps && !root._capsSaid) {
                root._capsSaid = true;
                root.wave(root.capsLines, 2, 300);
                return;
            }
            if (now - root._lastTyping > 4000) {
                root._lastTyping = now;
                root.wave(root.typingLines, 1 + Math.floor(Math.random() * 3), 600);
            }
        }
        function onShake() {
            const f = root.lockScope.fails;
            root.wave(root.failLines, 3 + Math.min(5, f * 2), 350);
            if (f === 2)
                root.say([I18n.t("капс не нажат?", "caps lock?"), I18n.t("раскладка %1?", "layout %1?").arg(Niri.layoutShort)]);
            else if (f >= 4)
                root.say([I18n.t("ангел это вообще ты?", "angel is that even you?"), I18n.t("чат звоним в поддержку", "chat call support")]);
            // the mistake becomes a clip
            const title = root.lockScope.caps ? I18n.t("капс-катастрофа", "caps catastrophe") : f === 1 ? I18n.t("ангел забыл(а) пароль", "angel forgot the password") : f === 2 ? I18n.t("попытка №2", "attempt #2") : f === 3 ? I18n.t("третий раз не везёт", "third time unlucky") : I18n.t("пароль-спидран ×%1", "password speedrun ×%1").arg(f);
            root.clips = root.clips.concat([
                {
                    "n": root.clips.length + 1,
                    "title": title,
                    "at": root.elapsed
                }
            ]);
            if (root.viewers > 0)
                root.post(I18n.t("✂ %1 сделал(а) клип: «%2»", "✂ %1 clipped it: “%2”").arg(root.person().nick).arg(title), "bot");
            if (root.poll && root.poll.kind === "first")
                root.endPoll(1);
            root.viewers = Math.max(0, root.viewers - Math.ceil(root.viewers * 0.02));
            root._capsSaid = false;
        }
        function onSuccess() {
            const c = root.lockScope.claimed;
            if (c)
                root.alert("milestone", I18n.t("награда за вход", "login reward"), I18n.t("+%1 ✦ · серия %2", "+%1 ✦ · streak %2").arg(c.n).arg(LockStream.streak));
            const w = root.lockScope.wished;
            if (w) {
                wishTalk.lines = w.stars >= 5 ? [I18n.t("ЛЕГЕНДАРКА!!!", "LEGENDARY!!!"), I18n.t("5★ ПОЗДРАВЛЯЮ", "5★ CONGRATS"), I18n.t("ВОТ ЭТО ВЕЗЕНИЕ", "WHAT LUCK"), I18n.t("золото!!", "gold!!"), "OMG"] : w.stars === 4 ? [I18n.t("фиолетовая!", "purple!"), I18n.t("4★ неплохо", "4★ not bad"), "W", "pog"] : [I18n.t("синяя…", "blue…"), I18n.t("ну хоть что-то", "better than nothing"), I18n.t("3★ классика", "3★ classic"), "F"];
                // what it is stays in the chest on the desktop; the chat only sees the colour
                wishTalk.lines = wishTalk.lines.concat([I18n.t("открывай сундук!!", "open the chest!!")]);
                wishTalk.interval = w.stars >= 5 ? 1300 : w.stars === 4 ? 1000 : 800;
                wishTalk.restart();
            }
            if (root.poll && root.poll.kind === "first")
                root.endPoll(root.lockScope.fails === 0 ? 0 : 1);
            if (root.poll && root.poll.kind === "afk")
                root.endPoll(0);
            root.wave(root.winLines, 6, 260);
            if (root.seen.app)
                root.say([I18n.t("назад в %1!", "back to %1!").arg(root.seen.app)]);
            root.viewers += Math.max(1, Math.round(root.viewers * 0.08));
        }
    }
    // the chat sees the capsule open
    Timer {
        id: wishTalk
        property var lines: []
        onTriggered: root.wave(lines, lines.length > 5 ? 8 : 4, 300)
    }
    // stars that come in while locked: the bot says so (not the minute-by-minute ones)
    Connections {
        target: HeavenStars
        function onRewarded(text) {
            if (!text.endsWith("· "))
                root.post(text, "bot");
        }
    }
    function mouseMoved() {
        if (Date.now() - _lastMouse > 20000) {
            _lastMouse = Date.now();
            say(mouseLines);
        }
    }
    property real _lastMouse: Date.now()
    // the stats speak up once when they get high
    property bool _stressSaid: false
    property bool _darkSaid: false
    function onMeters(stress, dark) {
        if (stress > 80 && !_stressSaid) {
            _stressSaid = true;
            wave([I18n.t("стресс %1, отдохни", "stress %1, take a break").arg(stress), I18n.t("комп пыхтит", "the PC is huffing")], 2, 600);
        }
        if (dark > 80 && !_darkSaid) {
            _darkSaid = true;
            say([I18n.t("тьма растёт…", "the darkness grows…"), I18n.t("уже совсем ночь", "it's deep night")]);
        }
    }

    // ---- top left: LIVE, viewers, time on air, day, title ----
    Row {
        id: topRow
        x: Theme.u * 10
        y: Theme.u * 10
        spacing: Theme.u * 4
        PxBox {
            width: live.implicitWidth + Theme.u * 10
            height: Theme.u * 15
            color: Theme.danger
            Row {
                id: live
                anchors.centerIn: parent
                spacing: Theme.u * 3
                Rectangle {
                    width: Theme.u * 4
                    height: width
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#ffffff"
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: root.visible && !Motion.still
                        alwaysRunToEnd: true
                        PropertyAction {
                            value: 1
                        }
                        PauseAnimation {
                            duration: Motion.ms(600)
                        }
                        PropertyAction {
                            value: 0.2
                        }
                        PauseAnimation {
                            duration: Motion.ms(600)
                        }
                    }
                }
                PxText {
                    text: "LIVE"
                    color: "#ffffff"
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
        PxBox {
            width: viewersRow.implicitWidth + Theme.u * 10
            height: Theme.u * 15
            color: Qt.alpha(Theme.face, 0.85)
            Row {
                id: viewersRow
                anchors.centerIn: parent
                spacing: Theme.u * 3
                PxIcon {
                    name: root.viewers > 0 ? "eye" : "ghost"
                    anchors.verticalCenter: parent.verticalCenter
                }
                PxText {
                    text: root.viewers.toLocaleString(Qt.locale(), "f", 0)
                    font.family: Theme.fontMono
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
        PxBox {
            width: airRow.implicitWidth + Theme.u * 10
            height: Theme.u * 15
            color: Qt.alpha(Theme.face, 0.85)
            Row {
                id: airRow
                anchors.centerIn: parent
                spacing: Theme.u * 3
                PxText {
                    text: {
                        const e = root.elapsed;
                        const p = n => (n < 10 ? "0" : "") + n;
                        return p(Math.floor(e / 3600)) + ":" + p(Math.floor(e / 60) % 60) + ":" + p(e % 60);
                    }
                    font.family: Theme.fontMono
                    anchors.verticalCenter: parent.verticalCenter
                }
                PxText {
                    text: I18n.t("· день ", "· day ") + root.day
                    color: Theme.accent
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
        // heaven's stars ✦ (services/HeavenStars): the wishes cost them
        PxBox {
            width: starsText.implicitWidth + Theme.u * 10
            height: Theme.u * 15
            color: Qt.alpha(Theme.face, 0.85)
            PxText {
                id: starsText
                anchors.centerIn: parent
                text: "✦ " + HeavenStars.stars
                color: Theme.accent3
                font.bold: true
            }
        }
        PxBox {
            visible: root.replaying
            width: replayRow.implicitWidth + Theme.u * 10
            height: Theme.u * 15
            color: Theme.accent
            Row {
                id: replayRow
                anchors.centerIn: parent
                spacing: Theme.u * 3
                PxIcon {
                    name: "play"
                    ink: "#ffffff"
                    fill: "#ffffff"
                    anchors.verticalCenter: parent.verticalCenter
                }
                PxText {
                    text: I18n.t("ПОВТОР", "REPLAY")
                    color: "#ffffff"
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
        PxText {
            anchors.verticalCenter: parent.verticalCenter
            text: Config.lock.streamTitle || (root.seen.app ? I18n.t("ушла из %1 на перерыв ♡ скоро вернусь", "left %1 for a break ♡ brb").arg(root.seen.app) : I18n.t("ангел ушёл на перерыв ♡ скоро вернусь", "angel is on a break ♡ be right back"))
            color: "#ffffff"
            style: Text.Outline
            styleColor: Theme.edge
        }
    }

    // ---- left: the game's stats, the webcam ----
    StreamMeters {
        id: meters
        visible: Config.lock.streamMeters
        x: Theme.u * 10
        y: topRow.y + topRow.height + Theme.u * 8
        width: Theme.u * 120
        stream: root
        onChanged: (stress, dark) => root.onMeters(stress, dark)
    }
    StreamGoals {
        x: Theme.u * 10
        y: meters.visible ? meters.y + meters.height + Theme.u * 6 : topRow.y + topRow.height + Theme.u * 8
        width: Theme.u * 120
    }
    StreamCam {
        id: cam
        visible: Config.lock.streamCam
        x: Theme.u * 10
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.u * 10
        width: Theme.u * 120
        lockScope: root.lockScope
    }

    // ---- alert (top middle) ----
    PxBox {
        id: alertBox
        visible: root.current !== null && pop > 0
        anchors.horizontalCenter: parent.horizontalCenter
        y: topRow.y + topRow.height + Theme.u * 10
        width: alertRow.implicitWidth + Theme.u * 20
        height: alertRow.implicitHeight + Theme.u * 12
        color: root.current && root.current.kind === "raid" ? Theme.danger : root.current && root.current.kind === "donation" ? Theme.mix(Theme.accent3, Theme.accent, 0.4) : Theme.accent
        shadow: true
        property real pop: 0
        property real bob: 0
        scale: pop
        NumberAnimation on bob {
            running: alertBox.visible && !Motion.still
            loops: Animation.Infinite
            from: 0
            to: Math.PI * 2
            duration: 700
        }
        Row {
            id: alertRow
            anchors.centerIn: parent
            spacing: Theme.u * 6
            PxIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: !root.current ? "heart" : ({
                        "donation": "heart",
                        "raid": "sparkleStar",
                        "follow": "heart",
                        "sub": "star",
                        "milestone": "sparkle"
                    })[root.current.kind] || "heart"
                pixel: Theme.u * 3
                ink: Theme.edge
                fill: "#ffffff"
                y: Math.round(Math.sin(alertBox.bob) * Theme.u * 2)
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.u * 2
                PxText {
                    text: root.current ? root.current.title : ""
                    kind: "title"
                    color: "#ffffff"
                    style: Text.Outline
                    styleColor: Theme.edge
                    font.bold: true
                }
                PxText {
                    visible: text !== ""
                    text: root.current ? root.current.sub : ""
                    color: "#ffffff"
                }
            }
        }
        SequentialAnimation {
            id: alertPop
            NumberAnimation {
                target: alertBox
                property: "pop"
                from: 0
                to: 1.15
                duration: Motion.ms(140)
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: alertBox
                property: "pop"
                to: 1
                duration: Motion.ms(90)
            }
            PauseAnimation {
                duration: 3100
            }
            NumberAnimation {
                target: alertBox
                property: "pop"
                to: 0
                duration: Motion.ms(160)
            }
        }
    }

    // ---- chat (bottom right) ----
    PxWindow {
        id: chatWin
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.u * 10
        width: Theme.u * 160
        height: Math.min(Theme.u * 210, root.height * 0.55)
        title: I18n.exe(I18n.t("чат", "chat")) + "  ·  " + root.viewers.toLocaleString(Qt.locale(), "f", 0)
        icon: "chat"
        compact: true
        closable: false
        Column {
            width: parent.width
            height: chatWin.height - chatWin.titleHeight - Theme.pad * 2 - Theme.u * 6
            spacing: Theme.u * 3
            // the poll, pinned
            PxBox {
                id: pollBox
                visible: root.poll !== null
                width: parent.width
                height: visible ? pollCol.implicitHeight + Theme.u * 8 : 0
                color: Theme.mix(Theme.face, Theme.accent, 0.12)
                Column {
                    id: pollCol
                    x: Theme.u * 4
                    y: Theme.u * 4
                    width: parent.width - Theme.u * 8
                    spacing: Theme.u * 2
                    PxText {
                        width: parent.width
                        text: "📊 " + (root.poll ? root.poll.q : "")
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Repeater {
                        model: root.poll ? root.poll.a.length : 0
                        Item {
                            id: opt
                            required property int index
                            readonly property int votes: root.poll ? root.poll.v[index] : 0
                            readonly property real share: root.poll ? votes / Math.max(1, root.poll.v[0] + root.poll.v[1]) : 0
                            readonly property bool won: root.poll && root.poll.done && root.poll.win === index
                            width: pollCol.width
                            height: Theme.u * 10
                            Rectangle {
                                anchors.fill: parent
                                color: Theme.sunken
                            }
                            Rectangle {
                                width: Math.round(parent.width * opt.share / Theme.u) * Theme.u
                                height: parent.height
                                color: opt.won ? Theme.accent : Theme.mix(Theme.accent2, Theme.face, 0.4)
                                Behavior on width {
                                    NumberAnimation {
                                        duration: Motion.ms(300)
                                    }
                                }
                            }
                            PxText {
                                x: Theme.u * 3
                                anchors.verticalCenter: parent.verticalCenter
                                text: (opt.won ? "✓ " : "") + (root.poll ? root.poll.a[opt.index] : "")
                                kind: "tiny"
                                font.bold: opt.won
                            }
                            PxText {
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.u * 3
                                anchors.verticalCenter: parent.verticalCenter
                                text: Math.round(opt.share * 100) + "%"
                                kind: "tiny"
                            }
                        }
                    }
                }
            }
            // the messages: new ones slide in at the bottom, the rest scroll up
            Item {
                id: chatView
                width: parent.width
                height: parent.height - (pollBox.visible ? pollBox.height + parent.spacing : 0)
                clip: true
                Column {
                    id: chat
                    width: parent.width
                    y: chatView.height - height
                    spacing: Theme.u * 2
                    Behavior on y {
                        enabled: root.scrollAnim && !Motion.still
                        NumberAnimation {
                            duration: 140
                            easing.type: Easing.OutQuad
                        }
                    }
                    Repeater {
                        model: chatModel
                        Item {
                            id: msg
                            required property string nick
                            required property string text
                            required property string col
                            required property string kind
                            required property string badge
                            required property int amount
                            readonly property bool sc: kind === "sc"
                            readonly property bool bot: kind === "bot"
                            width: chat.width
                            height: line.implicitHeight + (sc ? Theme.u * 6 : 0)
                            property real slide: Motion.still ? 0 : 1
                            opacity: 1 - slide
                            NumberAnimation on slide {
                                to: 0
                                duration: Motion.ms(160)
                                easing.type: Easing.OutQuad
                            }
                            PxBox {
                                visible: msg.sc
                                anchors.fill: parent
                                color: Theme.mix(Theme.accent3, Theme.face, 0.35)
                                outline: false
                            }
                            PxText {
                                id: line
                                x: (msg.sc ? Theme.u * 3 : 0) + Math.round(msg.slide * Theme.u * 16)
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - Theme.u * (msg.sc ? 6 : 0)
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                textFormat: Text.StyledText
                                // the nick in its own colour, a badge before it, the text after
                                text: (msg.badge ? "<font color=\"" + (msg.bot ? Theme.accent : Theme.accent3) + "\">" + msg.badge + "</font> " : "") + "<b><font color=\"" + msg.col + "\">" + Qt.escapeHtml(msg.nick) + (msg.sc ? " ¥" + msg.amount : "") + "</font></b>: " + (msg.bot ? "<font color=\"" + Theme.textDim + "\">" : "") + Qt.escapeHtml(msg.text) + (msg.bot ? "</font>" : "")
                            }
                        }
                    }
                }
            }
        }
    }
}
