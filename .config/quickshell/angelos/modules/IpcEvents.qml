import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// Events for other programs (Quickshell 0.3's IPC signal listeners): `angelos events [signal]`
// (= `qs -c angelos ipc listen events [signal]`) prints a line each time one fires, so a stream
// bot, a fader script or a status bar follows angelOS without polling it. `angelos eventsNow`
// gives the state they describe right now, as JSON. Quickshell lets a signal carry one value:
// awake gives its reason ("" = off), angelSaid a line of JSON.
Scope {
    id: root

    // settings.json not read yet: the defaults flickering into the real values are no events
    readonly property bool live: Config.ready

    IpcHandler {
        id: ev

        target: "events"

        signal stream(bool active)              // stream mode on/off (OBS or by hand)
        signal awake(string reason)             // stay awake: manual | stream | fullscreen; "" = off
        signal realm(string realm)              // heaven | hell — the widgets' world
        signal character(string who)            // angel | demon — who the player is
        signal circle(string circle)            // the hell circle the player is in ("" outside)
        signal locked(bool locked)
        signal idle(bool active)                // the idle screen
        signal theme(string mode)               // dark | light
        signal dnd(bool on)                     // Do not disturb
        signal angelSaid(string line)           // the corner helper spoke: {"who": angel|demon, "text": …}

        function now(): string {
            return JSON.stringify({
                "stream": StreamMode.active,
                "awake": Awake.active,
                "awakeReason": Awake.reason,
                "realm": Theme.realm,
                "character": Angel.demon ? "demon" : "angel",
                "circle": Story.circle,
                "locked": Shell.locked,
                "idle": Idle.active,
                "theme": Theme.dark ? "dark" : "light",
                "dnd": !!Config.notifications.dnd
            });
        }
    }

    Connections {
        target: StreamMode
        enabled: root.live
        function onActiveChanged() {
            ev.stream(StreamMode.active);
        }
    }
    Connections {
        target: Awake
        enabled: root.live
        function onActiveChanged() {
            ev.awake(Awake.reason);
        }
        function onReasonChanged() {
            if (Awake.active)
                ev.awake(Awake.reason);
        }
    }
    Connections {
        target: Theme
        enabled: root.live
        function onRealmChanged() {
            ev.realm(Theme.realm);
        }
        function onDarkChanged() {
            ev.theme(Theme.dark ? "dark" : "light");
        }
    }
    Connections {
        target: Angel
        enabled: root.live
        function onDemonChanged() {
            ev.character(Angel.demon ? "demon" : "angel");
        }
        function onSaid(text) {
            ev.angelSaid(JSON.stringify({
                "who": Angel.demon ? "demon" : "angel",
                "text": text
            }));
        }
    }
    Connections {
        target: Story
        enabled: root.live
        function onCircleChanged() {
            ev.circle(Story.circle);
        }
    }
    Connections {
        target: Shell
        enabled: root.live
        function onLockedChanged() {
            ev.locked(Shell.locked);
        }
    }
    Connections {
        target: Idle
        enabled: root.live
        function onActiveChanged() {
            ev.idle(Idle.active);
        }
    }
    Connections {
        target: Config.notifications
        enabled: root.live
        function onDndChanged() {
            ev.dnd(!!Config.notifications.dnd);
        }
    }
}
