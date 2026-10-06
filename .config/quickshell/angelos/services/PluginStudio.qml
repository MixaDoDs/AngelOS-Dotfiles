pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The worker owns API calls and drafts; closing Settings does not lose a job.
Singleton {
    id: root

    property var session: ({messages: [], plan: null, draft: null, installed: ""})
    // changing an installed plugin (Settings → Plugins → "Improve"): the draft starts as its files
    readonly property bool editing: session.mode === "edit"
    readonly property string target: editing ? session.target || "" : ""
    property var backups: ({})          // user plugin id -> saved earlier versions
    property string editRequest: ""     // Settings → Plugins → Improve: Studio opens it
    property string hellRequest: ""     // …and then makes its hell version (Settings → Plugins → Hell version)
    property var keys: ({openai: false, anthropic: false})
    property var cli: ({})              // {"claude-cli": {installed, loggedIn, method}, "codex-cli": {…}}
    property var models: ({})           // provider -> [{id, label, efforts, default, speed}]
    property int repairRound: 0
    property int repairOf: 0
    property real startedAt: 0
    property int elapsed: 0             // seconds since the request started
    readonly property var modelList: models[Config.developer.provider] || []
    readonly property var modelInfo: modelList.find(m => m.id === model) || null
    // levels this model takes; an unknown model id gets the common ones
    readonly property var effortLevels: modelInfo ? modelInfo.efforts : ["low", "medium", "high", "xhigh", "max"]
    readonly property string effort: {
        const e = (Config.developer.efforts || {})[Config.developer.provider];
        return e !== undefined && (e === "" || effortLevels.includes(e)) ? e : (modelInfo ? modelInfo["default"] || "" : "");
    }
    function setEffort(value) {
        const m = Object.assign({}, Config.developer.efforts || {});
        m[Config.developer.provider] = value;
        Config.developer.efforts = m;
    }
    // rough wall-clock expectations shown next to the level
    function effortHint(e) {
        return ({
                "": I18n.t("как решит модель", "the model decides"),
                "low": I18n.t("быстро · ~1–2 мин", "fast · ~1–2 min"),
                "medium": I18n.t("баланс · ~2–4 мин", "balanced · ~2–4 min"),
                "high": I18n.t("тщательно · ~4–8 мин", "careful · ~4–8 min"),
                "xhigh": I18n.t("очень тщательно · ~6–15 мин", "very careful · ~6–15 min"),
                "max": I18n.t("максимум · до 30 мин", "maximum · up to 30 min"),
                "ultra": I18n.t("ультра · до 40 мин", "ultra · up to 40 min")
            })[e] || "";
    }
    Timer {
        interval: 1000
        repeat: true
        running: root.busy
        onTriggered: root.elapsed = Math.round((Date.now() - root.startedAt) / 1000)
    }
    property string error: ""
    property string stage: ""
    property string action: ""
    property bool busy: false
    property bool loaded: false
    property string composer: ""
    signal completed(string action)
    property bool _received: false
    property string _request: ""
    property string _enableAfterScan: ""
    property bool _addDesktop: false
    property string _screen: ""
    readonly property var plan: session.plan || null
    readonly property var draft: session.draft || null
    readonly property var providers: [
        {label: I18n.t("Claude · вход через браузер", "Claude · browser sign-in"), value: "claude-cli"},
        {label: I18n.t("Codex · вход через ChatGPT", "Codex · ChatGPT sign-in"), value: "codex-cli"},
        {label: "OpenAI API", value: "openai"},
        {label: "Anthropic API", value: "anthropic"}
    ]
    readonly property bool isCli: Config.developer.provider === "claude-cli" || Config.developer.provider === "codex-cli"
    readonly property var cliState: cli[Config.developer.provider] || ({})
    // ready to send: a saved API key, or an installed and signed-in CLI
    readonly property bool hasKey: isCli ? (!!cliState.installed && !!cliState.loggedIn) : !!keys[Config.developer.provider]
    readonly property string model: ({
            "anthropic": Config.developer.anthropicModel,
            "openai": Config.developer.openaiModel,
            "claude-cli": Config.developer.claudeCliModel,
            "codex-cli": Config.developer.codexCliModel
        })[Config.developer.provider] || ""
    function setModel(value) {
        const key = ({
                "anthropic": "anthropicModel",
                "openai": "openaiModel",
                "claude-cli": "claudeCliModel",
                "codex-cli": "codexCliModel"
            })[Config.developer.provider];
        if (key)
            Config.developer[key] = value;
    }
    // the CLIs sign in through the browser themselves; angelOS never sees the tokens
    function login() {
        const argv = Config.developer.provider === "codex-cli" ? ["codex", "login"] : ["claude", "auth", "login"];
        Quickshell.execDetached(Shell.terminalArgv(["sh", "-c", 'PATH="$HOME/.local/bin:$PATH"; "$@"; printf "\\n♡ Готово — вернись в angelOS и нажми «Проверить вход». Enter закроет окно."; read _', "sh"].concat(argv)));
    }
    readonly property string elapsedText: elapsed >= 60 ? Math.floor(elapsed / 60) + I18n.t(" мин ", " min ") + (elapsed % 60) + I18n.t(" с", " s") : elapsed + I18n.t(" с", " s")
    readonly property string statusText: !busy ? "" : (action === "update" ? I18n.t("Обновляю плагин…", "Updating the plugin…")
        : action === "rollback" ? I18n.t("Возвращаю прошлую версию…", "Restoring the earlier version…")
        : action === "edit_start" ? I18n.t("Открываю плагин…", "Opening the plugin…")
        : stage === "validation"
        ? I18n.t("Проверяю файлы…", "Checking files…")
        : stage === "runtime" ? I18n.t("Запускаю плагин в песочнице и проверяю, что всё загружается…", "Loading the plugin in a sandbox to see that everything works…")
        : stage === "repair" ? I18n.t("Нашлись ошибки — ИИ исправляет (попытка ", "Checks failed — AI is fixing them (attempt ") + repairRound + "/" + repairOf + ")…"
        : action === "generate" ? (editing ? I18n.t("ИИ дорабатывает плагин… ", "AI is changing the plugin… ") : I18n.t("ИИ пишет плагин… ", "AI is writing your plugin… ")) + effortHint(effort)
        : action === "plan" ? I18n.t("ИИ разбирает запрос…", "AI is reviewing your request…")
        : I18n.t("Обрабатываю…", "Working…")) + (elapsed > 2 ? "  ·  " + elapsedText : "")

    function send(name, params) {
        if (busy || worker.running || (!Config.developer.enabled && name !== "status" && name !== "reload"))
            return false;
        _clearComposer = name === "plan" || name === "reset" || name === "edit_start" || (name === "generate" && !!(params && params.prompt));
        error = "";
        action = name;
        stage = "";
        _received = false;
        _request = JSON.stringify(Object.assign({
            action: name,
            language: Config.appearance.language,
            provider: Config.developer.provider,
            model: model,
            effort: effort,
            autoRepair: Math.max(0, Math.min(2, Config.developer.autoRepair)),
            maxOutputTokens: Config.developer.maxOutputTokens
        }, params || {})) + "\n";
        busy = true;
        startedAt = Date.now();
        elapsed = 0;
        repairRound = 0;
        worker.running = true;
        // the worker enforces its own per-request limit; this only catches a stuck worker
        const perRequest = ({"low": 420, "medium": 720, "high": 1080, "xhigh": 1500, "max": 2100, "ultra": 2400})[effort] || 900;
        deadline.interval = (perRequest * (name === "generate" ? 1 + Math.max(0, Config.developer.autoRepair) : 1) + 120) * 1000;
        deadline.restart();
        return true;
    }
    function refresh() {
        send("status");
    }
    function cancel() {
        // Installation and updates are short, atomic local operations; never interrupt them.
        if (!busy || ["install", "update", "rollback", "save_file", "delete_file", "edit_start"].includes(action))
            return;
        worker.signal(15);
        _request = "";
        _received = true;
        error = I18n.t("Запрос отменён. Провайдер мог уже учесть отправленный запрос.", "Request cancelled. The provider may already have counted the request.");
    }
    // ---- improving an installed plugin ----
    function startEdit(id) {
        return send("edit_start", {id: id});
    }
    // change the plugin straight from a request, without a plan
    function applyChange(prompt) {
        return send("generate", {prompt: prompt});
    }
    // ---- heaven and hell (docs/STUDIO_CONTRACT.md, "Two realms") ----
    // An installed plugin of yours whose desktop widget only knows heaven: in hell
    // the shell just re-inks it. makeHell() asks the AI for its own hell look.
    function needsHell(p) {
        return !!p && !p.bundled && !!p.desktopWidget && !(p.realms || []).includes("hell");
    }
    readonly property string hellPrompt: I18n.t("Сделай адскую версию виджета рабочего стола (контракт, раздел «Two realms»): добавь в manifest.json \"realms\": [\"heaven\", \"hell\"], а виджету — свой адский облик, привязанный к Theme.hell. Те же данные и кнопки на тех же местах, палитра Theme.hell…, шрифт Theme.fontHell для латиницы, PxBox/PxButton с hell: Theme.hell, размер почти тот же. Ад — не перекраска: придумай, чем этот виджет станет в аду. Остальное не меняй; в README опиши оба вида.", "Make the hell version of the desktop widget (contract section “Two realms”): add \"realms\": [\"heaven\", \"hell\"] to manifest.json and give the widget its own hell look bound to Theme.hell. Same data and controls in the same places, the Theme.hell… palette, Theme.fontHell for Latin text, PxBox/PxButton with hell: Theme.hell, about the same size. Hell is not a recolour: decide what this widget becomes in hell. Change nothing else; describe both looks in the README.")
    function makeHell() {
        return editing && applyChange(hellPrompt);
    }
    function saveFile(path, content) {
        return send("save_file", {path: path, content: content});
    }
    function deleteFile(path) {
        return send("delete_file", {path: path});
    }
    function update() {
        if (draft)
            send("update", {digest: draft.digest});
    }
    function rollback(id) {
        return send("rollback", {id: id});
    }
    // load an installed plugin's files again (after editing them by hand)
    function reloadPlugin(id) {
        return send("reload", {id: id});
    }
    property bool _clearComposer: false

    function install(addDesktop) {
        if (!draft)
            return;
        _addDesktop = addDesktop;
        _screen = Shell.primaryName;
        send("install", {digest: draft.digest});
    }
    function activateInstalled() {
        const id = _enableAfterScan;
        const p = id ? Plugins.byId(id) : null;
        if (!p)
            return;
        _enableAfterScan = "";
        Achievements.note("plugin.create", id);
        Plugins.setEnabled(id, true);
        if (_addDesktop && p.desktopWidget && _screen && !DesktopWidgets.has("plugin:" + id, _screen))
            DesktopWidgets.add("plugin:" + id, _screen);
    }
    function receive(event) {
        if (event.event === "progress") {
            stage = event.stage;
            if (event.round) {
                repairRound = event.round;
                repairOf = event.of || 0;
            }
            return;
        }
        _received = true;
        if (event.event === "error") {
            error = event.message;
            return;
        }
        if (event.keys !== undefined)
            keys = event.keys;
        if (event.cli !== undefined)
            cli = event.cli;
        if (event.models !== undefined)
            models = event.models;
        if (event.session !== undefined)
            session = event.session;
        if (event.backups !== undefined)
            backups = event.backups;
        if (_clearComposer)
            composer = "";
        loaded = true;
        if (event.reloaded && event.reloaded.loadDir)
            Plugins.setLoadDir(event.reloaded.id, event.reloaded.loadDir);
        if (event.installed) {
            _enableAfterScan = event.installed.id;
            Plugins.reload();
        }
        completed(action);
    }
    Connections {
        target: Plugins
        function onPluginsChanged() {
            root.activateInstalled();
        }
    }
    Connections {
        target: Config.developer
        function onEnabledChanged() {
            if (!Config.developer.enabled)
                root.cancel();
        }
    }
    Timer {
        id: deadline
        interval: 240000
        onTriggered: {
            if (root.busy && !["install", "update", "rollback"].includes(root.action)) {
                worker.signal(15);
                root._received = true;
                root._request = "";
                root.error = I18n.t("Превышено время ожидания. Повторите запрос.", "Request timed out. Try again.");
            }
        }
    }
    Process {
        id: worker
        command: ["python3", "-u", Quickshell.shellDir + "/scripts/plugin-studio.py"]
        stdinEnabled: true
        onStarted: {
            write(root._request);
            root._request = "";
        }
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.receive(JSON.parse(data));
                } catch (e) {
                    root.error = I18n.t("Не удалось прочитать ответ мастера.", "Could not read the Studio response.");
                }
            }
        }
        stderr: StdioCollector {}
        onExited: {
            deadline.stop();
            root._request = "";
            root.busy = false;
            if (!root._received)
                root.error = I18n.t("Мастер завершился без ответа. Проверьте наличие Python 3.", "Studio exited without a response. Check that Python 3 is installed.");
            // Settings → Plugins → Hell version: the plugin is open, now the request
            if (root.hellRequest && root.action === "edit_start") {
                const forHell = root.hellRequest === root.target;
                root.hellRequest = "";
                if (forHell && root.editing && !root.error) {
                    if (root.hasKey)
                        Qt.callLater(root.makeHell);
                    else
                        root.composer = root.hellPrompt;
                }
            }
        }
        onRunningChanged: {
            if (!running && root.busy) {
                // Also handles failure to start, where exited may not fire.
                Qt.callLater(() => {
                    if (!worker.running) {
                        root.busy = false;
                        root._request = "";
                        deadline.stop();
                        if (!root._received && !root.error)
                            root.error = I18n.t("Не удалось запустить мастер.", "Could not start Studio.");
                    }
                });
            }
        }
    }
}
