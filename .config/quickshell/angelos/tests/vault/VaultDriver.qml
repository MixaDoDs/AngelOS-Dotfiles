pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings

// Passwords and spelling inside the shell (started by tests/vault/run.sh, offscreen): the
// Vault service against stand-ins of bw / rbw / op and of the clipboard — states, unlocking
// with a typed master password, the launcher's "pw …" rows, masking on air, locking — and the
// Spell service with two tiny dictionaries: a text area underlines what is misspelt, offers
// corrections, learns a word. Then the two settings pages are opened.
Scope {
    id: root

    property int step: 0
    property double since: Date.now()
    property var notes: ({})

    function report(name, ok, detail) {
        console.log("TEST " + name + " " + (ok ? "PASS" : "FAIL") + " " + (detail === undefined ? "" : detail));
    }
    function next() {
        step++;
        since = Date.now();
    }
    // wait until cond() (then report and go on) or for at most ms
    function until(name, cond, ms, detail) {
        let ok = false;
        try {
            ok = !!cond();
        } catch (e) {
            ok = false;
            detail = () => String(e);
        }
        if (!ok && Date.now() - since < (ms || 8000))
            return false;
        report(name, ok, detail ? detail() : "");
        next();
        return true;
    }
    // ANGELOS_VAULT_SHOTS=dir: pictures of the two pages and of a note with mistakes in it
    readonly property string shots: Quickshell.env("ANGELOS_VAULT_SHOTS") || ""
    function shot(item, name) {
        item.grabToImage(r => r.saveToFile(root.shots + "/" + name + ".png"));
    }
    function state(id) {
        const b = Vault.backend(id);
        return b ? b.state : "?";
    }
    function titles(q) {
        return Vault.rows(q).map(r => r.kind + ":" + r.title);
    }

    FloatingWindow {
        id: win
        implicitWidth: 1000
        implicitHeight: 700
        title: "angelOS vault test"
        SettingsView {
            id: view
            anchors.fill: parent
            hostWindow: win
        }
        PxTextArea {
            id: area
            z: 10
            width: 400
            height: 160
        }
        PxField {
            id: line
            z: 10
            y: 200
            width: 400
            spell: true
        }
    }
    // the launcher itself is a layer-shell window: there is none offscreen, so its rows are
    // asked for the way it asks (Vault.match → Vault.rows) and it is looked at on a real screen
    // (scripts/test-ui.sh)
    QtObject {
        id: launcher
        readonly property var item: null
    }

    Timer {
        interval: 50
        repeat: true
        running: true
        onTriggered: {
            const L = launcher.item;
            switch (root.step) {
            case 0:
                if (!Config.ready)
                    return;
                root.report("prefix", Vault.match("pw git") === "git" && Vault.match("  Пароль  почта ") === "почта" && Vault.match("pw") === "" && Vault.match("pwgit") === null && Vault.match("power") === null && Vault.match("pass x") === "x");
                root.report("before-look", root.titles("")[0].startsWith("wait:"), root.titles("").join(" | "));
                Vault.touch();
                root.next();
                return;
            case 1:
                root.until("states", () => Vault.loaded && root.state("bw") === "locked" && root.state("rbw") === "locked" && root.state("op") === "setup", 15000, () => JSON.stringify(Vault.backends));
                return;
            case 2:
                {
                    const t = root.titles("");
                    // a manager not signed in to is not offered while another can be opened
                    root.report("locked-rows", t.length === 2 && t.every(x => x.startsWith("unlock:")) && Vault.items.length === 0, t.join(" | "));
                    root.report("who-asks", Vault.wantsPassword("bw") && !Vault.wantsPassword("rbw"));
                    if (L) {
                        L.query = "pw";
                        root.report("launcher-mode", L.vaultMode && L.results.length === 3 && L.results[0].builtin === "vault" && L.kindOf(L.results[0]) !== "" && !L.pickedLogin, L.mode + " " + L.results.length);
                        L.activate(L.results.find(r => r.vault.backend === "bw"));
                        root.report("launcher-asks", L.unlockFor === "bw", L.unlockFor);
                        L.query = "firefox";
                        root.report("launcher-leaves", !L.vaultMode && L.unlockFor === "" && !L.results.some(r => r.builtin === "vault"));
                    }
                    Vault.unlock("bw", "wrong");
                    root.next();
                }
                return;
            case 3:
                root.until("wrong-password", () => !Vault.busy && Vault.error !== "" && root.state("bw") === "locked" && !Vault.sessions.bw, 15000, () => Vault.error + " " + root.state("bw"));
                return;
            case 4:
                Vault.unlock("bw", "correct horse");
                root.next();
                return;
            case 5:
                root.until("unlocked", () => root.state("bw") === "unlocked" && Vault.listed && Vault.items.length === 3 && !!Vault.sessions.bw && Vault.mine.includes("bw") && Vault.error === "", 20000, () => root.state("bw") + " items " + Vault.items.length + " " + Vault.error + JSON.stringify(Vault.errors));
                return;
            case 6:
                {
                    const t = root.titles("git");
                    // a name typed: the entry leads, the manager still closed waits below it
                    root.report("find", t.join("|") === "item:GitHub|unlock:Открыть Bitwarden (rbw)" && root.titles("")[0].startsWith("unlock:") && root.titles("example.org").some(x => x === "item:Почта") && root.titles("angel@").some(x => x === "item:GitHub") && root.titles("нет такого").filter(x => x.startsWith("item:")).length === 0, t.join(" | "));
                    root.report("no-secrets", !/gh-secret|пароль-ё|wifi pass|123456/.test(JSON.stringify(Vault.items) + Vault.ipc("status") + Vault.ipc("find git")), Vault.ipc("find git"));
                    const row = Vault.rows("git").find(r => r.kind === "item");
                    root.report("plain", row.subtitle === "angel@example.com" && !Vault.discreet, row.subtitle + " active=" + StreamMode.active + " up=" + StreamMode.obsUp + " rec=" + StreamMode.obsRec + " privacy=" + Privacy.on + " port=" + Config.stream.port);
                    // nothing typed: the entry of the site in front comes first, before the manager still closed
                    Vault.context = "входящие — mail.example.org — helium";
                    const near = Vault.rows("");
                    root.report("fits-the-window", near[0].kind === "item" && near[0].title === "Почта" && near[1].kind === "unlock" && Vault.fits(Vault.items.find(i => i.name === "GitHub"), "github · pull requests") && !Vault.fits(Vault.items.find(i => i.name === "GitHub"), "почта"), near.map(r => r.title).join(" | "));
                    Vault.context = "";
                    Config.vault.hideOnStream = true;
                    Config.stream.manual = true;
                    root.next();
                }
                return;
            case 7:
                root.until("on-air", () => {
                    const row = Vault.rows("git")[0];
                    return Vault.discreet && row.kind === "item" && row.title === "G•••" && row.subtitle === "a•••@e•••";
                }, 4000, () => JSON.stringify(Vault.rows("git").map(r => [r.title, r.subtitle])));
                return;
            case 8:
                Config.stream.manual = false;
                Config.vault.hideOnStream = false;
                if (L) {
                    L.query = "pw wi-fi";
                    root.report("launcher-login", !!L.pickedLogin && L.pickedLogin.item.name === "Wi-Fi дома" && L.results.length === 1, L.results.length);
                    L.vaultAct(L.pickedLogin, "password");
                } else {
                    Vault.copy(Vault.items.find(i => i.name === "Wi-Fi дома"), "password");
                }
                root.next();
                return;
            case 9:
                root.until("copied", () => Vault.told !== "" && !Vault._job, 15000, () => Vault.told + " / " + Vault.error);
                return;
            case 10:
                Shell.locked = true;
                root.next();
                return;
            case 11:
                root.until("locks-with-screen", () => root.state("bw") === "locked" && Vault.items.length === 0 && !Vault.sessions.bw && Vault.mine.length === 0 && !Vault._job, 15000, () => root.state("bw") + " " + Vault.items.length);
                return;
            case 12:
                Shell.locked = false;
                Vault.unlock("rbw");
                root.next();
                return;
            case 13:
                root.until("rbw-own-prompt", () => root.state("rbw") === "unlocked" && Vault.items.length === 3 && Vault.items[0].backend === "rbw" && root.state("bw") === "locked", 20000, () => root.state("rbw") + " " + Vault.items.length + " " + Vault.error);
                return;
            case 14:
                Config.vault.enabled = false;
                root.report("switched-off", Vault.match("pw git") === null);
                Config.vault.enabled = true;
                Vault.lock();
                // ---- spelling ----
                root.report("spell-idle", !Spell.loaded && !Spell.ready);
                area.text = "привет мирр, hello wrold";
                area.input.forceActiveFocus();
                root.next();
                return;
            case 15:
                // offscreen there may be no active window: the field is told it was entered
                if (!area.spelling) {
                    if (Date.now() - root.since > 600) {
                        root.notes.forced = true;
                        area.spellWanted = true;
                    }
                    return;
                }
                if (!area.spelling.touched && Date.now() - root.since > 600) {
                    root.notes.forced = true;
                    area.spelling.touched = true;
                    Spell.want();
                    area.spelling.recheck();
                }
                if (Spell.ready && area.spelling.touched && !area.spelling.errors.length && Date.now() - root.since > 1500)
                    area.spelling.recheck();
                root.until("underlined", () => Spell.ready && area.spelling.errors.map(e => e.w).join(",") === "мирр,wrold" && area.spelling.marks.length === 2 && area.spelling.marks[0].w > 0 && area.spelling.marks[1].x > area.spelling.marks[0].x, 15000, () => JSON.stringify(area.spelling.errors) + JSON.stringify(area.spelling.marks) + " installed " + JSON.stringify(Spell.installed.map(d => d.code)) + (root.notes.forced ? " (focus forced)" : ""));
                return;
            case 16:
                {
                    // typing before a mark moves it along at once, before the next answer
                    const before = area.spelling.errors[1].s;
                    area.input.cursorPosition = 0;
                    area.input.insert(0, "ой ");
                    root.report("marks-follow", area.spelling.errors.length === 2 && area.spelling.errors[1].s === before + 3 && area.text.substr(area.spelling.errors[1].s, 5) === "wrold", JSON.stringify(area.spelling.errors));
                    Spell.suggest("wrold", list => root.notes.suggest = list);
                    root.next();
                }
                return;
            case 17:
                root.until("suggests", () => (root.notes.suggest || []).includes("world"), 8000, () => JSON.stringify(root.notes.suggest));
                return;
            case 18:
                area.spelling.current = area.spelling.errors.find(e => e.w === "wrold");
                area.spelling.replace("world");
                root.next();
                return;
            case 19:
                root.until("replaced", () => area.text === "ой привет мирр, hello world" && area.spelling.errors.map(e => e.w).join(",") === "мирр", 8000, () => area.text + " " + JSON.stringify(area.spelling.errors));
                return;
            case 20:
                Spell.learn("мирр");
                root.next();
                return;
            case 21:
                root.until("learnt", () => area.spelling.errors.length === 0 && area.spelling.marks.length === 0, 8000, () => JSON.stringify(area.spelling.errors));
                return;
            case 22:
                Spell.forget("мирр");
                Spell.setOn("ru", false);
                root.next();
                return;
            case 23:
                root.until("language-off", () => Spell.active.length === 1 && area.spelling.errors.length === 0, 8000, () => JSON.stringify(area.spelling.errors));
                return;
            case 24:
                Spell.setOn("ru", true);
                root.next();
                return;
            case 25:
                root.until("language-on", () => area.spelling.errors.map(e => e.w).join(",") === "мирр", 8000, () => JSON.stringify(area.spelling.errors));
                return;
            case 26:
                Config.spell.enabled = false;
                root.next();
                return;
            case 27:
                root.until("check-off", () => !area.spelling, 8000, () => "the overlay is still there");
                return;
            case 28:
                Config.spell.enabled = true;
                line.text = "wrold";
                line.input.forceActiveFocus();
                root.report("ipc", JSON.parse(Spell.ipc("status")).installed.join(",") === "en,ru" && Spell.ipc("help").startsWith("angelos spell") && Vault.ipc("help").startsWith("angelos vault") && Vault.ipc("unlock bw").includes("pw"), Spell.ipc("status"));
                Shell.settingsPage = "vault";
                root.next();
                return;
            case 29:
                root.until("page-vault", () => Date.now() - root.since > 1200 && Shell.settingsPage === "vault" && view.pageUp, 6000, () => Shell.settingsPage);
                return;
            case 30:
                Shell.settingsPage = "spell";
                root.next();
                return;
            case 31:
                root.until("page-spell", () => Date.now() - root.since > 1200 && Shell.settingsPage === "spell" && view.pageUp, 6000, () => Shell.settingsPage);
                return;
            case 32:
                if (!root.shots) {
                    root.step = 200;
                    root.since = Date.now();
                    return;
                }
                area.visible = false;
                line.visible = false;
                root.shot(view, "page-spell");
                root.next();
                return;
            case 33:
                if (Date.now() - root.since < 600)
                    return;
                if (Shell.settingsPage !== "vault") {
                    Shell.settingsPage = "vault";
                    root.since = Date.now() + 1200;
                    return;
                }
                root.shot(view, "page-vault");
                root.since = Date.now();
                root.step = 133;
                return;
            case 133:
                if (Date.now() - root.since < 600)
                    return;
                root.step = 33;
                area.visible = true;
                area.text = "Привет! Это замтка с ашибкой.\nHello wrold, this is fine.";
                area.input.forceActiveFocus();
                area.input.cursorPosition = area.text.indexOf("wrold") + 2;
                root.next();
                return;
            case 34:
                if (Date.now() - root.since < 2500)
                    return;
                root.shot(area, "note");
                root.next();
                return;
            case 35:
                if (Date.now() - root.since < 800)
                    return;
                root.step = 200;
                root.since = Date.now();
                return;
            // ---- no master password each time: remembered in the (stand-in) keyring, then under a PIN ----
            case 200:
                Vault.remember("bw", "correct horse", "");
                root.next();
                return;
            case 201:
                root.until("remembered", () => root.state("bw") === "unlocked" && Vault.backend("bw").saved === "keyring" && Vault.asks("bw") === "" && !Vault._job, 20000, () => root.state("bw") + " " + JSON.stringify(Vault.backend("bw")) + Vault.error);
                return;
            case 202:
                Vault.lock();
                root.next();
                return;
            case 203:
                if (root.state("bw") !== "locked" || Vault._job || Vault.busy || Date.now() - root.since < 1500)
                    return;
                // the launcher goes into "pw": the vault opens by itself, nothing typed
                Vault.probedAt = 0;
                Vault.touch();
                root.next();
                return;
            case 204:
                root.until("opens-by-itself", () => root.state("bw") === "unlocked" && Vault.items.length === 3 && !Vault._job, 20000, () => root.state("bw") + " " + Vault.items.length + " " + Vault.error);
                return;
            case 205:
                Vault.forget("bw");
                Vault.lock();
                root.next();
                return;
            case 206:
                if (Vault._job || Vault.busy || root.state("bw") !== "locked" || Date.now() - root.since < 1500)
                    return;
                root.report("forgotten", Vault.backend("bw").saved === "" && Vault.asks("bw") === "password", JSON.stringify(Vault.backend("bw")));
                Vault.remember("bw", "correct horse", "4821");
                root.next();
                return;
            case 207:
                root.until("under-a-pin", () => root.state("bw") === "unlocked" && Vault.backend("bw").saved === "pin" && !Vault._job, 20000, () => JSON.stringify(Vault.backend("bw")) + Vault.error);
                return;
            case 208:
                Vault.lock();
                root.next();
                return;
            case 209:
                if (Vault._job || Vault.busy || root.state("bw") !== "locked" || Date.now() - root.since < 1500)
                    return;
                root.report("asks-the-pin", Vault.asks("bw") === "pin" && Vault.wantsPassword("bw"));
                Vault.unlock("bw", "0000");
                root.next();
                return;
            case 210:
                root.until("wrong-pin", () => !Vault.busy && Vault.error !== "" && root.state("bw") === "locked" && Vault.asks("bw") === "pin", 15000, () => Vault.error);
                return;
            case 211:
                Vault.unlock("bw", "4821");
                root.next();
                return;
            case 212:
                root.until("pin-opens", () => root.state("bw") === "unlocked" && Vault.items.length === 3 && Vault.error === "", 20000, () => root.state("bw") + " " + Vault.error);
                return;
            default:
                stop();
                console.log("TEST DONE");
                Qt.quit();
            }
        }
    }
}
