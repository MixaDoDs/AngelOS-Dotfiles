pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Settings → Updates: pull the dotfiles repository this system was installed
// from and run its installer (scripts/dotfiles-update.sh). Checks once a day
// when allowed; never installs by itself. An update counts as installed only
// when the script exits 0 after its "UPDATED" line; anything else is a failure
// with the stage, the text and the snapshot to go back to (restore()).
Singleton {
    id: root

    readonly property string script: Quickshell.shellDir + "/scripts/dotfiles-update.sh"
    readonly property string managedDir: Config.home + "/.local/share/angelos/dotfiles"
    property string found: ""                     // repository found on disk
    readonly property string repo: Config.expand(Config.updates.repo) || found
    property string state: "idle"                 // idle | checking | updating | cloning | restoring | done | restored | failed
    property var log: []
    property int logTotal: 0                      // lines ever added to log (IPC `updates log N`)
    property var incoming: []
    property int behind: 0
    property int ahead: 0
    property int dirty: 0
    property string branch: ""
    property string upstream: ""
    property string remote: ""
    property bool trusted: true
    property string error: ""                     // the last check failed: why (no network…)
    readonly property bool busy: state === "checking" || state === "updating" || state === "cloning" || state === "restoring"
    readonly property bool available: behind > 0
    // the clone has commits of its own (a developer's working copy): no fast-forward,
    // and with nothing new there is nothing to take
    readonly property bool blocked: dirty > 0 || ahead > 0 || !trusted
    // a new version landed on disk, but this shell keeps running the old one from
    // memory: UpdatePrompt asks to restart now or leave it for the next login
    property bool needsRestart: false
    property bool askRestart: false
    // which big release this shell is (data/release.json, written when one is published):
    // {number, codename, date}, null before the first
    property var release: null
    FileView {
        path: Quickshell.shellDir + "/data/release.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.release = JSON.parse(text());
            } catch (e) {
                root.release = null;
            }
        }
        onLoadFailed: root.release = null
    }
    property int landed: 0                        // commits the last update brought
    // after a restore the prompt says "the previous version is back"
    property bool restored: false

    // the last attempt, as the script recorded it (survives a restart of the shell)
    property string lastStatus: ""                // ok | failed | started (cut short) | restored | restore-failed
    property string failedStage: ""               // install, niri-validate, …
    property string failure: ""                   // what went wrong, in words
    property string backupDir: ""                 // its snapshot
    property var conflicts: []                    // files kept on restore: changed again after the update
    // how the last run in this session ended (state goes back to idle with the check after it)
    property string lastRun: ""                   // "" | ok | failed | restored | restore-failed
    readonly property bool failedUpdate: lastStatus === "failed" || lastStatus === "started"
    readonly property bool canRestore: !!backupDir && (failedUpdate || lastStatus === "restore-failed")
    function stageText(stage) {
        const t = {
            "repo": I18n.t("папка репозитория не найдена", "the repository folder is missing"),
            "clone": I18n.t("не удалось скачать dotfiles", "the dotfiles could not be downloaded"),
            "untrusted": I18n.t("репозиторий не тот, из которого ставилась система", "not the repository this system came from"),
            "local-changes": I18n.t("в репозитории свои правки", "the repository has edits of its own"),
            "local-commits": I18n.t("в репозитории свои коммиты", "the repository has commits of its own"),
            "snapshot": I18n.t("не удалось сделать резервную копию — ничего не менялось", "the snapshot could not be taken — nothing was changed"),
            "pull": I18n.t("git не смог подтянуть новую версию", "git could not fetch the new version"),
            "install": I18n.t("установщик завершился с ошибкой", "the installer failed"),
            "niri-integration": I18n.t("не удалось подключить angelOS к niri", "angelOS could not be wired into niri"),
            "niri-validate": I18n.t("конфиг niri не прошёл проверку", "the niri config failed validation"),
            "niri-missing": I18n.t("niri не найден — конфиг нельзя проверить", "niri is not installed — the config cannot be checked"),
            "snapshot-started": I18n.t("обновление прервалось на середине", "the update was cut short")
        };
        return t[stage] || I18n.t("обновление не удалось", "the update failed");
    }
    // what to do next, after the stage that stopped the update
    function nextStep(stage) {
        const t = {
            "repo": I18n.t("Скачай dotfiles заново кнопкой «Скачать dotfiles» выше.", "Download the dotfiles again with the Download dotfiles button above."),
            "clone": I18n.t("Проверь подключение к интернету и нажми «Скачать dotfiles» ещё раз.", "Check the internet connection and press Download dotfiles again."),
            "untrusted": I18n.t("Ничего не менялось. Верни origin на официальный репозиторий (команда в сообщении) или обновляй вручную.", "Nothing changed. Point origin back at the official repository (the command is in the message) or update by hand."),
            "local-changes": I18n.t("Ничего не менялось. Закоммить или отложи правки (git stash -u) либо откати их — потом «Проверить» и «Обновить».", "Nothing changed. Commit or put the edits aside (git stash -u), or drop them — then Check and Update."),
            "local-commits": I18n.t("Ничего не менялось. Это рабочий клон со своими коммитами: перенеси их поверх новых (git pull --rebase) или ставь свою версию её установщиком (./install.sh).", "Nothing changed. This is a working clone with commits of its own: put them on top of the new ones (git pull --rebase), or install your version with its installer (./install.sh)."),
            "snapshot": I18n.t("Ничего не менялось. Освободи место на диске и проверь права на ~/.local/state/angelos, потом попробуй снова.", "Nothing changed. Free some disk space and check that ~/.local/state/angelos is writable, then try again."),
            "pull": I18n.t("Проверь подключение к интернету и попробуй ещё раз. Если снимок уже сделан — можно вернуть как было.", "Check the internet connection and try again. If a snapshot was taken, you can restore it."),
            "install": I18n.t("Верни как было кнопкой ниже: система вернётся к версии до попытки. Причина — в сообщении, весь вывод установщика — в install.log в папке снимка; если повторяется, приложи его к issue (angelos report).", "Restore with the button below: the system goes back to the version before the attempt. The reason is in the message, the installer's whole output is install.log in the snapshot folder; if it happens again, attach it to an issue (angelos report)."),
            "niri-integration": I18n.t("Верни как было кнопкой ниже, затем приложи журнал к issue (angelos report).", "Restore with the button below, then attach the log to an issue (angelos report)."),
            "niri-validate": I18n.t("Новый конфиг niri не прошёл проверку — со следующим входом niri бы его не принял. Верни как было кнопкой ниже.", "niri refuses the new config — the next login would fail with it. Restore with the button below."),
            "niri-missing": I18n.t("Поставь niri (sudo pacman -S niri) и обнови снова, или верни как было кнопкой ниже.", "Install niri (sudo pacman -S niri) and update again, or restore with the button below."),
            "snapshot-started": I18n.t("Попытка оборвалась на середине (выключение, сбой оболочки). Верни как было кнопкой ниже и обнови снова.", "The attempt was cut short (power-off, a shell crash). Restore with the button below and update again.")
        };
        return t[stage] || I18n.t("Подробности — в журнале ниже; если снимок сделан, можно вернуть как было.", "The details are in the log below; if a snapshot was taken, you can restore it.");
    }
    // the update's own text repeats the stage's heading sometimes: say it once
    function failureText(stage, msg) {
        const head = stageText(stage);
        if (!msg || msg.startsWith(head))
            return msg || head;
        return head + ": " + msg;
    }
    // the shell's log, without the colours a terminal would show
    function clean(line) {
        return String(line).replace(/\x1b\[[0-9;?]*[A-Za-z]/g, "");
    }
    function addLog(line) {
        log = log.concat([clean(line)]).slice(-500);
        logTotal += 1;
    }
    property var _pending: null                   // "UPDATED …" seen; it counts once the exit code is 0
    property bool _shellChanged: false            // "CHANGED <n> 1": the shell's own files changed
    property bool _afterFailure: false            // the attempt before this one failed (it may have half-installed)
    property string _lastSay: ""                  // the script's last "» " line: the reason when no FAILED line came
    property string _mode: ""                     // what the runner is doing: update | clone | restore
    property bool _snapshot: false                // this run took a snapshot (so the record is about it)
    // shell.qml touches this singleton at start-up: when this instance began
    readonly property double bornAt: Date.now()
    // started after the snapshot <stamp>-update was taken, so it runs files of that update
    function runsFilesOf(dir) {
        const m = String(dir).match(/(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})(?:-\d+)?-update\/?$/);
        return !m || bornAt > new Date(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +m[6]).getTime();
    }

    function find() {
        if (!finder.running)
            finder.running = true;
        readLast();
    }
    function readLast() {
        if (!lastReader.running)
            lastReader.running = true;
    }
    function check() {
        if (busy || !repo)
            return;
        state = "checking";
        error = "";
        checker.command = ["bash", script, "--check", repo];
        checker.running = true;
    }
    function update() {
        if (busy || !repo)
            return;
        _afterFailure = failedUpdate;
        state = "updating";
        lastRun = "";
        _mode = "update";
        _pending = null;
        error = "";
        failure = "";
        failedStage = "";
        conflicts = [];
        _snapshot = false;
        _shellChanged = false;
        _lastSay = "";
        log = [];
        addLog("» " + repo);
        runner.command = ["bash", script, repo];
        runner.running = true;
    }
    function clone() {
        if (busy)
            return;
        state = "cloning";
        _mode = "clone";
        log = [];
        _lastSay = "";
        lastRun = "";
        failure = "";
        failedStage = "";
        runner.command = ["bash", script, "--clone", managedDir];
        runner.running = true;
    }
    // back to how things were before the last attempt (its snapshot)
    function restore() {
        if (busy || !backupDir)
            return;
        state = "restoring";
        lastRun = "";
        _mode = "restore";
        failure = "";
        conflicts = [];
        log = [];
        addLog("» " + I18n.t("возвращаю как было: ", "restoring: ") + backupDir);
        runner.command = ["bash", script, "--restore", backupDir];
        runner.running = true;
    }
    function restartShell() {
        askRestart = false;
        // `angelos restart` restarts the live instance: never from a dev one
        if (Shell.dev) {
            console.log("angelOS dev: restart skipped");
            return;
        }
        Quickshell.execDetached([Quickshell.shellDir + "/bin/angelos", "restart"]);
    }
    function restartLater() {
        askRestart = false;
    }

    Process {
        id: finder
        running: true
        command: ["bash", root.script, "--find"]
        stdout: StdioCollector {
            onStreamFinished: root.found = text.trim()
        }
    }
    Process {
        id: lastReader
        command: ["bash", root.script, "--last"]
        stdout: StdioCollector {
            onStreamFinished: {
                const conf = [];
                let status = "", stage = "", dir = "", msg = "";
                for (const l of text.split("\n")) {
                    const parts = l.split(" ");
                    const k = parts.shift();
                    if (k === "LAST") {
                        status = parts[0] || "";
                        stage = parts[1] === "-" ? "" : parts[1] || "";
                        dir = parts[2] || "";
                    } else if (k === "MESSAGE")
                        msg = parts.join(" ");
                    else if (k === "CONFLICT")
                        conf.push(parts.join(" "));
                }
                // a runner result from this session is newer than the record it is read with
                if (root.busy)
                    return;
                const bad = status === "failed" || status === "started" || status === "restore-failed";
                root.lastStatus = status;
                root.backupDir = dir;
                root.failedStage = status === "started" ? "snapshot-started" : bad ? stage : "";
                root.failure = bad ? (msg || root.stageText(root.failedStage)) : "";
                root.conflicts = conf;
            }
        }
    }
    // "ERR fetch <git's reason>" / "ERR not a dotfiles repository" of `--check`, in words
    function checkError(v) {
        const s = String(v || "");
        if (s.startsWith("fetch"))
            return I18n.t("нет связи с репозиторием — проверь интернет и нажми «Проверить» ещё раз", "the repository can't be reached — check the internet connection and press Check again") + (s.length > 6 ? " (" + s.slice(6) + ")" : "");
        if (s.startsWith("not a dotfiles repository"))
            return I18n.t("в папке нет репозитория dotfiles", "the folder holds no dotfiles repository");
        return s;
    }
    // the script and the installer answer in the shell's language, not the session's
    readonly property var scriptEnv: ({
            "ANGELOS_LANG": I18n.english ? "en" : "ru"
        })
    Process {
        id: checker
        environment: root.scriptEnv
        stdout: StdioCollector {
            onStreamFinished: {
                const inc = [];
                for (const l of text.split("\n")) {
                    const parts = l.split(" ");
                    const k = parts.shift();
                    const v = parts.join(" ");
                    if (k === "BRANCH")
                        root.branch = v;
                    else if (k === "UPSTREAM")
                        root.upstream = v === "none" ? "" : v;
                    else if (k === "BEHIND")
                        root.behind = parseInt(v) || 0;
                    else if (k === "AHEAD")
                        root.ahead = parseInt(v) || 0;
                    else if (k === "DIRTY")
                        root.dirty = parseInt(v) || 0;
                    else if (k === "REMOTE")
                        root.remote = v;
                    else if (k === "TRUSTED")
                        root.trusted = v === "1";
                    else if (k === "IN")
                        inc.push(v);
                    else if (k === "ERR")
                        root.error = root.checkError(v);
                }
                root.incoming = inc;
                // a failed check (offline at login) is retried by the daily timer, not 22 h later
                if (text.includes("ERR "))
                    return;
                root.error = "";
                Config.updates.lastCheck = new Date().toISOString();
                Config.updates.available = root.behind;
            }
        }
        onExited: code => {
            root.state = code === 0 ? "idle" : "failed";
            if (code !== 0 && !root.error)
                root.error = I18n.t("не удалось связаться с репозиторием", "could not reach the repository");
            root.maybeNotify();
        }
    }
    Process {
        id: runner
        environment: root.scriptEnv
        // the protocol lines of scripts/dotfiles-update.sh; the rest goes to the log
        stdout: SplitParser {
            onRead: line => {
                const p = line.split(" ");
                const rest = n => p.slice(n).join(" ");
                if (p[0] === "UPDATED") {
                    // only a claim until the exit code backs it
                    root._pending = {
                        "changed": p[1] !== p[2],
                        "commits": parseInt(p[3]) || 0
                    };
                    return;
                }
                if (p[0] === "BACKUP") {
                    root.backupDir = rest(1);
                    root._snapshot = true;
                } else if (p[0] === "CHANGED")
                    root._shellChanged = p[2] === "1";
                else if (p[0] === "»")
                    root._lastSay = root.clean(rest(1));
                else if (p[0] === "FAILED") {
                    root.failedStage = p[1] || "";
                    root.failure = rest(2) || root.stageText(root.failedStage);
                } else if (p[0] === "RESTORE-FAILED")
                    root.failure = rest(2) || I18n.t("восстановление не удалось", "the restore failed");
                else if (p[0] === "CONFLICT")
                    root.conflicts = root.conflicts.concat([rest(1)]);
                else if (p[0] === "RESTORED")
                    root._pending = {
                        "files": parseInt(p[1]) || 0,
                        "shell": p[3] === "1"
                    };
                root.addLog(line);
            }
        }
        stderr: SplitParser {
            onRead: line => root.addLog(line)
        }
        onExited: code => {
            const mode = root._mode;
            const pending = root._pending;
            root._pending = null;
            root._mode = "";
            root.addLog(code === 0 ? I18n.t("✓ готово", "✓ done") : I18n.t("✕ код выхода ", "✕ exit code ") + code);
            if (mode === "restore") {
                if (code === 0) {
                    root.state = "restored";
                    root.lastRun = "restored";
                    root.lastStatus = "restored";
                    root.failure = "";
                    root.failedStage = "";
                    root.restored = true;
                    // the shell's own files went back; this instance only runs code that is
                    // gone now if it started after the failed update (else it still has the old one)
                    if (pending && pending.shell && root.runsFilesOf(root.backupDir))
                        root.needsRestart = true;
                    if (root.needsRestart)
                        root.askRestart = true;
                } else {
                    root.state = "failed";
                    root.lastRun = "restore-failed";
                    root.lastStatus = "restore-failed";
                    if (!root.failure)
                        root.failure = I18n.t("восстановление не удалось, код ", "the restore failed, code ") + code;
                }
                root.readLast();
                Qt.callLater(root.check);
                return;
            }
            if (mode === "update" && (code !== 0 || !pending)) {
                // whatever was printed, this is not an installed update
                root.state = "failed";
                root.lastRun = "failed";
                // an older script stops without a FAILED line: its last words are the reason
                if (!root.failure)
                    root.failure = code === 0 ? I18n.t("скрипт не сообщил об успешной установке", "the script did not report a finished install") : root._lastSay ? root._lastSay + " (" + I18n.t("код ", "code ") + code + ")" : I18n.t("обновление не удалось, код ", "the update failed, code ") + code;
                // stopped before its snapshot (local edits, untrusted origin, no network):
                // nothing changed, and the record of an earlier attempt must not
                // replace this message
                if (root._snapshot) {
                    root.lastStatus = "failed";
                    root.find();
                } else if (!finder.running) {
                    finder.running = true;
                }
                Qt.callLater(root.check);
                return;
            }
            root.state = code === 0 ? "done" : "failed";
            if (code !== 0 && mode === "clone") {
                root.lastRun = "failed";
                if (!root.failedStage)
                    root.failedStage = "clone";
                if (!root.failure)
                    root.failure = root._lastSay || I18n.t("код ", "code ") + code;
            }
            if (code === 0 && mode === "update") {
                root.lastRun = "ok";
                root.lastStatus = "ok";
                root.failure = "";
                root.failedStage = "";
                root.restored = false;
                // new commits, or the same commit installed again after a failed attempt
                if (pending.changed || root._shellChanged || root._afterFailure) {
                    root.landed = pending.commits;
                    root.needsRestart = true;
                }
                // the installer ships default binds / cursor: put the user's choices back
                WorkspaceAnim.reapply();
                if (Cursors.hellOn)
                    Cursors.put(Cursors.hellTheme, Config.cursor.size);
                else if (Config.cursor.theme)
                    Cursors.apply(Config.cursor.theme, Config.cursor.size);
                // also after a "nothing new" run while an earlier update still waits
                if (root.needsRestart)
                    root.askRestart = true;
            }
            root.find();
            Qt.callLater(root.check);
        }
    }

    // ---- once a day, only telling ----
    property string notifiedFor: ""
    function maybeNotify() {
        if (behind <= 0 || !incoming.length || Shell.dev)
            return;
        const head = incoming[0].split(" ")[0];
        if (head === notifiedFor)
            return;
        notifiedFor = head;
        Quickshell.execDetached(["notify-send", "-a", "angelOS", "-i", "system-software-update", I18n.t("Доступно обновление angelOS", "An angelOS update is available"), I18n.t("Новых изменений: ", "New changes: ") + behind + I18n.t(". Настройки → Обновления.", ". Settings → Updates.")]);
    }
    Timer {
        interval: 90 * 1000
        running: Config.ready && Config.updates.autoCheck
        repeat: true
        onTriggered: {
            interval = 6 * 3600 * 1000;
            const last = Date.parse(Config.updates.lastCheck || "") || 0;
            if (Date.now() - last > 22 * 3600 * 1000)
                root.check();
        }
    }

    // Quickshell uses Qt's private parts: a Quickshell built against one Qt crashes at
    // random on another (#50, #51: Qt 6.12 arrived before the rebuilt quickshell
    // package). Its own check says so; asked at start and every hour (Qt updates while
    // the shell runs), told once per pair of versions.
    property string qtMismatch: ""
    property string _qtTold: ""
    Process {
        id: qtCheck
        running: true
        command: ["sh", "-c", "qs --private-check-compat; echo \"EXIT $?\"; [ -x /usr/bin/quickshell ] && echo SYSTEM"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/built against Qt ([0-9.]+) but the system has updated to Qt ([0-9.]+)/);
                root.qtMismatch = m && /EXIT 1/.test(text) ? m[1] + " → " + m[2] : "";
                if (!root.qtMismatch || root.qtMismatch === root._qtTold)
                    return;
                root._qtTold = root.qtMismatch;
                const fix = /SYSTEM/.test(text) ? I18n.t("Обнови систему (sudo pacman -Syu), затем angelos restart.", "Update the system (sudo pacman -Syu), then angelos restart.") : I18n.t("Поставь пакет: sudo pacman -S quickshell, затем angelos restart.", "Install the package: sudo pacman -S quickshell, then angelos restart.");
                Quickshell.execDetached(["notify-send", "-a", "angelOS", "-u", "critical", "-i", "dialog-warning", I18n.t("Quickshell не подходит к Qt", "Quickshell doesn't match Qt"), I18n.t("Собран под Qt ", "Built against Qt ") + m[1] + I18n.t(", а в системе ", ", the system has ") + m[2] + I18n.t(" — оболочка будет падать. ", " — the shell will crash. ") + fix]);
            }
        }
    }
    Timer {
        interval: 3600 * 1000
        repeat: true
        running: true
        onTriggered: qtCheck.running = true
    }
}
