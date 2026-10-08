pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "CalcCore.js" as Core

// The calculator in Start's search and the launcher (Win+Space): maths, units and
// currencies (services/CalcCore.js). Currency rates per 1 USD come from open.er-api.com
// (no key, updated daily), fetched only when a currency is asked for and kept for 12 hours
// in ~/.cache/angelos/rates.json, so it works offline with the last known rate.
Singleton {
    id: root

    property var rates: null
    property double ratesTime: 0          // unix seconds of the provider's update
    property double fetchedAt: 0          // ms
    property bool fetching: false
    property string rateError: ""
    readonly property bool stale: !rates || Date.now() - fetchedAt > 12 * 3600 * 1000
    readonly property string cacheFile: Config.cacheDir + "/rates.json"

    // {kind: math|unit|money, title, copy, subtitle} or null when the text is not a sum
    function evaluate(text) {
        if (Config.launcher.calc === false)
            return null;
        const t = String(text || "").trim();
        if (t.length < 2 || t.length > 200)
            return null;
        const en = I18n.english;
        const enter = I18n.t("Enter — скопировать", "Enter to copy");
        const m = Core.money(t, rates);
        if (m) {
            if (stale)
                fetchRates();
            if (!rates || !rates[m.from] || !rates[m.to])
                return {
                    "kind": "money",
                    "title": Core.pretty(Core.format(m.amount), en) + " " + m.from + " → " + m.to,
                    "copy": "",
                    "subtitle": fetching || !rateError ? I18n.t("загружаю курс…", "fetching the rate…") : I18n.t("нет курса: ", "no rate: ") + rateError
                };
            const v = m.amount / rates[m.from] * rates[m.to];
            const s = Core.format(Math.abs(v) >= 1 ? Math.round(v * 100) / 100 : Number(v.toPrecision(4)));
            const day = ratesTime ? Qt.formatDate(new Date(ratesTime * 1000), "d.MM.yyyy") : "";
            return {
                "kind": "money",
                "title": Core.pretty(Core.format(m.amount), en) + " " + m.from + " = " + Core.pretty(s, en) + " " + m.to,
                "copy": s,
                "subtitle": I18n.t("курс на ", "rate of ") + day + " · open.er-api.com · " + enter
            };
        }
        const u = Core.convert(t);
        if (u)
            return {
                "kind": "unit",
                "title": Core.pretty(u.amount, en) + " " + u.from + " = " + Core.pretty(u.text, en) + " " + u.to,
                "copy": u.text,
                "subtitle": enter
            };
        const r = Core.math(t);
        if (r)
            return {
                "kind": "math",
                "title": "= " + Core.pretty(r.text, en),
                "copy": r.text,
                "subtitle": t + (r.degrees ? I18n.t(" · углы в градусах", " · angles in degrees") : "") + " · " + enter
            };
        return null;
    }
    function copy(result) {
        if (result && result.copy)
            Quickshell.execDetached(["wl-copy", "--", result.copy]);
    }

    function fetchRates() {
        if (fetching || (rateError && Date.now() - fetchedAt < 60000))
            return;
        fetching = true;
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            fetching = false;
            let body = null;
            try {
                body = xhr.status === 200 ? JSON.parse(xhr.responseText) : null;
            } catch (e) {}
            if (body && body.result === "success" && body.rates) {
                rates = body.rates;
                ratesTime = body.time_last_update_unix || Date.now() / 1000;
                fetchedAt = Date.now();
                rateError = "";
                cache.write(JSON.stringify({
                    "rates": rates,
                    "time": ratesTime,
                    "fetched": fetchedAt
                }));
            } else {
                fetchedAt = rates ? fetchedAt : Date.now();
                rateError = xhr.status ? "HTTP " + xhr.status : I18n.t("нет сети", "offline");
            }
        };
        xhr.open("GET", "https://open.er-api.com/v6/latest/USD");
        xhr.send();
    }

    AsyncFile {
        id: cache
        path: root.cacheFile
        onLoaded: {
            try {
                const c = JSON.parse(text());
                if (c.rates) {
                    root.rates = c.rates;
                    root.ratesTime = c.time || 0;
                    root.fetchedAt = c.fetched || 0;
                }
            } catch (e) {}
        }
    }
}
