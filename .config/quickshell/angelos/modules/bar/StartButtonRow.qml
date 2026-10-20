pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// Start's row of buttons (sleep, lock, power…): the ones the user picked, in their order
// (Config.bar.startButtons, services/StartItems.buttons). Every button the same square (15×15
// art pixels, 20 apart), a tooltip with its name. A look drops it in as is:
//     StartButtonRow { anchors.right: …; anchors.verticalCenter: … }
// A click closes Start and then does the button's action (as the looks' own buttons did).
// `live: false` (previews, the settings editor) only reports the click: activated(id).
// A look with its own Scale hands in its units (StartPrefs.of(look): unit, iu); the default is
// the plain art pixel, as the settings editor draws it.
Item {
    id: root

    property var ids: Config.bar.startButtons
    property bool labelled: false           // the label under each icon (wider, taller cells)
    property bool live: true
    property real unit: Theme.u             // a length unit: cells and gaps are whole pixels of it
    property int iu: Theme.u                // the icons' art pixel, a whole number
    signal activated(string id)

    readonly property var items: StartItems.buttonsFor(ids)
    readonly property int count: items.length
    function px(n) {
        return Math.round(unit * n);
    }
    // the cell: square when compact; labelled, as wide as the longest label
    readonly property int cellWidth: labelled ? Math.max(px(15), Math.ceil(measure.implicitWidth / iu) * iu + px(6)) : px(15)
    readonly property int cellHeight: labelled ? px(17) + Math.ceil(measure.implicitHeight / iu) * iu + px(2) : px(15)
    readonly property int gap: px(5)

    implicitWidth: row.implicitWidth
    implicitHeight: count ? cellHeight : 0

    function run(b) {
        activated(b.id);
        if (!live)
            return;
        Shell.closeStart();
        // after the overlay let go of the keyboard, so a dialog or the launcher gets it
        Qt.callLater(b.run);
    }

    // the widest label (only while labelled); not `visible: false` — a hidden Column lays out nothing
    Column {
        id: measure
        opacity: 0
        Repeater {
            model: root.labelled ? root.items : []
            PxText {
                required property var modelData
                kind: "tiny"
                text: modelData.label
            }
        }
    }

    Row {
        id: row
        spacing: root.gap
        Repeater {
            model: root.items
            StartButtonCell {
                required property var modelData
                button: modelData
                labelled: root.labelled
                unit: root.unit
                iu: root.iu
                width: root.cellWidth
                height: root.cellHeight
                onClicked: root.run(modelData)
            }
        }
    }
}
