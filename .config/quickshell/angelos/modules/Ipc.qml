import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.modules.mac

// `qs -c angelos ipc call angelos <fn> [args]` — the `angelos` CLI wraps this.
IpcHandler {
    target: "angelos"

    // While the first-run wizard holds the desktop (Shell.setupLocked) the shell's hotkeys —
    // niri's binds call these — and the other ways in wait until it is done or skipped.
    function settings(page: string): void {
        if (Shell.setupLocked)
            return;
        Shell.toggleSettings(page);
    }
    function showLyrics(): void {
        if (Shell.setupLocked)
            return;
        Config.lyrics.enabled = true;
        Config.lyrics.screens = [];
        Lyrics.visibleToggle = true;
    }
    // osu!mini's rhythm mode on the track that plays now (the Halo's «Ритм» by the music)
    function rhythm(): void {
        if (Shell.setupLocked)
            return;
        Shell.gameAsk = "rhythm";
        Shell.gameOpen = true;
    }
    // the people of the Discord call walking over the bar: on / off
    function discordCrew(): void {
        Config.discord.crew = !Config.discord.crew;
    }
    // the keys pressed, on screen (Mod+Shift+K): on / off
    function keycast(): void {
        if (Shell.setupLocked)
            return;
        KeyCast.toggle();
    }
    // the «what's new» paper of this release on the desktop again (Updates.paperShown)
    function paper(): void {
        Updates.paperForced = true;
    }
    // the setup wizard again, as a window that holds nothing (the first run opens by itself)
    function setup(): void {
        Shell.setupOpen = true;
    }
    // the first run's intro alone, as everyone sees it once after an update brings a new one
    function intro(): void {
        Shell.introRequested();
    }
    // open the wizard on a given step (0 = welcome)
    function setupStep(step: int): void {
        Shell.setupOpen = true;
        Shell.setupStepRequested(step);
    }
    // the way out of the first-run wizard, also when its window is broken: `angelos setup
    // skip` (scripts/setup-cli.py) leaves ~/.config/angelos/setup-skipped first, then asks here
    function setupSkip(): void {
        Shell.setupSkipRequested();
    }
    // Start menu on a screen (default: focused); what a Meta tap does
    function startMenu(screen: string): void {
        if (Shell.setupLocked)
            return;
        Shell.toggleStart(screen);
    }
    // the owner check: GitHub's answer for the dotfiles repo (services/Owner)
    function owner(): string {
        return (Owner.check || "not asked") + (Owner.login ? " " + Owner.login : "") + (Owner.enabled ? " · owner features on" : " · owner features off");
    }
    // the lens at the pointer: in | out | close | toggle | refresh (services/Lens)
    function lens(cmd: string): void {
        Lens.cmd(cmd, "");
    }
    // …on a given screen (tests, the dev stand)
    function lensOn(cmd: string, screen: string): void {
        Lens.cmd(cmd, screen);
    }
    // show where the pointer is, as if the mouse were shaken (a niri bind can call it)
    function findCursor(): void {
        CursorShake.demo();
    }
    // open Start with its search filled in: `angelos startText "2+2"` (classic Start: the launcher)
    function startText(text: string): void {
        if (Shell.setupLocked)
            return;
        if (Config.bar.startStyle === "classic" || !Config.bar.startStyle) {
            launcherText(text);
            return;
        }
        Shell.startPrefill = text;
        Shell.openStart("");
    }
    // switch workspaces through angelOS: a number, up, down or prev
    function ws(target: string): void {
        WorkspaceAnim.go(target);
    }
    // dev only: fake niri workspaces on an output and switch between them the way
    // niri reports it (a new workspace list, then the activation), to test the
    // bar animations without touching real workspaces
    function fakeSwitch(output: string, count: int, idx: int): string {
        if (!Shell.dev)
            return "dev only";
        let list = Niri.workspaces.filter(w => w.output !== output);
        for (let i = 1; i <= count; i++)
            list.push({"id": 9000 + i, "idx": i, "name": null, "output": output, "is_active": i === idx, "is_focused": false, "is_urgent": false, "active_window_id": null});
        Niri._setWorkspaces(list);
        Niri.workspaceActivated(Niri.workspaces.find(w => w.id === 9000 + idx), false);
        return "ok";
    }
    // stream mode: on | off | auto (follow OBS) | toggle | status
    function stream(mode: string): string {
        if (["on", "off", "auto", "toggle"].includes(mode))
            StreamMode.set(mode);
        else if (mode !== "status" && mode !== "")
            return "on | off | auto | toggle | status";
        return JSON.stringify({
            "active": StreamMode.active,
            "manual": Config.stream.manual,
            "auto": Config.stream.auto,
            "obs": StreamMode.obsUp ? (StreamMode.obsLive ? "live" : "up") : (StreamMode.obsAuth ? "password" : "down")
        });
    }
    // privacy on stream (services/Privacy): on | off | toggle — the mode; app — the focused
    // window's app into its list or out of it; status. The `angelos privacy …` of the CLI goes
    // to the tool itself (~/.local/bin/niri-cast-privacy), which needs no shell
    function privacy(cmd: string): string {
        if (["on", "off", "toggle"].includes(cmd))
            Privacy.set(cmd);
        else if (cmd === "app")
            Privacy.app("toggle", "");
        else if (cmd === "show")
            Privacy.show("toggle", "");
        else if (cmd !== "status" && cmd !== "")
            return "on | off | toggle | app | show | status";
        return JSON.stringify({
            "on": Privacy.on,
            "shown": Privacy.shown,
            "auto": Config.stream.privacyAuto,
            "apps": Privacy.apps
        });
    }
    // the pause for viewers (services/Privacy.pause): on | off | toggle | status
    function castPause(mode: string): string {
        if (!Privacy.nativeLook)
            return "needs angel-niri";
        if (["on", "off", "toggle"].includes(mode))
            Privacy.pause(mode);
        else if (mode !== "status" && mode !== "")
            return "on | off | toggle | status";
        return Privacy.paused ? "paused" : "live";
    }
    // Desktop or the Strip (angel-niri's stacking mode, Settings → Windows, services/WindowConfig): on | off | toggle | status
    function stacking(mode: string): string {
        if (!Niri.nativeMinimize)
            return "needs angel-niri";
        if (["on", "off", "toggle"].includes(mode))
            WindowConfig.setFloatAll(mode === "toggle" ? !WindowConfig.floatAll : mode === "on");
        else if (mode !== "status" && mode !== "")
            return "on | off | toggle | status";
        return WindowConfig.floatAll ? "on" : "off";
    }
    // stay awake (services/Awake): on | off | toggle | status — by hand; stream mode and
    // full-screen windows switch it by themselves (Settings → Lock → Stay awake)
    function awake(mode: string): string {
        if (["on", "off", "toggle"].includes(mode))
            Awake.set(mode);
        else if (mode !== "status" && mode !== "")
            return "on | off | toggle | status";
        return JSON.stringify({
            "active": Awake.active,
            "manual": Awake.manual,
            "reason": Awake.reason,
            "fullscreen": Awake.fullscreenWindow ? Awake.fullscreenWindow.app_id || "" : ""
        });
    }
    // the angel on stream (services/StreamAngel): on | off | toggle | drop (her menu's
    // "stop being a streamer": off, and her menu offers it back) | test (show her now,
    // without a stream; again hides her) | view (Mod+Alt+A: on the bar ⇄ hidden) |
    // screen | obs (on your screen too, or only in her window for OBS) | status
    function streamer(mode: string): string {
        if (["on", "off", "toggle", "drop", "test", "view", "screen", "obs"].includes(mode))
            StreamAngel.set(mode);
        else if (mode !== "status" && mode !== "")
            return "on | off | toggle | drop | test | view | screen | obs | status";
        return JSON.stringify({
            "enabled": StreamAngel.enabled,
            "shown": StreamAngel.shown,
            "preview": StreamAngel.preview,
            "obs": StreamAngel.obsUp ? (StreamAngel.obsLive ? "live" : "up") : "down",
            "mic": StreamAngel.using,
            "level": StreamAngel.level,
            "talking": StreamAngel.talking,
            "view": StreamAngel.view,
            "cast": StreamAngel.castOpen ? (Niri.castWindowId >= 0 ? "window " + Niri.castWindowId : "opening") : "closed",
            "error": StreamAngel.error
        });
    }
    // the game (services/Story): `angelos game off` — out of the game at once (also
    // Mod+Ctrl+Shift+Escape), on, calm on|off (no flashes, shaking or sudden loud sounds),
    // status, reset (the save starts over); developer mode (Settings → System) or the dev
    // stand: circle <1–9|id>, scene <id>, sin <name> [+1|-1|N], outcome stars|pact|limbo, try
    function game(line: string): string {
        const a = String(line || "").trim().split(/\s+/);
        switch (a[0]) {
        case "off":
            return Story.setEnabled(false);
        case "on":
            return Story.setEnabled(true);
        case "calm":
            // older: the calm mode is Motion "calm" now (Settings → Appearance → Motion)
            Motion.set(a[1] === "off" ? "full" : "calm");
            return "calm " + (Motion.calm ? "on" : "off") + " (motion " + Motion.level + ")";
        case "reset":
            return Story.reset();
        case "":
        case "status":
            return Story.status();
        }
        if (!Shell.dev && !Config.developer.enabled)
            return "off | on | calm on|off | status | reset" + " (circle, scene, sin, outcome, try: developer mode — Settings → System → For developers)";
        switch (a[0]) {
        case "circle":
            return Story.jump(a[1] || "");
        case "scene":
            return Novel.startScene(a[1] || "") ? "ok" : "scenes: " + Object.keys(Novel.scenes).sort().join(" ");
        case "sin":
            {
                const set = {};
                // "N" sets it, "+N" / "-N" moves it (a plain number stays a number in the save)
                set[a[1] || "limbo"] = /^\d+(\.\d+)?$/.test(a[2] || "") ? Number(a[2]) : a[2] || "+1";
                Story.applySet(set);
                return JSON.stringify(Story.vars);
            }
        case "outcome":
            return Story.inHell ? (Story.outcome(a[1] || "stars") ? "ok" : "no") : "not in hell";
        case "try":
            return Story.attempt(true);
        case "ambient":
            if (!Story.inHell)
                return "not in hell";
            HellAmbient.now();
            return "ok";
        }
        return "off | on | calm on|off | status | reset | circle <1–9|id> | scene <id> | sin <name> [+1] | outcome stars|pact|limbo | try | ambient";
    }
    // the achievements (services/Achievements): `angelos ach` status | list | events | check |
    // validate; the owner or developer mode: grant <id|all> | revoke <id|all> | toast <id>
    function ach(line: string): string {
        const a = String(line || "").trim().split(/\s+/);
        switch (a[0]) {
        case "":
        case "status":
            return Achievements.status();
        case "list":
            return Achievements.listText();
        case "events":
            return Achievements.eventIds.map(e => e + " — " + Achievements.eventLabel(e)).join("\n") + "\n\ncond: " + Achievements.condVars.join(" ") + " + the game's (docs/STORY.md), count(\"event\") kinds(\"event\") got(\"id\")";
        case "check":
            return Story.enabled ? "earned now: " + Achievements.check() : "the game is off: no achievements";
        case "streak":
            return a[1] ? a[1] + ": " + Achievements.streak(a[1], Number(a[2]) || 10) + " in a row (≤" + (Number(a[2]) || 10) + " s apart)" : "streak <event> [seconds]";
        case "validate":
            {
                const bad = Achievements.problems(Achievements.doc);
                return Achievements.loadError ? "story/achievements.json: " + Achievements.loadError : bad.length ? bad.join("\n") : "ok (" + Achievements.own.length + ")";
            }
        }
        if (!Owner.enabled && !Shell.dev && !Config.developer.enabled)
            return "status | list | events | check | validate | streak (grant, revoke, toast, note, reset: the owner or developer mode)";
        if (!Story.enabled && a[0] !== "revoke")
            return "the game is off: no achievements";
        const ids = a[1] === "all" ? Achievements.list.map(x => x.id) : [a[1] || ""];
        switch (a[0]) {
        case "grant":
            return ids.filter(id => Achievements.grant(id, a[1] === "all")).length + " granted";
        case "revoke":
            return ids.filter(id => Achievements.revoke(id)).length + " revoked";
        case "toast":
            {
                const x = Achievements.find(a[1] || "") || Achievements.list[0];
                if (!x)
                    return "no achievements";
                // `toast <id> hell` | `heaven`: that card's look whatever the realm
                Achievements.announce(x, a[2] === "hell" ? true : a[2] === "heaven" ? false : null);
                return "ok";
            }
        case "note":
            // an event as if it happened: note <event> [key|-] [times]
            return Achievements.simulate(a[1] || "", a[2] && a[2] !== "-" ? a[2] : "", Number(a[3]) || 1) ? "noted " + a[1] + " → earned now: " + Achievements.check() : "note <event> [key|-] [times] (the game must be on)";
        case "reset":
            // reset: everything earned, counted and read in the diary; reset counts: only the counters
            return a[1] === "counts" ? (Achievements.resetCounts() ? "counters reset" : "no save") : Achievements.resetAll() ? "achievements, counters and the diary's marks reset" : "no save";
        }
        return "status | list | events | check | validate | streak <event> [s] | grant <id|all> | revoke <id|all> | toast <id> [hell|heaven] | note <event> [key|-] [n] | reset [counts]";
    }
    // the Angel's diary (services/Diary): `angelos diary` open [page] | close | list | validate |
    // read-reset | preview on|off (the owner or developer mode: every page written)
    function diary(line: string): string {
        const a = String(line || "").trim().split(/\s+/);
        switch (a[0]) {
        case "":
        case "open":
            return Diary.open(a[1] || "") ? "ok" : "the diary is locked: its key is not had (" + Diary.thingId + ")";
        case "close":
            Diary.close();
            return "ok";
        case "list":
            return Diary.listText();
        case "watch-status":
        case "status":
            return "trust " + Diary.trust + " / " + Diary.trustStart + ", caught " + Diary.caughtTimes + (Diary.hidden ? ", hidden" : "") + (Angel.away ? ", she is away" : Diary.watching ? ", she is watching" : "");
        case "watch":
            return JSON.stringify({
                "watching": Diary.watching,
                "away": Angel.away,
                "backIn": Angel.away ? Math.round((Angel.awayUntil - Date.now()) / 1000) + " s" : "",
                "nextWalk": Diary.walks ? "planned" : "no walks (" + (Diary.owned ? "hell, limbo or the game off" : "no key") + ")",
                "trust": Diary.trust + " / " + Diary.trustStart,
                "caught": Diary.caughtTimes,
                "hidden": Diary.hidden
            }, null, 1);
        case "validate":
            {
                const bad = Diary.problems(Diary.doc);
                return Diary.loadError ? "story/diary.json: " + Diary.loadError : bad.length ? bad.join("\n") : "ok (" + Diary.pages.length + " pages)";
            }
        }
        if (!Owner.enabled && !Shell.dev && !Config.developer.enabled)
            return "open [page] | close | list | validate | watch (read-reset, preview, away, back, trust: the owner or developer mode)";
        switch (a[0]) {
        case "read-reset":
            Diary.resetRead();
            return "the diary's read marks reset";
        case "preview":
            Diary.preview = a[1] !== "off";
            return "preview " + (Diary.preview ? "on: every page written" : "off");
        case "away":
            // she goes now for N minutes (default: one of the rules')
            return Diary.leave(Number(a[1]) || Diary.awayMinutes()) ? "she is leaving" : "she can't leave now (the demon, the game off, already away)";
        case "back":
            Angel.awayUntil = 0;
            return "she is back";
        case "trust":
            if (a[1] === "reset") {
                Diary.resetTrust();
                return "trust " + Diary.trust + ", not caught, the diary not hidden";
            }
            return "trust " + Diary.trust + " / " + Diary.trustStart + ", caught " + Diary.caughtTimes + (Diary.hidden ? ", hidden in Settings" : "");
        }
        return "open [page] | close | list | validate | watch | read-reset | preview on|off | away [min] | back | trust [reset]";
    }
    // the game's debug panel: the author's only (services/GameDebug → owner/debug/GameDebugCore,
    // which knows the commands); anyone else gets "owner only"
    function debug(line: string): string {
        return GameDebug.command(line);
    }
    // the live wallpaper's scene editor, a window of the shell: the author's only
    // (services/SceneEditor → modules/sceneeditor). `angelos scene edit [picture] | close | status`
    function scene(line: string): string {
        return SceneEditor.command(line);
    }
    // the corner helper: `angelos helper "tip | joke | hint | ask <text> | plea | talk | gift | stay | status"`
    // (owner: angel — the demon leaves at once; dev or owner: prank, ascend, fx,
    // hell, throw; dev only: drag)
    // the novel (services/Novel, ~/AngelOs-Nov): start [chapter] | reset | reload | status |
    // question | drop | resume | click | next | choose N | open | fold | edit
    function novel(line: string): string {
        const a = String(line || "").trim().split(/\s+/);
        switch (a[0]) {
        case "start":
            return Novel.startChapter(a[1] || Object.keys(Novel.stories).sort()[0] || "");
        case "reset":
            return Novel.reset();
        case "reload":
            Novel.reload();
            return "ok";
        case "question":
            Novel.forceQuestion();
            return "ok";
        case "drop":
            Novel.forceDrop();
            return "ok";
        case "resume":
            Novel.resumed();
            return "ok";
        case "click":
            return Novel.click() ? "ok" : "nothing waits for a click";
        case "next":
            Novel.advance();
            return "ok";
        case "choose":
            Novel.choose((parseInt(a[1]) || 1) - 1);
            return "ok";
        case "edit":
            Novel.edit();
            return "ok";
        case "open":
            // unfold the paper on the desk (what a click on it does)
            if (!Novel.paper)
                return "no paper";
            Novel.noteOpen = true;
            return "ok";
        case "fold":
            Novel.noteRead();
            return "ok";
        }
        return Novel.status();
    }
    function helper(line: string): string {
        const cmd = String(line).trim().split(/\s+/)[0];
        const arg = String(line).trim().slice(cmd.length).trim();
        const debug = Shell.dev || Owner.enabled;
        if (cmd === "angel")
            return Angel.ownerAngel() ? "ok" : !Owner.enabled ? "owner only" : Angel.demon ? "not now" : "she is an angel already";
        if (cmd === "summon")
            return Angel.summon();
        // heaven ↔ hell at once, once the angel has come back three times (or for the owner)
        if (cmd === "portal")
            return Angel.portal() ? "ok" : Angel.transition ? "busy" : "closed: " + Angel.returns + "/" + Angel.returnsNeeded + " returns";
        if (cmd === "tip")
            Angel.tip();
        else if (cmd === "joke")
            Angel.joke();
        else if (cmd === "hint")
            Angel.hint();
        else if (cmd === "ask")
            Angel.answer(arg);
        else if (cmd === "plea")
            Angel.plea();
        // the demon of a circle: a word, a gift her sin loves, staying (Story → closeness)
        else if (cmd === "talk" || cmd === "gift" || cmd === "stay")
            Angel.demonDo(cmd);
        else if (cmd === "menu")
            Angel.openMenu(arg || "main");
        else if (debug && cmd === "prank")
            return Angel.prank() ? "ok" : "not now";
        else if (debug && cmd === "ascend")
            Angel.getOut("stars");
        // the angel goes to hell only by being thrown down (AngelHelper); dev: pretend
        else if (debug && cmd === "hell")
            Angel.toHell();
        else if (debug && cmd === "throw")
            Angel.released(true, -40, 30);
        // dev: a real drag on her by dx, dy pixels over ms (TestEvent): "drag 0 90 300"
        else if (Shell.dev && cmd === "drag") {
            const a = arg.split(/\s+/).map(Number);
            Angel.devDrag(a[0] || 0, a[1] || 0, a[2] || 300);
        }
        // dev: the pointer swung to and fro over her head N times, no button (TestEvent): "pet 8"
        else if (Shell.dev && cmd === "pet")
            Angel.devPet(Number(arg) || 6);
        else if (debug && cmd === "fx")
            Angel.effect();
        else if (debug && cmd === "hellwall")
            return Angel.newHell() ? "ok" : "not now (angel, off, or your own picture)";
        // the widgets burn over to the other side and back: "realm [hell|heaven]"
        else if (debug && cmd === "realm")
            return "burning to " + DesktopWidgets.burnPreview(arg);
        else if (cmd !== "status")
            return "summon | portal | tip | joke | hint | ask <text> | plea | talk | gift | stay | menu [main|ask] | status" + (Owner.enabled ? " | angel" : "");
        return JSON.stringify({
            "character": Story.player.character,
            "shown": Angel.shown,
            "screen": Angel.screenName,
            "transition": Angel.transition,
            "realm": Theme.realm + (DesktopWidgets.burning ? " → " + DesktopWidgets.burnTo : ""),
            "cursor": Cursors.active,
            "circle": Story.circle,
            "returns": Angel.returns + "/" + Angel.returnsNeeded + (Angel.portalOpen ? " (portal open)" : ""),
            "pranks": (Story.player.pranks || []).map(p => p.id + (p.undone ? " (undone)" : "")),
            "text": Angel.talking ? Angel.text : ""
        });
    }
    // dev only: run a shell command the way the shell starts apps (Shell.sh)
    function devExec(cmd: string): string {
        if (!Shell.dev)
            return "dev only";
        Shell.sh(cmd);
        return Shell.scopes ? "ok (own scope)" : "ok";
    }
    // the heart animation on every bar, without switching workspaces (0-based cells)
    function heartDemo(from: int, to: int): void {
        Shell.heartDemo(from, to);
    }
    function heartAnim(style: string): string {
        const all = ["smart", "collide", "ender", "hop", "worm", "pixel", "beat", "sparkle", "drop", "glitch", "slide", "off"];
        if (!all.includes(style))
            return "styles: " + all.join(", ");
        Config.workspaces.heartAnim = style;
        return "ok";
    }
    // classic | win11 | fullscreen | xmb | spotlight
    function startStyle(style: string): string {
        const styles = StartPrefs.styles;
        if (!styles.includes(style))
            return "styles: " + styles.join(", ");
        Config.bar.startStyle = style;
        return "ok";
    }
    function launcher(): void {
        if (Shell.setupLocked)
            return;
        Shell.launcherOpen = !Shell.launcherOpen;
    }
    function launcherWith(text: string): void {
        if (Shell.setupLocked)
            return;
        Shell.launcherPrefill = text;
        Shell.launcherOpen = true;
    }
    function session(): void {
        if (Shell.setupLocked)
            return;
        Shell.sessionOpen = !Shell.sessionOpen;
    }
    function clipboard(): void {
        if (Shell.setupLocked)
            return;
        Shell.clipboardOpen = !Shell.clipboardOpen;
    }
    // the eyedropper: a click anywhere, the colour's hex into the clipboard (services/ColorPicker)
    function pickColor(): void {
        ColorPicker.pick();
    }
    // instant replay (Mod+Alt+G): the last seconds onto the Halo's shelf
    function clip(): void {
        Capture.clip();
    }
    // the day's timelapse: on | off | build (today so far)
    function timelapse(mode: string): void {
        Timelapse.set(mode);
    }
    // the screenshot (Mod+Shift+S, Print): the frozen screen to pick, read, search, save —
    // the focused screen, or a named one; circle/circleOn are its old names
    function capture(): void {
        captureOn("");
    }
    function captureOn(screen: string): void {
        if (Shell.setupLocked)
            return;
        // Settings → Screenshots → «Classic region selection»: the old selector (services/Capture)
        // the key again while the overlay is up closes it (as Circle's did)
        if (Config.capture.classic)
            Capture.screenshot(screen);
        else
            CircleHost.toggle(screen);
    }
    // niri-record-region started or stopped a recording: read its state again (services/Capture)
    function recChanged(): void {
        Capture.recCheck();
    }
    // …and saved this file (glued, if it was paused): onto the Halo's shelf
    function recSaved(path: string): void {
        Capture.saved(path);
    }
    function circle(): void {
        captureOn("");
    }
    // Quick Share (LocalSend devices nearby): files one per line, or a text
    function share(paths: string): void {
        if (Shell.setupLocked)
            return;
        QuickShare.share(paths.split("\n").filter(p => p !== ""), "");
    }
    function shareText(text: string): void {
        if (Shell.setupLocked)
            return;
        QuickShare.share([], text);
    }
    // the screenshot editor on a picture ("" : the newest shot), its recent shots along the bottom
    function shotEdit(path: string): void {
        if (Shell.setupLocked)
            return;
        ShotEdit.edit(path);
    }
    // Quick Look: a look at a file without opening it (Space in Nautilus calls it by itself)
    function quicklook(path: string): void {
        if (Shell.setupLocked)
            return;
        QuickLook.show(path, false);
    }
    // the mini island: a page in a small window of its own; clicks through it on and off
    function island(url: string): void {
        if (Shell.setupLocked)
            return;
        Island.open(url);
    }
    // one video link through yt-dlp into ~/Downloads, the Halo's capsule shows it (services/VideoGrab)
    function grab(url: string): void {
        if (Shell.setupLocked)
            return;
        VideoGrab.grab(url, false);
    }
    // the same, the sound alone (m4a)
    function grabAudio(url: string): void {
        if (Shell.setupLocked)
            return;
        VideoGrab.grab(url, true);
    }
    // the conversion ring over these files (one path a line; services/Convert)
    function convert(paths: string): void {
        if (Shell.setupLocked)
            return;
        Convert.show(paths.split("\n").filter(p => p !== ""));
    }
    // a video squeezed under Discord's limit (Settings → Screenshots and recording), on the shelf
    function discord(path: string): void {
        if (Shell.setupLocked)
            return;
        VideoGrab.shrink(path, 0, 0);
    }
    // a picture to Google Lens, the results in angelOS's window (services/LensSearch)
    function lensSearch(path: string): void {
        if (Shell.setupLocked)
            return;
        LensSearch.search(path);
    }
    function islandThrough(): void {
        Island.setThrough(!Island.through);
    }
    // «Обслуживание»: the page, and a fresh look at the computer
    function care(): void {
        if (Shell.setupLocked)
            return;
        Care.open();
    }
    function circleOn(screen: string): void {
        captureOn(screen);
    }
    // toggle a desktop widget: angelos widget clock DP-1 (types: clock sysmon music picture note disks plugin:<id>)
    function widget(type: string, screen: string): string {
        if (!DesktopWidgets.typeInfo(type))
            return "unknown widget: " + type + " (" + DesktopWidgets.types.map(t => t.type).join(", ") + ")";
        DesktopWidgets.toggle(type, screen || Shell.primaryName);
        return "ok";
    }
    function widgetEdit(): void {
        DesktopWidgets.editMode = !DesktopWidgets.editMode;
    }
    // a desktop widget as it is seen (its face in the backdrop), saved to a file
    function widgetShot(uid: string, path: string): string {
        const f = DesktopWidgets.faces[uid];
        if (!f)
            return "no widget " + uid + "; have: " + Object.keys(DesktopWidgets.faces).join(", ");
        return f.grabToImage(r => r.saveToFile(path)) ? "ok (saving " + path + ")" : "grab failed";
    }
    // the open Settings as they are drawn (also under other windows), saved to a file
    function settingsShot(path: string): string {
        const v = Shell.settingsView;
        if (!v)
            return "Settings are closed";
        const f = v.Window.window ? v.Window.window.activeFocusItem : null;
        return (v.grabToImage(r => r.saveToFile(path)) ? "ok (saving " + path + ")" : "grab failed") + "; focus: " + (f ? (f.objectName || String(f)) + (f.parent ? " in " + (f.parent.objectName || String(f.parent)) : "") : "none");
    }
    // what the open settings page shows, row by row (label · control · value), for comparing
    // two builds of a page; "more" first opens its «Ещё…»
    function settingsDump(arg: string): string {
        const v = Shell.settingsView;
        if (!v)
            return "Settings are closed";
        if (arg === "more") {
            SettingsTree.setMoreOpen(v.settingsNav.settingsPage, true);
            return "ok";
        }
        const out = [];
        const kind = it => String(it).replace(/_QML.*|\(.*/, "");
        const showing = it => {
            for (let p = it; p && p !== v; p = p.parent)
                if (!p.visible || p.opacity === 0)
                    return false;
            return true;
        };
        const walk = (it, depth) => {
            if (!it || depth > 60)
                return;
            const k = kind(it);
            if (showing(it)) {
                if (k === "PxGroup" && it.title)
                    out.push("## " + it.title);
                else if (it.rowHeight !== undefined && it.labelWidth !== undefined)
                    out.push("- " + it.label + (it.hint ? " (" + it.hint + ")" : ""));
                else if (k === "PxToggle" || k === "PxCheck")
                    out.push("    " + k + " " + it.checked + (it.text ? " " + it.text : ""));
                else if (k === "PxSegmented" || k === "PxCombo")
                    out.push("    " + k + " " + JSON.stringify(it.currentValue) + " " + JSON.stringify((it.model || []).map(m => typeof m === "object" ? m.value : m)));
                else if (k === "PxSlider" || k === "PxSpin")
                    out.push("    " + k + " " + it.value + " [" + it.from + ".." + it.to + "]");
                else if (k === "PxField")
                    out.push("    PxField " + JSON.stringify(it.text));
                else if (k === "PxButton")
                    out.push("    PxButton " + (it.text || it.icon) + (it.enabled ? "" : " (off)"));
                else if ((k === "PxText" || k === "Note") && it.text)
                    out.push("    “" + String(it.text).slice(0, 80) + "”");
            }
            for (const c of it.children)
                walk(c, depth + 1);
        };
        walk(v, 0);
        return out.join("\n");
    }
    // a desktop widget's two copies (DesktopWidgetHost face/input), for diagnostics
    function widgetState(uid: string): string {
        const h = DesktopWidgets.hosts[uid], f = DesktopWidgets.faces[uid];
        if (!h && !f)
            return "no widget " + uid + "; have: " + Object.keys(DesktopWidgets.hosts).join(", ");
        const scr = h ? h.screenName : f.screenName;
        return JSON.stringify({
            "screen": scr,
            "interactive": h ? h.interactive : null,
            "hovered": h ? h.engaged && !h.dragging && !DesktopWidgets.editMode : null,
            "dragging": h ? h.dragging : null,
            "inputShown": h ? h.shown : null,
            "inputOpacity": h ? h.opacity : null,
            "faceOpacity": f ? f.opacity : null,
            "steppedAside": DesktopWidgets.steppedAside(scr),
            "overview": Niri.overviewOpen,
            "asideLeftMs": Math.max(0, (DesktopWidgets.asideUntil[scr] || 0) - Date.now()),
            "at": h ? [Math.round(h.x), Math.round(h.y)] : null
        });
    }
    // dev: where the shell last saw the pointer (Pointer: desk and taskbar report it)
    function pointer(): string {
        return JSON.stringify({
            "screen": Pointer.screen,
            "x": Math.round(Pointer.x),
            "y": Math.round(Pointer.y),
            "over": Pointer.over,
            "source": Pointer.source
        });
    }
    // dev: drags a desktop widget by its title bar by dx, dy over ms
    function widgetDrag(uid: string, dx: int, dy: int, ms: int): string {
        if (!Shell.dev)
            return "dev only";
        const h = DesktopWidgets.hosts[uid];
        if (!h)
            return "no widget " + uid;
        h.devDrag(dx, dy, ms || 600);
        return "ok";
    }
    // replays a left click at (x, y) of a desktop widget
    function widgetClick(uid: string, x: int, y: int): string {
        const h = DesktopWidgets.hosts[uid];
        if (!h)
            return "no widget";
        if (!h.takes(x, y, Qt.LeftButton))
            return "nothing clickable there";
        h.press(x, y, Qt.LeftButton);
        h.release(x, y, Qt.LeftButton);
        return "ok";
    }
    // what a pointer at (x, y) of a desktop widget would hit: {title, cursor, target}
    function widgetProbe(uid: string, x: int, y: int): string {
        const h = DesktopWidgets.hosts[uid];
        if (!h)
            return "no widget " + uid + "; have: " + Object.keys(DesktopWidgets.hosts).join(", ");
        const t = h.targetAt(x, y, "clicked");
        return JSON.stringify({
            "title": h.isTitleDrag(x, y),
            "cursor": h.cursorAt(x, y),
            "target": t ? String(t.item) : null,
            "size": [h.width, h.height]
        });
    }
    // the configured system monitor, floating (Settings → System → Task Manager)
    function taskManager(): void {
        if (Shell.setupLocked)
            return;
        DesktopActions.launchMonitor();
    }
    // heaven's chest: the day's free one, else one for 160 ✦ ("ten": ten for 1600 ✦)
    function chest(n: string): string {
        if (Shell.setupLocked)
            return "the setup wizard is open";
        const ok = n === "demo" ? Chests.demo(1) : n === "demo10" ? Chests.demo(10) : n === "ten" ? Chests.openTen() : Chests.openOne();
        return ok ? "opened" : "no chest: " + HeavenStars.stars + " ✦";
    }
    // Wellbeing (services/Wellbeing): `angelos wellbeing` (status) | water | unwater |
    // test eyes|move|water|limit (the reminder now) | clear (the history gone)
    function wellbeing(cmd: string): string {
        const [c, arg] = String(cmd || "").trim().split(/\s+/);
        if (c === "water") {
            Wellbeing.drink();
            return "water " + Wellbeing.waterToday + "/" + Config.wellbeing.waterGoal;
        }
        if (c === "unwater") {
            Wellbeing.undrink();
            return "water " + Wellbeing.waterToday + "/" + Config.wellbeing.waterGoal;
        }
        if (c === "test") {
            const k = ["eyes", "move", "water", "limit"].includes(arg) ? arg : "water";
            Wellbeing.remind(k, true);
            return "reminded: " + k;
        }
        if (c === "clear") {
            Wellbeing.clear();
            return "history cleared";
        }
        return Wellbeing.status();
    }
    function settingsPage(page: string): void {
        if (Shell.setupLocked)
            return;
        Shell.openSettings(page);
    }
    // one more Settings window: `angelos settingsNew sound` (no page: the main window's page)
    function settingsNew(page: string): string {
        if (Shell.setupLocked)
            return "the setup wizard holds the desktop (angelos setup skip)";
        if (!Shell.newSettingsWindow(page || Shell.settingsPage))
            return "no more than " + Shell.settingsMoreMax + " more windows";
        return "windows: " + (Shell.settingsMore.count + (Shell.settingsOpen ? 1 : 0));
    }
    // what's new in Settings (services/SettingsNews): `angelos settingsNews` (what is starred) |
    // seen (all of it read) | forget <file/group[/Russian label]> (starred again)
    function settingsNews(cmd: string): string {
        const c = String(cmd || "").trim();
        if (c === "seen") {
            SettingsNews.seeAll();
            return "all seen";
        }
        if (c.startsWith("forget ")) {
            SettingsNews.forget(c.slice(7).trim());
            return "forgot " + c.slice(7).trim();
        }
        const n = SettingsNews.news;
        return JSON.stringify({
            "count": n.count,
            "pages": Object.keys(n.pages),
            "underMore": Object.keys(n.more)
        });
    }
    // how Settings lay the pages out: Windows 11, or System Settings under Golden Gate (no choice)
    function settingsView(view: string): string {
        return GoldenGate.on ? "mac" : "win11";
    }
    // what Settings wear: `angelos settingsSkin windose` (no argument: which one)
    function settingsSkin(skin: string): string {
        const skins = ["classic", "windose", "stream", "goldengate"];
        const s = String(skin || "").trim().toLowerCase();
        if (s === "")
            return Config.settingsUi.skin + "  (" + skins.join(" | ") + ")";
        if (!skins.includes(s))
            return "unknown skin " + s + ": " + skins.join(" | ");
        Config.settingsUi.skin = s;
        Config.settingsUi.skinChosen = true;
        return "ok";
    }
    // the Golden Gate menu bar from the keyboard (macOS: Control-F2): the menu `index` of the
    // focused screen's bar opens with its first item selected (0 = angelOS's, 1 = the app's,
    // -1: the app's); ←/→, ↑/↓, Enter and Esc from there
    function macMenu(index: int): string {
        if (Shell.setupLocked || !GoldenGate.on)
            return "the Golden Gate skin is off";
        const scr = Shell.focusedScreen ? Shell.focusedScreen.name : "";
        const i = index < 0 ? 1 : index;
        const xs = MacMenus.titleX[scr] || [];
        MacMenus.open(scr, i, xs[i] || 0, true);
        return MacMenus.isOpen ? "ok" : "no menu " + i;
    }
    // ⌘Q of the Golden Gate skin's Mac shortcuts: the frontmost app quits — its own Quit when it
    // has one (by D-Bus), else every window of it closes through niri (the app may still ask)
    function macQuit(): string {
        if (Shell.setupLocked || !GoldenGate.on)
            return "the Golden Gate skin is off";
        // ⌘Q while ⌘Tab is up (⌘ still held): the app picked there quits, the switcher stays
        const picked = AltTab.pickedApp;
        if (picked) {
            for (const w of picked.windows)
                Niri.closeWindow(w.id);
            const rest = AltTab.items.filter(a => a !== picked);
            if (!rest.length)
                AltTab.cancel();
            else {
                AltTab.items = rest;
                AltTab.index = Math.min(AltTab.index, rest.length - 1);
            }
            return "ok";
        }
        if (!AppMenu.window)
            return "nothing to quit";
        const app = AppMenu.menus.length ? AppMenu.menus[0].items.find(it => /^(app|s):quit$/.test(it.id)) : null;
        AppMenu.trigger(app || AppMenu.item("app:quit", "", {
            "kind": "quit"
        }));
        return "ok";
    }
    // ⌘M of the Golden Gate skin's Mac shortcuts: the frontmost window goes to the Dock
    // (services/Minimize); with a window id: that one. "restore <id>" brings one back.
    // the focused window minimized (the pixel keys' Mod+Z); back from the taskbar or Alt+Tab
    function minimize(): string {
        const w = Niri.focusedWindow;
        if (Shell.setupLocked || !w)
            return "nothing to minimize";
        Minimize.request(w.id, "keys");
        return "ok";
    }
    // Mod+D: show the desktop of the focused screen, again to bring the windows back
    function showDesktop(): string {
        if (Shell.setupLocked)
            return "locked";
        DeskMenu.showDesktop(Niri.focusedOutput);
        return "ok";
    }
    function macMinimize(): string {
        if (!GoldenGate.on || !AppMenu.window)
            return "nothing to minimize";
        Minimize.request(AppMenu.window.id, "keys");
        return "ok";
    }
    // ⌘H of the Golden Gate skin's Mac keys: the frontmost app hides (all its windows go,
    // services/Minimize.hide; its Dock icon or ⌘Tab brings them back) — while ⌘Tab is up, the
    // app picked there
    function macHide(): string {
        if (Shell.setupLocked || !GoldenGate.on)
            return "the Golden Gate skin is off";
        const picked = AltTab.pickedApp;
        const w = picked ? picked.windows.find(x => !Minimize.isMinimized(x)) : AppMenu.window;
        if (!w)
            return "nothing to hide";
        Minimize.hide(w.id);
        if (picked)
            AltTab.cancel();
        return "ok";
    }
    // ⇧⌘5: the screenshot menu on the focused screen, above the Dock (MacMenus.openShot)
    function macShotMenu(): string {
        const scr = Shell.focusedScreen;
        if (Shell.setupLocked || !GoldenGate.on || !scr)
            return "the Golden Gate skin is off";
        MacMenus.openShot(scr.name, scr.width / 2, scr.height - (GoldenGate.dockEdge === "bottom" ? Minimize.dockZone[scr.name] || 0 : 0) - GoldenGate.px(12));
        return MacMenus.isOpen ? "ok" : "no menu";
    }
    function macHidden(): string {
        return JSON.stringify(Minimize.hiddenWindows.map(w => ({
                    "id": w.id,
                    "app_id": w.app_id,
                    "title": w.title
                })));
    }
    function macMinimized(): string {
        return JSON.stringify(Minimize.windows.map(w => ({
                    "id": w.id,
                    "app_id": w.app_id,
                    "title": w.title,
                    "shot": Minimize.shots[w.id] || ""
                })));
    }
    function macRestore(id: string): string {
        Minimize.restore(parseInt(id));
        return "ok";
    }
    // Settings → Appearance → "Reset the theme's settings to the defaults" (GoldenGate.themeKeys);
    // "Undo" in Settings brings them back. Returns how many changed
    function macResetTheme(): string {
        Config.flush();
        return String(GoldenGate.resetTheme());
    }
    // a left click on the Dock's app `id` (its entry id or app id) on the focused screen, as the
    // Dock's own click does it (tests)
    function macDockOpen(id: string): string {
        if (!GoldenGate.on)
            return "the Golden Gate skin is off";
        const it = MacDockModel.apps.find(a => a.id === id);
        if (!it)
            return "no app " + id;
        MacDockModel.open(it, Niri.focusedOutput);
        return it.name;
    }
    // what the menu bar shows now, as JSON (the report's table, tests): the app, where its menus
    // come from, the titles and their items
    function macMenuState(): string {
        return JSON.stringify({
            "app": AppMenu.appId,
            "name": AppMenu.appName,
            "source": AppMenu.source,
            "ambiguous": !!AppMenu.report.ambiguous,
            "registrar": AppMenu.registrar,
            "pid": AppMenu.pid,
            "reported": [AppMenu.report.pid, AppMenu.report.source],
            "menus": AppMenu.menus.map(m => ({
                        "title": m.title,
                        "items": m.items.map(it => it.type === "separator" ? "—" : (it.label || "") + (it.type === "submenu" ? " ›" : "") + (it.enabled === false ? " (off)" : "") + (it.act ? " [" + it.act.kind + "]" : ""))
                    }))
        });
    }
    // Control Center (cc) or Notification Center (nc) on the focused screen, open or closed
    function macPanel(kind: string): string {
        if (!GoldenGate.on)
            return "the Golden Gate skin is off";
        const scr = Shell.focusedScreen;
        GoldenGate.togglePanel(kind, scr ? scr.name : "");
        return GoldenGate.panel === kind ? "open" : "closed";
    }
    // the Dock menu of its item `index` (0 = the first app), as a right click would open it
    function macDockMenu(index: int): string {
        if (!GoldenGate.on)
            return "the Golden Gate skin is off";
        const it = MacDockModel.apps[index];
        const scr = Shell.focusedScreen;
        if (!it || !scr)
            return "no item " + index;
        MacMenus.openDock(scr.name, it, scr.width / 2, scr.height - GoldenGate.px(Config.mac.dockSize) - GoldenGate.px(30));
        return it.name;
    }
    // the desktop's menu (a right click on the wallpaper) in the middle of the focused screen
    function macDeskMenu(): string {
        const scr = Shell.focusedScreen;
        if (!GoldenGate.on || !scr)
            return "the Golden Gate skin is off";
        MacMenus.openDesktop(scr.name, scr.width / 2, scr.height / 3);
        return MacMenus.menu ? MacMenus.menu.items.filter(it => it.label).map(it => it.label).join(", ") : "no menu";
    }
    // a status item's menu on the focused screen: wifi | bluetooth | sound | input
    function macStatus(kind: string): string {
        if (!GoldenGate.on)
            return "the Golden Gate skin is off";
        const scr = Shell.focusedScreen;
        MacMenus.openStatus(scr ? scr.name : "", kind, scr ? scr.width - GoldenGate.px(120) : 0);
        return MacMenus.isOpen ? "ok" : "no menu " + kind;
    }
    // a key on the open Settings window, for tests and scripts (ANGELOS_DEV only):
    // `angelos settingsKey down` — what the view's navigation does with it
    function settingsKey(key: string): string {
        if (!Shell.dev)
            return "dev only";
        const v = Shell.settingsView;
        if (!v)
            return "settings not open";
        const keys = {
            "up": Qt.Key_Up,
            "down": Qt.Key_Down,
            "left": Qt.Key_Left,
            "right": Qt.Key_Right,
            "enter": Qt.Key_Return,
            "home": Qt.Key_Home,
            "end": Qt.Key_End,
            "escape": Qt.Key_Escape,
            "backspace": Qt.Key_Backspace
        };
        const k = keys[String(key).toLowerCase()];
        if (k === undefined)
            return "keys: " + Object.keys(keys).join(" ");
        return v.navKeyForTest(k) ? "ok" : "not handled";
    }
    // settings search: `angelos searchSettings "прозрачность панели"` → the best matches
    function searchSettings(text: string): string {
        SettingsSearch.load();
        return JSON.stringify({
            "complete": SettingsSearch.complete(text),
            "results": SettingsSearch.search(text, 8).map(r => ({
                        "title": r.title,
                        "where": r.crumb,
                        "page": r.page,
                        "related": r.related,
                        "score": Math.round(r.score * 100) / 100
                    }))
        });
    }
    function settingsQuery(text: string): void {
        if (Shell.setupLocked)
            return;
        Shell.openSettings();
        Qt.callLater(() => {
            if (Shell.settingsView)
                Shell.settingsView.setQuery(text);
        });
    }
    // open settings at the best match: `angelos openSetting blur`
    function openSetting(text: string): string {
        if (Shell.setupLocked)
            return "the setup wizard holds the desktop (angelos setup skip)";
        Shell.openSettings();
        const r = SettingsSearch.search(text, 1)[0];
        if (!r)
            return "not found";
        Qt.callLater(() => {
            if (Shell.settingsView)
                Shell.settingsView.openResult(r);
        });
        return r.title + (r.crumb ? " · " + r.crumb : "");
    }
    function launcherText(text: string): void {
        if (Shell.setupLocked)
            return;
        if (!Shell.launcherOpen)
            Shell.launcherOpen = true;
        Shell.launcherText = text;
    }
    // open the right-click desktop menu (x, y in screen pixels); sub: no submenus any more, kept
    // for old scripts
    function desktopMenu(screen: string, x: int, y: int, sub: string): string {
        if (Shell.setupLocked)
            return "the setup wizard holds the desktop (angelos setup skip)";
        const m = Shell.desktopMenus[screen || (Shell.focusedScreen ? Shell.focusedScreen.name : "")];
        if (!m)
            return "no desktop on " + screen;
        if (x < 0) {
            m.close();
            return "closed";
        }
        if (!m.visible)
            m.openAt(x, y);
        return "ok";
    }
    function tourNext(): void {
        Tour.next();
    }
    function tourStop(): void {
        Tour.stop();
    }
    function tour(): void {
        if (Shell.setupLocked)
            return;
        Tour.start();
    }
    function lock(): void {
        if (Shell.setupLocked)
            return;
        Shell.lock();
    }
    // the boot screen now, like Settings → Y2K → "Show it now"
    function bootScreen(): void {
        Shell.bootOpen = true;
    }
    // show the lock screen without locking (Esc or any password closes it)
    function lockPreview(): void {
        if (Shell.setupLocked)
            return;
        Shell.lockPreview = !Shell.lockPreview;
    }
    // preview only: "" shows the wrong-password reaction, any text the unlock
    function lockPreviewTry(text: string): void {
        if (Shell.lockPreviewTry)
            Shell.lockPreviewTry(text);
    }
    // experimental sidebar (Settings → Bar → Sidebar)
    function sidebar(): string {
        if (Shell.setupLocked)
            return "the setup wizard holds the desktop (angelos setup skip)";
        if (!Sidebar.enabled)
            return "sidebar is off (Settings → Taskbar → Sidebar)";
        Sidebar.toggle();
        return Sidebar.open ? "open" : Sidebar.shown ? "shut, on the desk" : "closed";
    }
    // the sidebar's phone (Config.sidebar.look "phone"): turn | upright | next | prev | page N
    // | side sound|walls|theme — for a look without the mouse
    function phone(cmd: string): string {
        const a = String(cmd || "").trim().split(/\s+/);
        if (a[0] === "turn")
            Sidebar.turned = !Sidebar.turned;
        else if (a[0] === "upright")
            Sidebar.turned = false;
        else if (a[0] === "next" || a[0] === "prev")
            Sidebar.page += a[0] === "next" ? 1 : -1;
        else if (a[0] === "page")
            Sidebar.page = Number(a[1]) || 0;
        else if (a[0] === "side") {
            Sidebar.side = a[1] || "sound";
            Sidebar.turned = true;
        } else
            return "phone turn | upright | next | prev | page N | side sound|walls|theme";
        return (Sidebar.turned ? "side " + Sidebar.side : "page " + Sidebar.page) + (Sidebar.open ? "" : " (shut: angelos sidebar)");
    }
    // screensaver: animated ASCII art until any input
    function idle(): void {
        if (Shell.setupLocked)
            return;
        Idle.toggle();
    }
    // look the current song up again, skipping the caches
    function lyricsRefetch(): void {
        Lyrics.refetch();
    }
    function lyrics(): void {
        if (Shell.setupLocked)
            return;
        Config.lyrics.enabled = !Config.lyrics.enabled;
    }
    function theme(mode: string): void {
        if (Shell.setupLocked)
            return;
        Config.appearance.mode = mode === "toggle" ? (Theme.dark ? "light" : "dark") : mode;
    }
    function flavor(name: string): void {
        Config.appearance.flavor = name;
    }
    // `angelos perf [seconds]` (scripts/perf.py): what the shell spends — services/Perf
    function perf(): string {
        return Perf.snapshot();
    }
    function perfStart(seconds: int): int {
        return Perf.start(seconds);
    }
    function perfReport(): string {
        return Perf.report();
    }
    // how much moves: `angelos motion full|calm|off` (no argument: the level now)
    function motion(level: string): string {
        if (!level || level === "status")
            return Motion.level;
        return Motion.set(level);
    }
    function wallpaper(path: string): void {
        if (path === "random")
            Wallpapers.random("");
        else
            Wallpapers.setEverywhere(path);
    }
    // wallpaper for one monitor: angelos wallpaperOn DP-1 <path|random>
    function wallpaperOn(screen: string, path: string): string {
        if (!Shell.screenByName(screen))
            return "no screen " + screen;
        if (path === "random")
            Wallpapers.random(screen);
        else
            Wallpapers.setForOutput(screen, path);
        return "ok";
    }
    // half-alive wallpapers: `angelos liveWall status|on|off|analyze|<event>` (what the focused screen's
    // picture has; analyze looks at it again)
    function liveWall(cmd: string): string {
        const scr = Shell.focusedScreen ? Shell.focusedScreen.name : (Shell.screens[0] ? Shell.screens[0].name : "");
        const ws = Niri.activeWorkspace(scr);
        const path = Wallpapers.resolve(scr, ws ? ws.idx : 1);
        if (cmd === "on" || cmd === "off")
            Config.wallpaper.live = cmd === "on";
        else if (cmd === "analyze")
            LiveWalls.reanalyze(path);
        else if (cmd.startsWith("reload ")) {
            // a picture's scene changed (the scene editor, modules/sceneeditor): looked at again
            // wherever it is shown
            const p = cmd.slice(7).trim();
            if (LiveWalls.info(p) || LiveWalls.busy === p)
                LiveWalls.reanalyze(p);
            return "ok " + p;
        }
        else if (["glint", "pebble", "gust", "eye", "rings", "blink"].includes(cmd))
            LiveWalls.poke(["glint", "pebble", "gust", "eye", "rings", "blink"].indexOf(cmd) + 1);
        else if (cmd && cmd !== "status")
            return "usage: liveWall status|on|off|analyze|reload <path>|glint|pebble|gust|eye|rings|blink";
        return (Config.wallpaper.live ? "on" : "off") + "  " + path + "\n" + LiveWalls.describe(path) + "\n" + JSON.stringify(LiveWalls.effective(path));
    }
    // pixel wallpapers: `angelos pixelWall status|on|off|size N|colors N|dither N` (any picture
    // redrawn in big pixels, a copy per screen: services/Wallpapers, scripts/wall-pixelate.py)
    function pixelWall(cmd: string): string {
        const scr = Shell.focusedScreen ? Shell.focusedScreen.name : (Shell.screens[0] ? Shell.screens[0].name : "");
        const ws = Niri.activeWorkspace(scr);
        const w = cmd.trim().split(/\s+/), n = parseInt(w[1]);
        if (w[0] === "on" || w[0] === "off")
            Config.wallpaper.pixel = w[0] === "on";
        else if (w[0] === "size" && n >= 1 && n <= 32)
            Config.wallpaper.pixelSize = n;
        else if (w[0] === "colors" && n >= 2 && n <= 256)
            Config.wallpaper.pixelColors = n;
        else if (w[0] === "dither" && n >= 0 && n <= 100)
            Config.wallpaper.pixelDither = n;
        else if (w[0] && w[0] !== "status")
            return "usage: pixelWall status|on|off|size 1…32|colors 2…256|dither 0…100";
        const raw = Wallpapers.pick(Wallpapers.raw(scr, ws ? ws.idx : 1), scr);
        return (Config.wallpaper.pixel ? "on" : "off") + "  size " + Config.wallpaper.pixelSize + "  colors " + Config.wallpaper.pixelColors + "  dither " + Config.wallpaper.pixelDither + "\n" + raw + "\n" + Wallpapers.resolve(scr, ws ? ws.idx : 1) + "\n" + JSON.stringify(Wallpapers.pixelInfo(raw, scr));
    }
    // laptops: the brightness keys (cfg/angelos-laptop.kdl): up | down | 0…100
    function brightness(cmd: string): string {
        if (!Backlight.available)
            return "no backlight";
        if (cmd === "up")
            Backlight.up();
        else if (cmd === "down")
            Backlight.down();
        else if (/^\d+$/.test(cmd))
            Backlight.set(parseInt(cmd) / 100);
        return Math.round(Backlight.level * 100) + "%";
    }
    // the keyboard's light: up | down | cycle | 0…max
    function kbdLight(cmd: string): string {
        if (!Backlight.kbdAvailable)
            return "no keyboard light";
        if (cmd === "up")
            Backlight.setKbd(Backlight.kbd + 1);
        else if (cmd === "down")
            Backlight.setKbd(Backlight.kbd - 1);
        else if (cmd === "cycle" || cmd === "")
            Backlight.kbdCycle();
        else if (/^\d+$/.test(cmd))
            Backlight.setKbd(parseInt(cmd));
        return Backlight.kbd + "/" + Backlight.kbdMax;
    }
    // the rest of the laptop: `angelos laptop help` (services/Laptop.ipc)
    function laptop(line: string): string {
        return Laptop.ipc(line);
    }
    // the devices' charge (the bar's ampoules): `angelos peripherals list | refresh`
    // (services/Peripherals.ipc)
    function peripherals(line: string): string {
        return Peripherals.ipc(line);
    }
    // the devices' driver (Hall-effect keyboards, mice): `angelos devices status`; the rest of
    // `angelos devices …` is scripts/devices.py and needs no shell (services/Devices.ipc)
    function devices(line: string): string {
        return Devices.ipc(line);
    }
    // presets of settings: `angelos preset help` (services/Presets.ipc)
    function preset(line: string): string {
        return Presets.ipc(line);
    }
    // the author's new apps after an update, in the shell's own window: `angelos apps help`
    // (services/AppsSync.ipc)
    function apps(line: string): string {
        return AppsSync.ipc(line);
    }
    // password managers in the launcher: `angelos vault help` (services/Vault.ipc); no secret
    // ever crosses this channel
    function vault(line: string): string {
        return Vault.ipc(line);
    }
    // spelling in notes and replies: `angelos spell help` (services/Spell.ipc)
    function spell(line: string): string {
        return Spell.ipc(line);
    }
    // the cobwebs on windows: `angelos cobweb help` (services/Cobweb.ipc)
    function cobweb(line: string): string {
        return Cobweb.ipc(line);
    }
    function volumeUp(): void {
        Audio.step(0.05);
    }
    function volumeDown(): void {
        Audio.step(-0.05);
    }
    function mute(): void {
        Audio.toggleMute();
    }
    function micMute(): void {
        Audio.toggleMic();
    }
    function media(cmd: string): void {
        const p = Lyrics.player;
        if (!p)
            return;
        if (cmd === "next")
            p.next();
        else if (cmd === "previous" || cmd === "prev")
            p.previous();
        else if (cmd === "pause")
            p.pause();
        else if (cmd === "play")
            p.play();
        else
            p.togglePlaying();
    }
    // owner only: dotfiles pull | publish | check (no-op in the public version)
    function dotfiles(action: string): string {
        if (!Owner.enabled || !Owner.jobs)
            return "owner features are not available";
        // status: what the Dotfiles tab shows — job state, the GitHub check, the log's tail
        if (action === "status")
            return JSON.stringify({
                "state": Owner.jobs.state,
                "checking": Owner.jobs.checking,
                "ci": [Owner.jobs.ciStatus, Owner.jobs.ciConclusion, Owner.jobs.ciSha, Owner.jobs.ciUrl].join(" ").trim(),
                // the private admin repo against the public one (owner/admin-sync.sh status)
                "admin": Owner.jobs.adminStatus || {},
                "log": Owner.jobs.log.slice(-40)
            });
        Shell.openSettings("dotfiles");
        if (action === "pull")
            Owner.jobs.update();
        else if (action === "publish")
            Owner.jobs.publish(false);
        else if (action === "check")
            Owner.jobs.publish(true);
        else if (action === "admin")
            Owner.jobs.publishAdmin();
        return "ok";
    }
    // Settings → Updates: check | update | prompt (the restart question an update ends with) | later |
    // restart | status | log N (the log lines from number N on: {"next": …, "lines": […]}).
    // `angelos updates check|update` follows these until the run ends (scripts/updates-cli.py)
    function updates(cmd: string): string {
        const a = String(cmd || "").trim().split(/\s+/);
        if (a[0] === "check") {
            if (Updates.busy)
                return "busy " + Updates.state;
            if (!Updates.repo)
                return "no repository";
            Updates.check();
            return "checking";
        }
        if (a[0] === "update") {
            if (Updates.busy)
                return "busy " + Updates.state;
            if (!Updates.repo)
                return "no repository";
            Updates.update();
            return "updating " + Updates.repo;
        }
        if (a[0] === "log") {
            const from = Math.max(0, parseInt(a[1]) || 0);
            const first = Updates.logTotal - Updates.log.length;       // older lines were dropped
            return JSON.stringify({
                "next": Updates.logTotal,
                "lines": Updates.log.slice(Math.max(0, from - first))
            });
        }
        if (a[0] === "restart") {
            Updates.restartShell();
            return "ok";
        }
        if (cmd === "prompt") {
            Updates.askRestart = true;
            return "ok";
        }
        if (cmd === "later") {
            Updates.restartLater();
            return "ok";
        }
        return JSON.stringify({
            "state": Updates.state,
            "behind": Updates.behind,
            "ahead": Updates.ahead,
            "dirty": Updates.dirty,
            "trusted": Updates.trusted,
            "error": Updates.error,
            "needsRestart": Updates.needsRestart,
            "repo": Updates.repo,
            "lastRun": Updates.lastRun,
            "lastStatus": Updates.lastStatus,
            "stage": Updates.failedStage,
            "failure": Updates.failure ? Updates.failureText(Updates.failedStage, Updates.failure) : "",
            "next": Updates.failure ? Updates.nextStep(Updates.failedStage) : "",
            "backup": Updates.backupDir,
            "landed": Updates.landed,
            "incoming": Updates.incoming.length
        });
    }
    // used by ~/.local/bin/polkit-agent-guard to hand the session slot back to angelOS
    function polkitRegister(): void {
        if (Shell.polkitReregister)
            Shell.polkitReregister();
    }
    function plugins(): void {
        Plugins.reload();
    }
    function reload(): void {
        Quickshell.reload(true);
    }
    // an id of WorkspaceAnim.styles: soft | dash | spring | snap | zoom | card | wipe | fade | dissolve | realm | glitch | crt | instant
    function switchFx(style: string): string {
        if (!WorkspaceAnim.styles.some(x => x.id === style))
            return "styles: " + WorkspaceAnim.styles.map(x => x.id).join(", ");
        WorkspaceAnim.pick(style);
        return WorkspaceAnim.log || "ok";
    }
    // the current workspace transition over an output, without switching
    function testTransition(output: string): string {
        if (!WorkspaceAnim.captured)
            return "the current style (" + WorkspaceAnim.current.id + ") is niri's own animation";
        WorkspaceAnim.preview(output);
        return "ok";
    }
    // replay the workspace switch animation on an output (handy after tweaking settings)
    function testFx(output: string): void {
        const ws = Niri.activeWorkspace(output || Niri.focusedOutput);
        if (ws)
            Niri.workspaceActivated(ws, false);
    }
    // the newest card's reply, for tests (ANGELOS_DEV only): `angelos notifReply open` puts its
    // field up, `angelos notifReply close` takes it down, anything else is sent as typed there
    function notifReply(text: string): string {
        if (!Shell.dev)
            return "dev only";
        const n = Notifs.popups[Notifs.popups.length - 1];
        if (!n || (!n.hasInlineReply && text !== "window"))
            return "no card to reply to";
        if (text === "open")
            Notifs.replyTo = n;
        else if (text === "close")
            Notifs.replyTo = null;
        else if (text === "window") {
            const w = Notifs.appWindow(n);
            return w ? w.app_id + " · " + w.title : "no window";
        }
        else
            Notifs.reply(n, text);
        return "ok";
    }
    function testNotify(): void {
        if (!Shell.dev) {
            Quickshell.execDetached(["notify-send", "-a", "angelOS", I18n.t("Привет ♡", "Hello ♡"), I18n.t("тестовое уведомление", "test notification")]);
            return;
        }
        Notifs.popups = Notifs.popups.concat([
            {
                "id": 900000 + Math.floor(Math.random() * 99999),
                "appName": "angelOS",
                "summary": I18n.t("Привет, это тест ♡", "Hello, this is a test ♡"),
                "body": I18n.t("Уведомление в стиле <b>NGO</b>: пиксели, розовый и сердечки. <i>Клик</i> — закрыть.", "An <b>NGO</b> notification: pixels, pink and hearts. <i>Click</i> to dismiss."),
                "actions": [
                    {
                        "text": I18n.t("Ответить", "Reply"),
                        "identifier": "reply",
                        "invoke": () => {}
                    }
                ],
                "urgency": 1,
                "expireTimeout": -1,
                "image": "",
                "appIcon": "kitty",
                "desktopEntry": "",
                "tracked": false
            }
        ]);
    }
    function testOsd(): void {
        Audio.changed("volume");
    }
    function panel(name: string, output: string): bool {
        return PopupManager.showPanel(name, output);
    }
    function taskLabels(show: bool): void {
        Config.bar.taskLabels = show;
    }
    function claudeBar(mode: string): void {
        if (["off", "five", "week", "both"].includes(mode)) {
            const p = Plugins.byId("claude-companion");
            if (p)
                Plugins.context(p).set("barLimit", mode);
        }
    }
    function lyricArtwork(mode: string): void {
        if (["note", "cover"].includes(mode))
            Config.lyrics.artwork = mode;
    }
    // font presets: angelos | arcade | soft | block (missing fonts are downloaded)
    function fontPreset(id: string): string {
        const p = Fonts.presets.find(x => x.id === id);
        if (!p)
            return "presets: " + Fonts.presets.map(x => x.id).join(", ");
        Fonts.applyPreset(p);
        return "ok";
    }
    function blur(enabled: bool): void {
        Config.appearance.blur = enabled;
    }
    function diagnostics(): string {
        const bars = {};
        for (const k of Object.keys(Shell.barViews))
            bars[k] = Shell.barViews[k].diagnostics();
        return JSON.stringify({
            settings: Shell.settingsView ? Shell.settingsView.diagnostics() : null,
            bars: bars,
            lyrics: {
                status: Lyrics.status,
                source: Lyrics.source,
                track: Lyrics.artist + " — " + Lyrics.title,
                hasLyrics: Lyrics.hasLyrics,
                enabled: Config.lyrics.enabled,
                visible: Lyrics.visibleToggle,
                screens: Config.lyrics.screens,
                index: Lyrics.index,
                line: Lyrics.current,
                count: Lyrics.lines.length
            },
            popup: PopupManager.active ? PopupManager.active.title : "",
            panels: PopupManager.registered.map(p => ({
                        id: p.panelId,
                        output: p.outputName,
                        visible: p.visible,
                        width: p.width,
                        height: p.height
                    })),
            language: Config.appearance.language
        });
    }
    function status(): string {
        return JSON.stringify({
            "theme": Theme.dark ? "dark" : "light",
            "flavor": Config.appearance.flavor,
            "bar": BarLayout.edge,
            "lyrics": Lyrics.status,
            "track": Lyrics.title,
            "plugins": Plugins.enabledPlugins.map(p => p.id),
            "screens": Shell.screens.map(s => s.name),
            "polkit": Shell.polkitRegistered,
            "notifications": true
        });
    }
}
