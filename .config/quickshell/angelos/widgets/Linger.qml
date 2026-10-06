import QtQuick

// `alive` while `when` holds and for `ms` after it stops. A window built on demand
// (LazyLoader { active: linger.alive }) stays a little after it closes — its closing
// animation, a quick reopen — and then goes, with everything it held.
QtObject {
    id: root

    property bool when: false
    property int ms: 20000
    readonly property bool alive: when || hold.running

    onWhenChanged: when ? hold.stop() : hold.restart()

    property Timer hold: Timer {
        interval: root.ms
    }
}
