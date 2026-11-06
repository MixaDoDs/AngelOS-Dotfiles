pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// The live ISO's course (Installer.qml covers the screens, SetupAssistant draws each step): angelOS onto a whole
// disk through /usr/local/bin/angelos-install-disk (iso/profile). New game → the language and the time zone →
// the network, when there is none → the hero's name and password → the disk → what gets erased (#163: what is on
// it) → the progress → restart. The rest (apps, wallpapers, games, voice) is asked by the installed system's first
// run, not here. The same interface as SetupFlow: step, steps, cur, next(), back(), installState.
Scope {
    id: root

    property int step: 0
    property var assistant: null
    readonly property var github: null
    readonly property var appsToInstall: []
    // the screen the questions are on (the others show the ground only)
    readonly property var host: Shell.focusedScreen

    // ---- the answers ----
    property string zone: ""
    readonly property string zoneOrDefault: zone || (I18n.english ? "UTC" : "Europe/Moscow")
    property var zones: []
    property bool needNet: false            // no internet when the language was picked: the network step stays
    property string heroName: ""
    property string loginTyped: ""          // the login edited by hand ("" = from the name)
    readonly property string login: loginTyped || loginFor(heroName)
    property string password: ""
    property string password2: ""
    property bool heroTried: false          // Continue pressed: the problems show
    readonly property string heroProblem: {
        if (!heroName.trim())
            return I18n.t("Нужно имя.", "A name, please.");
        if (!/^[a-z_][a-z0-9_-]{0,31}$/.test(login) || ["root", "nobody", "sddm", "bin", "daemon"].includes(login))
            return I18n.t("Логин: латинские буквы, цифры, - и _, с буквы.", "The login: Latin letters, digits, - and _, starting with a letter.");
        if (!password)
            return I18n.t("Нужен пароль: им входят в систему и ставят программы.", "A password, please: it logs you in and installs apps.");
        if (password !== password2)
            return I18n.t("Пароли не совпадают.", "The passwords differ.");
        return "";
    }
    property var disks: []                  // angelos-install-disk list: whole disks only
    property string disk: ""
    readonly property var diskInfo: disks.find(d => d.path === disk && !blocker(d)) || null
    // why a disk can't be picked ("" = it can): too small, or something on it is in use (the stick this runs from)
    function blocker(d) {
        if (d.size < 20e9)
            return I18n.t("меньше 20 ГБ", "smaller than 20 GB");
        if ([d].concat(d.children || []).some(p => (p.mountpoints || []).some(m => m)))
            return I18n.t("сейчас занят — скорее всего, это флешка установщика", "in use now; most likely the installer's own stick");
        return "";
    }

    // ---- the install ----
    readonly property var installState: ({
            "running": run.running
        })
    property real progress: 0
    property string phase: ""
    property string error: ""
    property bool done: false
    property var errLines: []

    readonly property var stepList: [
        {
            "id": "newgame",
            "icon": "heart",
            "title": "angelOS",
            "text": I18n.t("angelOS встанет на этот компьютер. Нужны язык, диск, имя и пароль — остальное спросит сама система при первом входе.", "angelOS goes onto this computer. A language, a disk, a name and a password; the system asks the rest at its first start."),
            "nextText": I18n.t("Новая игра", "New game"),
            "attention": "next"
        },
        {
            "id": "lang",
            "icon": "clock",
            "title": I18n.t("Язык и часовой пояс", "Language and time zone"),
            "text": I18n.t("На каком языке говорит система и по чьим часам живёт.", "The language the system speaks and whose clock it keeps."),
            "attention": "next"
        },
        {
            "id": "net",
            "icon": Wifi.online ? "wifi" : "wifiOff",
            "title": I18n.t("Подключись к сети", "Connect to the network"),
            "text": Wifi.online ? I18n.t("Сеть есть ♡", "Online ♡") : I18n.t("angelOS скачивается во время установки. Выбери Wi‑Fi или вставь кабель.", "angelOS is downloaded while it installs. Pick a Wi‑Fi network or plug in a cable."),
            "blocks": ["network/status", "network/wifi"],
            "rest": false,
            "attention": Wifi.online ? "next" : "none",
            "nextText": Wifi.online ? I18n.t("Продолжить", "Continue") : I18n.t("Жду сеть…", "Waiting for the network…"),
            "when": root.needNet
        },
        {
            "id": "hero",
            "icon": "heart",
            "title": I18n.t("Введите имя героя", "Enter the hero's name"),
            "text": I18n.t("Так система будет к тебе обращаться. Пароль — для входа и установки программ.", "What the system calls you. The password logs you in and installs apps.")
        },
        {
            "id": "disk",
            "icon": "hdd",
            "title": I18n.t("Куда ставить?", "Where should it go?"),
            "text": I18n.t("angelOS занимает весь диск. Рядом с Windows пока не встаёт.", "angelOS takes the whole disk. It can't sit next to Windows yet.")
        },
        {
            "id": "confirm",
            "icon": "warn",
            "title": I18n.t("Всё на диске сотрётся", "Everything on the disk is erased"),
            "text": I18n.t("Проверь, тот ли это диск. Вернуть стёртое будет нельзя.", "Make sure it is the right disk. What is erased can't be brought back."),
            "nextText": I18n.t("Стереть и установить", "Erase and install")
        },
        {
            "id": "progress",
            "icon": root.done ? "check" : root.error ? "warn" : "package",
            "title": root.done ? I18n.t("angelOS установлена ♡", "angelOS is installed ♡") : root.error ? I18n.t("Не получилось", "It didn't work") : I18n.t("Ставлю angelOS…", "Installing angelOS…"),
            "text": root.done ? I18n.t("Вынь флешку и перезагрузись. Дальше — первый запуск.", "Take the stick out and restart. Then the first start.") : root.error ? I18n.t("Можно повторить или вернуться и выбрать другой диск.", "Try again, or go back and pick another disk.") : I18n.t("Минут 5–15: всё скачивается по сети. Компьютер не выключай.", "5–15 minutes: everything comes over the network. Don't switch the computer off."),
            "back": !!root.error,
            "attention": root.done || root.error ? "next" : "none",
            "nextText": root.done ? I18n.t("Перезагрузить", "Restart") : root.error ? I18n.t("Повторить", "Try again") : I18n.t("Ставлю…", "Installing…")
        }
    ]
    readonly property var steps: stepList.filter(s => s.when === undefined || s.when)
    readonly property int last: steps.length - 1
    readonly property var cur: steps[Math.min(step, last)] || steps[0]
    property double shownAt: 0
    onCurChanged: {
        shownAt = Date.now();
        if (cur && cur.id === "disk")
            diskList.running = true;
    }

    function next() {
        if (run.running)
            return;
        switch (cur.id) {
        case "lang":
            needNet = !Wifi.online;
            break;
        case "net":
            if (!Wifi.online)
                return;
            break;
        case "hero":
            heroTried = true;
            if (heroProblem)
                return;
            break;
        case "disk":
            if (!diskInfo)
                return;
            break;
        case "confirm":
            // an Enter held or pressed twice from the disk step must not erase it: a second to look first
            if (Date.now() - shownAt < 1500)
                return;
            start();
            break;
        case "progress":
            if (done)
                reboot.running = true;
            else if (error)
                start();
            return;
        }
        if (step < last)
            step++;
    }
    function back() {
        if (run.running || step === 0)
            return;
        step--;
    }

    // "Миша Котов" → "misha-kotov": the login the name gives (Lyrics' Cyrillic table)
    function loginFor(name) {
        let s = Lyrics.translit(String(name || "").toLowerCase()).normalize("NFKD").replace(/[̀-ͯ]/g, "");
        s = s.replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 32);
        return /^[0-9]/.test(s) ? "u" + s.slice(0, 31) : s;
    }
    // "nvme · Samsung 980 · 1 TB": a disk in one line; what is on it, partition by partition
    function sizeText(bytes) {
        const g = bytes / 1e9;
        return g >= 1000 ? (g / 1000).toFixed(g >= 10000 ? 0 : 1) + I18n.t(" ТБ", " TB") : Math.round(g) + I18n.t(" ГБ", " GB");
    }
    function contents(d) {
        const parts = (d && d.children || []).map(p => [p.label || "", p.fstype || I18n.t("без файловой системы", "no file system"), p.size ? sizeText(p.size) : "", p["fsuse%"] ? I18n.t("занято ", "used ") + p["fsuse%"] : ""].filter(x => x).join(" · "));
        return parts;
    }

    function start() {
        error = "";
        done = false;
        progress = 0;
        phase = "check";
        errLines = [];
        run.command = ["sudo", "-n", "env", "INSTALL_DISK=" + disk, "INSTALL_CONFIRM=" + disk, "INSTALL_USER=" + login, "INSTALL_TZ=" + zoneOrDefault, "INSTALL_LOCALE=" + (I18n.english ? "en_US.UTF-8" : "ru_RU.UTF-8"), "INSTALL_KB=" + (I18n.english ? "us" : "us,ru"), "/usr/local/bin/angelos-install-disk"];
        run.running = true;
    }
    Process {
        id: run
        // the password: one line on stdin, never in the arguments (ps shows those)
        stdinEnabled: true
        onStarted: write(root.password + "\n")
        stdout: SplitParser {
            onRead: line => {
                const m = /^@@ (\S+) (\S+)/.exec(line);
                if (m && m[1] !== "fail") {
                    root.progress = Number(m[1]) / 100;
                    root.phase = m[2];
                }
            }
        }
        stderr: SplitParser {
            onRead: line => root.errLines = root.errLines.concat([line]).slice(-8)
        }
        onExited: code => {
            if (code === 0 && root.phase === "done") {
                root.done = true;
                root.password = root.password2 = "";
            } else {
                root.error = root.errLines.join("\n") || I18n.t("установщик вышел с кодом ", "the installer exited with ") + code;
            }
        }
    }
    readonly property string phaseText: ({
            "check": I18n.t("проверяю компьютер и сеть", "checking the computer and the network"),
            "disk": I18n.t("размечаю диск", "partitioning the disk"),
            "base": I18n.t("ставлю основу системы", "installing the base system"),
            "system": I18n.t("язык, время, имя компьютера", "language, time, the computer's name"),
            "user": I18n.t("создаю героя", "creating the hero"),
            "angelos": I18n.t("ставлю angelOS и программы", "installing angelOS and its programs"),
            "gpu": I18n.t("драйвер видеокарты", "the graphics driver"),
            "boot": I18n.t("загрузчик", "the boot loader"),
            "done": I18n.t("готово", "done")
        })[phase] || ""

    Process {
        id: diskList
        command: ["/usr/local/bin/angelos-install-disk", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.disks = (JSON.parse(text).blockdevices || []).filter(d => d.type === "disk");
                    // one disk it can go on (a laptop, a VM): picked already, Enter goes on
                    const usable = root.disks.filter(d => !root.blocker(d));
                    if (!root.diskInfo && usable.length === 1)
                        root.disk = usable[0].path;
                } catch (e) {
                    root.disks = [];
                }
            }
        }
    }
    Process {
        command: ["timedatectl", "list-timezones"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.zones = text.split("\n").filter(z => z)
        }
    }
    Process {
        id: reboot
        command: ["systemctl", "reboot"]
    }
}
