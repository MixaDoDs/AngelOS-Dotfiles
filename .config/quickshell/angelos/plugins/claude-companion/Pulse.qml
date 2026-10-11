pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// Session aggregator for the pulse protocol (see hooks/PROTOCOL.md upstream):
// events + CSV payload "model,in,out,cacheCreate,cacheRead,session".
Singleton {
    id: root

    readonly property var priority: ({
            "needs_attention": 6,
            "error": 5,
            "tool_start": 4,
            "turn_start": 3,
            "text": 3,
            "turn_end": 2,
            "idle": 1
        })
    readonly property var words: ({
            "needs_attention": I18n.t("ждёт тебя!", "Waiting for you!"),
            "error": I18n.t("ошибка", "Error"),
            "tool_start": I18n.t("работает", "Working"),
            "turn_start": I18n.t("думает", "Thinking"),
            "text": I18n.t("пишет", "Writing"),
            "turn_end": I18n.t("готово ♡", "Ready ♡"),
            "idle": I18n.t("отдыхает", "Resting"),
            "none": I18n.t("нет сессий", "No sessions")
        })
    // hell (Theme.hell, the demon's realm): the same states, plainer and colder — what it
    // does must still be clear at a glance
    readonly property var hellWords: ({
            "needs_attention": I18n.t("ждёт тебя", "Waiting for you"),
            "error": I18n.t("ошибка", "Error"),
            "tool_start": I18n.t("работает", "Working"),
            "turn_start": I18n.t("думает", "Thinking"),
            "text": I18n.t("пишет", "Writing"),
            "turn_end": I18n.t("готово", "Done"),
            "idle": I18n.t("тлеет", "Smouldering"),
            "none": I18n.t("ни души", "No souls")
        })
    readonly property var resting: ["idle", "turn_end", "error"]

    property var sessions: ({})     // from hooks: sid -> {state, model, in, out, cc, cr, at}
    property var scanned: []        // from transcripts (hooks/scan.py): [{id, state, model, …, age}]
    // hook data wins while it is fresh; transcripts fill in everything else
    readonly property var list: {
        const out = {};
        for (const s of scanned)
            out[s.id] = Object.assign({}, s, {
                "at": Date.now() - s.age * 1000,
                "source": "scan"
            });
        for (const k of Object.keys(sessions)) {
            const h = sessions[k];
            if (!out[k] || Date.now() - h.at < 120000)
                out[k] = Object.assign({
                    "id": k,
                    "source": "hook",
                    "cwd": out[k] ? out[k].cwd : ""
                }, h);
        }
        return Object.values(out).sort((a, b) => b.at - a.at);
    }

    // one scan.py for the shell's whole life: it looks every 3 s and prints a line only when
    // something changed (a Python started every 3 s cost more than all of the plugin's drawing);
    // scan() starts it again if it ended
    function scan() {
        if (!scanner.running)
            scanner.running = true;
    }
    Process {
        id: scanner
        command: ["python3", "-u", Quickshell.shellDir + "/plugins/claude-companion/hooks/scan.py", "--watch", "3"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    root.scanned = JSON.parse(line) || [];
                } catch (e) {}
            }
        }
    }
    readonly property string state: {
        let best = "none", p = 0;
        for (const s of list)
            if ((priority[s.state] || 1) > p) {
                p = priority[s.state] || 1;
                best = s.state;
            }
        return best;
    }
    readonly property string word: words[state] || state
    property var presence: null     // {message, state, at} written by the MCP shim
    property var answer: null       // {q, text, at, error}
    property bool asking: false
    readonly property string runtimeDir: (Quickshell.env("XDG_RUNTIME_DIR") || Quickshell.env("HOME") + "/.cache/angelos") + "/claude-companion"

    function wordFor(hell) {
        return (hell ? hellWords[state] : words[state]) || state;
    }
    function hellColorFor(s, theme) {
        // the circle's text roles only (readable on its plates); the one accent when it wants you
        return s === "needs_attention" || s === "error" ? theme.hellAccent : s === "idle" || s === "none" ? theme.hellTextDim : theme.hellText;
    }
    function colorFor(s, theme) {
        return s === "needs_attention" || s === "error" ? theme.danger : s === "tool_start" ? theme.accent3 : s === "turn_start" || s === "text" ? theme.accent : s === "turn_end" ? theme.ok : s === "idle" ? theme.accent4 : theme.textDim;
    }

    function event(name, payload) {
        const f = (payload || "").split(",");
        const sid = f.length >= 6 && f[5] ? f[5] : "default";
        const copy = Object.assign({}, sessions);
        if (name === "session_end" || (sid === "default" && resting.includes(name))) {
            delete copy[sid];
        } else {
            const old = copy[sid] || {};
            copy[sid] = {
                "state": name,
                "model": f[0] && f[0] !== "?" ? f[0] : (old.model || "?"),
                "in": parseInt(f[1]) || old.in || 0,
                "out": parseInt(f[2]) || old.out || 0,
                "cc": parseInt(f[3]) || old.cc || 0,
                "cr": parseInt(f[4]) || old.cr || 0,
                "at": Date.now()
            };
        }
        sessions = copy;
    }
    function retire(sid) {
        event("session_end", ",,,,," + sid);
    }
    function burn(s) {
        const k = n => n >= 1e6 ? (n / 1e6).toFixed(1) + "M" : n >= 1e3 ? (n / 1e3).toFixed(0) + "k" : String(n);
        return s.in + s.out > 0 ? k(s.in + s.cc) + I18n.t(" вх · ", " in · ") + k(s.out) + I18n.t(" вых · кэш ", " out · cache ") + k(s.cr) : "";
    }

    function readPresence() {
        presenceFile.reload();
    }
    FileView {
        id: presenceFile
        path: root.runtimeDir + "/presence"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.presence = JSON.parse(text());
            } catch (e) {
                root.presence = null;
            }
        }
        onLoadFailed: root.presence = null
    }

    // ---- quick ask: read-only one-shot `claude -p` (no tools, no user settings/MCP) ----
    readonly property string askNote: "Your answer is delivered as a desktop notification. Lead with the direct answer in one or two short sentences; add detail only if the question genuinely needs it. Plain text only — no markdown formatting. Answer in the language of the question."
    property string _acc: ""
    function ask(q) {
        q = (q || "").trim();
        if (!q || asker.running)
            return;
        asking = true;
        _acc = "";
        answer = {
            "q": q,
            "text": "",
            "at": Date.now(),
            "error": false
        };
        event("turn_start", "?,0,0,0,0,ask");
        // the question goes on stdin: argv is visible to every process
        asker.question = q;
        asker.command = ["sh", "-c", 'PATH="$HOME/.local/bin:$PATH"; exec claude --tools "" --strict-mcp-config --setting-sources "" --output-format stream-json --verbose --append-system-prompt "$1" -p', "sh", askNote];
        asker.running = true;
    }
    function finishAsk(text, error) {
        asking = false;
        answer = {
            "q": answer ? answer.q : "",
            "text": text,
            "at": Date.now(),
            "error": error
        };
        event(error ? "error" : "turn_end", "?,0,0,0,0,ask");
        Quickshell.execDetached(["notify-send", "-a", "Claude", error ? I18n.t("Claude: ошибка", "Claude: error") : I18n.t("Claude ответил ♡", "Claude replied ♡"), text.length > 280 ? text.slice(0, 280) + "…" : text]);
        retireAsk.restart();
    }
    Timer {
        id: retireAsk
        interval: 8000
        onTriggered: root.retire("ask")
    }
    Process {
        id: asker
        property string question: ""
        stdinEnabled: true
        onStarted: {
            write(question);
            stdinEnabled = false;
        }
        stdout: SplitParser {
            onRead: line => {
                let ev;
                try {
                    ev = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (ev.type === "assistant" && ev.message && ev.message.content) {
                    for (const c of ev.message.content)
                        if (c.type === "text" && c.text)
                            root._acc += c.text;
                    root.event("text", "?,0,0,0,0,ask");
                    if (root.answer)
                        root.answer = Object.assign({}, root.answer, {
                            "text": root._acc
                        });
                } else if (ev.type === "result") {
                    const txt = (ev.result || root._acc || "").trim();
                    root.finishAsk(txt || I18n.t("(пустой ответ)", "(empty answer)"), !!ev.is_error);
                }
            }
        }
        stderr: StdioCollector {
            id: askErr
        }
        onExited: code => {
            stdinEnabled = true;
            if (root.asking)
                root.finishAsk(code === 127 ? I18n.t("claude не найден в PATH", "Claude was not found in PATH") : (askErr.text.trim() || root._acc || I18n.t("claude завершился с кодом ", "Claude exited with code ") + code), true);
        }
    }

    // ---- terminal launches ----
    readonly property string shim: Quickshell.shellDir + "/plugins/claude-companion/shim/angelos-mcp.py"
    readonly property string systemNote: "You are running inside the angelOS desktop shell (Quickshell on niri), launched from its Claude Companion plugin. An MCP server named 'angelos' gives you live desktop senses and hands: PERCEIVE — get_window, get_workspace, get_media, get_shell_state, get_power, get_network, get_processes. ACT — notify, set_theme_mode (dark/light/auto), set_color_scheme (overdose/bubblegum/cyberangel/wallpaper/gruvbox/rosepine/catppuccin/nord/dracula/tokyonight/solarized/everforest), focus_window, switch_workspace, move_to_workspace, set_wallpaper, set_presence/clear_presence. MEMORY — remember. Call the perceive tools when current desktop context matters instead of assuming it."
    function launch(args, mcp) {
        const mcpJson = JSON.stringify({
            "mcpServers": {
                "angelos": {
                    "command": "python3",
                    "args": [shim]
                }
            }
        });
        const flags = mcp ? ["--mcp-config", mcpJson, "--append-system-prompt", systemNote] : [];
        const argv = ["sh", "-c", 'cd "$HOME"; PATH="$HOME/.local/bin:$PATH"; exec claude "$@"', "sh"].concat(flags).concat(args);
        Quickshell.execDetached(Shell.terminalArgv(argv));
    }
}
