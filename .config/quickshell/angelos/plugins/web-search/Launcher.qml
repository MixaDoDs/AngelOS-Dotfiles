import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import "Engines.js" as Engines

// Launcher provider: "web <query>" searches, bare text matches favourite sites.
QtObject {
    id: root

    property var plugin
    property string pluginId
    readonly property string prefix: "web"
    readonly property bool global: true
    signal changed

    readonly property string iconDir: Config.cacheDir + "/web-search"
    property var icons: ({})       // domain -> local png path
    property var pending: ({})

    function engine() {
        return Engines.engines[plugin ? plugin.get("provider", "google") : "google"] || Engines.engines.google;
    }
    function links() {
        const raw = plugin ? plugin.get("links", Engines.defaultLinks) : Engines.defaultLinks;
        return raw.map(l => {
            const i = l.indexOf("|");
            return i > 0 ? {
                "name": l.slice(0, i).trim(),
                "url": l.slice(i + 1).trim()
            } : null;
        }).filter(l => l && /^https?:\/\//.test(l.url));
    }
    function fuzzy(q, s) {
        q = q.toLowerCase();
        s = s.toLowerCase();
        if (!q)
            return 1;
        if (s.startsWith(q))
            return 60;
        if (s.includes(q))
            return 40;
        let i = 0;
        for (const ch of s)
            if (ch === q[i])
                i++;
        return i === q.length ? 15 : -1;
    }
    function icon(domain) {
        if (!domain)
            return "";
        if (icons[domain])
            return icons[domain];
        if (!pending[domain]) {
            pending[domain] = true;
            const safe = domain.replace(/[^\w.-]/g, "_");
            const path = iconDir + "/" + safe + ".png";
            const p = fetcher.createObject(root, {
                "domain": domain,
                "path": path
            });
            p.running = true;
        }
        return "";
    }

    property Component fetcher: Component {
        Process {
            id: proc
            property string domain
            property string path
            command: ["sh", "-c", '[ -s "$2" ] || { mkdir -p "$(dirname "$2")" && curl -fsSL --max-time 5 -o "$2" "https://www.google.com/s2/favicons?sz=64&domain=$1"; }; [ -s "$2" ]', "sh", domain, path]
            onExited: code => {
                if (code === 0) {
                    const m = Object.assign({}, root.icons);
                    m[proc.domain] = proc.path;
                    root.icons = m;
                    root.changed();
                }
                proc.destroy();
            }
        }
    }

    function query(text, prefixed) {
        const out = [];
        const mru = plugin ? plugin.get("mru", {}) : {};
        const list = links();
        list.forEach((l, i) => {
            const s = fuzzy(text, l.name);
            if (s < 0 || (!prefixed && s < 15))
                return;
            out.push({
                "id": "open:" + l.url,
                "title": l.name,
                "subtitle": l.url,
                "icon": "sparkle",
                "image": icon(Engines.domainOf(l.url)),
                "score": (prefixed ? 50 : s - 5) + (mru[l.url] || 0) / 1000 - i / 1000
            });
        });
        if (text) {
            const e = engine();
            out.push({
                "id": "search:" + text,
                "title": I18n.t("Искать в ", "Search with ") + e.label,
                "subtitle": text,
                "icon": "search",
                "image": icon(e.domain),
                "score": prefixed ? 1000 : 1
            });
        }
        return out;
    }

    function activate(id) {
        if (id.startsWith("open:")) {
            const url = id.slice(5);
            const mru = Object.assign({}, plugin.get("mru", {}));
            const values = Object.values(mru).map(v => Number(v) || 0);
            mru[url] = Math.max.apply(Math, [0].concat(values)) + 1;
            plugin.set("mru", mru);
            Shell.exec(["xdg-open", url]);
        } else if (id.startsWith("search:")) {
            const url = engine().url.replace("%s", encodeURIComponent(id.slice(7)));
            Shell.exec(["xdg-open", url]);
        }
    }
}
