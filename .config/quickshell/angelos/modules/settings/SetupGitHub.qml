pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// The wizard's GitHub step (SetupFlow keeps it, so a login goes on while the steps change):
// gh's own login, the device way — the wizard covers every screen, so the code is shown big
// with a QR of github.com/login/device for a phone. Then the author's tools
// (scripts/author-tools.sh: owner/ from the private repo, only for an account GitHub lets
// in) and the owner check (services/Owner). angelOS keeps no token: gh does.
Scope {
    id: root

    // "" asking | no-gh | no-login | waiting (the code is up) | access | no-access |
    // fetching | ready (the tools are here) | error
    property string state: ""
    property string login: ""
    property string code: ""
    property string error: ""
    readonly property string deviceUrl: "https://github.com/login/device"
    readonly property string qrPath: Config.cacheDir + "/github-device-qr.png"
    property bool qrReady: false
    readonly property string script: Quickshell.shellDir + "/scripts/author-tools.sh"
    // nothing more to do here: the step's button says "Continue", not "Skip"
    readonly property bool settled: state === "ready" || state === "no-access"

    function refresh() {
        if (signIn.running || fetcher.running)
            return;
        status.running = false;
        status.running = true;
    }
    function startLogin() {
        error = "";
        code = "";
        state = "waiting";
        if (!qrReady)
            qr.running = true;
        signIn.running = true;
    }
    function cancel() {
        signIn.running = false;
        code = "";
        state = "no-login";
    }
    function fetch() {
        error = "";
        state = "fetching";
        fetcher.running = true;
    }

    // "here|partial|absent access|no-access|no-login|no-gh <login>" (partial: fetch adds the rest)
    Process {
        id: status
        command: ["sh", root.script, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                // split on spaces without a RegExp: a regex argument here reached a QString
                // overload ("Cannot assign QRegularExpression to QString")
                const parts = String(text || "").replace(/\n/g, " ").trim().split(" ").filter(x => x !== "");
                const here = parts[0] || "", st = parts[1] || "", who = parts[2] || "";
                root.login = who || "";
                if (st === "access" && here === "here") {
                    root.state = "ready";
                    Owner.refresh();
                } else
                    root.state = st || "error";
            }
        }
    }
    Process {
        id: signIn
        command: ["gh", "auth", "login", "--hostname", "github.com", "--git-protocol", "https", "--web"]
        // no browser behind the cover: the code and the QR are on screen
        environment: ({
                "BROWSER": "true",
                "GH_PROMPT_DISABLED": "1"
            })
        stderr: SplitParser {
            onRead: line => {
                const m = line.match(/one-time code:\s*(\S+)/);
                if (m)
                    root.code = m[1];
            }
        }
        stdout: SplitParser {
            onRead: line => {
                const m = line.match(/one-time code:\s*(\S+)/);
                if (m)
                    root.code = m[1];
            }
        }
        onExited: code => {
            if (root.state !== "waiting")
                return;     // cancelled
            if (code === 0) {
                root.state = "";
                root.refresh();
            } else {
                root.state = "error";
                root.error = I18n.t("Вход в GitHub не завершился", "The GitHub login did not finish");
            }
        }
    }
    Process {
        id: fetcher
        command: ["sh", root.script, "fetch"]
        stderr: StdioCollector {
            onStreamFinished: if (text.trim())
                root.error = text.trim().split("\n").pop()
        }
        onExited: code => {
            if (code === 0) {
                root.state = "ready";
                Owner.refresh();
            } else
                root.state = "error";
        }
    }
    Process {
        id: qr
        command: ["sh", "-c", 'command -v qrencode >/dev/null && mkdir -p "$(dirname "$1")" && qrencode -o "$1" -s 8 -m 2 "$2"', "sh", root.qrPath, root.deviceUrl]
        onExited: code => root.qrReady = code === 0
    }
}
