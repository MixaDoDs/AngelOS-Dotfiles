import QtQuick

// On a page that scrolls (an ancestor with `wheelRest`, the settings: SettingsView) the wheel
// turns a slider or a spin box only once the pointer has rested on it that long or it was
// pressed: a page scrolled with a touchpad or a wheel slid its sliders under the pointer and
// every one they passed changed (#93). Until then the wheel goes on to the page. Elsewhere (the
// bar's mixer, the sidebar, the phone) it turns at once.
// A touchpad's small steps add up to whole notches; a sideways swipe turns nothing.
Item {
    id: gate
    property bool hovered: false   // the control's MouseArea.containsMouse
    property bool held: false      // its MouseArea.pressed: turns at once
    property bool armed: false
    property real _acc: 0
    // the rest the page asks for, 0 outside such a page (looked up on hover: the control may be
    // put on its page after it was made)
    function _rest() {
        for (let p = parent; p; p = p.parent)
            if (p.wheelRest !== undefined)
                return p.wheelRest;
        return 0;
    }
    onHoveredChanged: {
        _acc = 0;
        rest.stop();
        if (!hovered) {
            armed = held;
            return;
        }
        rest.interval = _rest();
        armed = held || rest.interval <= 0;
        if (!armed)
            rest.start();
    }
    onHeldChanged: if (held)
        armed = true
    Timer {
        id: rest
        onTriggered: gate.armed = true
    }
    // the whole notches this wheel event turns (+ up, − down); 0 and the event left to the page
    // while not armed (the scroll going on keeps it from arming)
    function steps(w) {
        if (!armed) {
            w.accepted = false;
            rest.restart();
            return 0;
        }
        _acc += w.angleDelta.y;
        const n = _acc > 0 ? Math.floor(_acc / 120) : Math.ceil(_acc / 120);
        _acc -= n * 120;
        return n;
    }
}
