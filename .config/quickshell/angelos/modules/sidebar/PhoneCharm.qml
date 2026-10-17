import QtQuick
import qs.config
import qs.widgets
import "../y2k/AngelSpriteMini.js" as AngelMini
import "../y2k/DemonSpriteMini.js" as DemonMini

// A tiny her, 20×21 art pixels (the first helper's sprites, in the colours AngelHelper gives
// them): the charm on the phone's strap and her face on the screen while she calls (Phone,
// PhoneCall). `talk` opens her mouth on every other tick, `tick` flaps her wings.
PxIcon {
    id: root

    property string who: "angel"
    property bool talk: false
    property int tick: 0
    readonly property bool demon: who === "demon"
    readonly property var art: demon ? DemonMini : AngelMini
    bitmap: talk && tick % 2 === 0 ? art.talk : Math.floor(tick / 3) % 2 ? art.down : art.up
    ink: demon ? "#1a0a14" : (Theme.dark ? Theme.text : Theme.edge)
    body: demon ? "#f7d9e3" : "#ffd9c7"
    fill: demon ? "#ff3b6b" : Theme.accent
    fill2: "#3a1a46"
    fill3: Theme.dark ? "#ffe07a" : "#f5c542"
    light: demon ? "#7a1e46" : "#ffffff"
    bad: "#d8203a"
}
