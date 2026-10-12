pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import qs.modules.bar.parts

// The bar's equalizer inside the shell (started by tests/eq/run.sh, offscreen): two faces,
// as on two screens, over one Eq service — against stand-ins of pactl, pw-link and of
// EasyEffects' socket (tests/eq/fake). An app that already plays into EasyEffects with no
// saved route is shown and taken over, a band moves, the route is given back.
Scope {
    id: root

    property int step: 0
    property double since: Date.now()

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
    function what() {
        return "ready=" + Eq.ready + " error=" + Eq.error + " route=" + Eq.routeActive + ":" + Eq.routedApp + ">" + Eq.routedOutput + " sel=" + Eq.selectedSource + ">" + Eq.selectedOutput + " rerr=" + Eq.routingError + " levels=" + Eq.levels;
    }

    FloatingWindow {
        id: win
        implicitWidth: 600
        implicitHeight: 200
        color: Theme.face
        Loader {
            id: faces
            sourceComponent: Row {
                EqButton {}
                EqButton {}
            }
        }
    }

    // a bar of a screen that goes away: the window and the face in it
    LazyLoader {
        id: other
        FloatingWindow {
            visible: true
            implicitWidth: 300
            implicitHeight: 100
            EqButton {}
        }
    }

    Timer {
        interval: 100
        repeat: true
        running: true
        onTriggered: {
            switch (root.step) {
            case 0:
                // a RØDECaster (Duo, Pro II) is a mixer; its virtual channels, another
                // RØDE and an ordinary card are not — and the bar has "eq" only when offered
                root.report("eq-rode-is-a-mixer", Eq.isMixer("alsa_output.usb-R__DE_RODECaster_Duo_IT0009789-00.pro-output-1") && Eq.isMixer("alsa_input.usb-R__DE_RODECaster_Pro_II_GV0000000-00.pro-input-0") && !Eq.isMixer("rcp_duo_music_in") && !Eq.isMixer("alsa_input.usb-R__DE_Microphones_RODE_NT-USB_0000-00.analog-stereo") && !Eq.isMixer("alsa_output.pci-0000_06_00.1.hdmi-stereo") && !Eq.isMixer(undefined));
                root.report("eq-on-the-bar-only-when-offered", BarLayout.has("eq") === Eq.offered && BarLayout.valid("eq") === Eq.offered && BarLayout.valid("volume"), "has=" + BarLayout.has("eq") + " offered=" + Eq.offered + " mixer=" + Eq.mixer);
                win.visible = true;
                // a bar is built, dropped and built again while the shell starts
                faces.active = false;
                faces.active = true;
                win.visible = false;
                faces.active = false;
                faces.active = true;
                win.visible = true;
                root.next();
                break;
            case 1:
                root.until("eq-one-service", () => Eq.watchers === 2 && Eq.ready && Eq.frequencies[9] === 16000, 15000, root.what);
                break;
            case 2:
                other.active = true;
                root.next();
                break;
            case 3:
                root.until("eq-third-face", () => Eq.watchers === 3, 5000, () => String(Eq.watchers));
                break;
            case 4:
                other.active = false;
                root.next();
                break;
            case 5:
                if (Date.now() - root.since < 800)
                    break;
                root.report("eq-window-gone-counted-once", Eq.watchers === 2, String(Eq.watchers));
                root.next();
                break;
            case 6:
                // Helium plays into EasyEffects, nothing was saved about it
                root.until("eq-orphan-shown", () => Eq.routeActive && Eq.routedApp === "Helium" && Eq.routedOutput === "rcp_duo_system_in" && Eq.selectedSource === "Helium" && Eq.rode, 8000, root.what);
                break;
            case 7:
                Eq.viewers++;
                Eq.selectedOutput = "rcp_duo_music_in";
                Eq.outputExplicit = true;
                Eq.routeCommand("route");
                root.next();
                break;
            case 8:
                root.until("eq-orphan-taken-over", () => Eq.routeActive && Eq.routedOutput === "rcp_duo_music_in" && Eq.routingError === "", 8000, root.what);
                break;
            case 9:
                // another app can be picked while one is in the equalizer: polls leave it alone
                Eq.selectedSource = "Spotify";
                root.next();
                break;
            case 10:
                if (Date.now() - root.since < 4500)
                    break;
                root.report("eq-pick-survives-polls", Eq.selectedSource === "Spotify" && Eq.routedApp === "Helium", root.what());
                root.next();
                break;
            case 11:
                Eq.changeBand(3, 6);
                root.next();
                break;
            case 12:
                root.until("eq-band-set", () => Eq.levels[3] === 6 && faces.item.children[0].levels[3] === 6 && faces.item.children[1].levels[3] === 6 && Eq.preset === "", 8000, root.what);
                break;
            case 13:
                Eq.send("preset bass");
                root.next();
                break;
            case 14:
                root.until("eq-preset", () => Eq.preset === "bass" && Eq.levels[0] === 3, 8000, root.what);
                break;
            case 15:
                Eq.releaseRoute();
                root.next();
                break;
            case 16:
                root.until("eq-released", () => !Eq.routeActive && Eq.routingError === "", 8000, root.what);
                break;
            case 17:
                Eq.viewers--;
                faces.active = false;
                root.next();
                break;
            case 18:
                root.until("eq-faces-counted-out", () => Eq.watchers === 0 && Eq.viewers === 0, 4000, () => Eq.watchers + " / " + Eq.viewers);
                break;
            default:
                console.log("TEST DONE");
                Qt.quit();
            }
        }
    }
}
