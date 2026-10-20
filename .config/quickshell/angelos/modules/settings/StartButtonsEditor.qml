pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.bar

// The buttons along Start's bottom (Config.bar.startButtons, services/StartItems.buttons): the
// row as Start shows it and a shelf of the rest. Drag from the shelf into the row to add (or
// click a shelf button: it goes at the end), drag inside the row to reorder, drag out of the
// row or click × to remove. Standalone, so it can sit on any settings page.
Item {
    id: root

    readonly property var row: StartItems.chosen
    readonly property var rowIds: row.map(b => b.id)
    readonly property var shelf: StartItems.buttonsFor(StartItems.buttonIds.filter(id => !rowIds.includes(id)))
    readonly property int cell: Theme.u * 15
    readonly property int step: cell + Theme.u * 5

    implicitHeight: col.implicitHeight

    function save(ids) {
        Config.bar.startButtons = ids;
    }
    function add(id, at) {
        const l = rowIds.filter(x => x !== id);
        l.splice(at === undefined || at < 0 ? l.length : Math.min(at, l.length), 0, id);
        save(l);
    }
    function remove(id) {
        save(rowIds.filter(x => x !== id));
    }

    // ---- dragging: one button at a time, from the row or the shelf ----
    property string dragId: ""
    property string dragFrom: ""            // row | shelf
    property point dragPos: Qt.point(0, 0)  // the pointer, in root's coordinates
    // where it would land in the row: an index, or -1 when it is not over the row
    readonly property int dropAt: {
        if (dragId === "")
            return -1;
        const p = mapToItem(rowBox, dragPos.x, dragPos.y);
        if (p.x < -cell || p.x > rowBox.width + cell || p.y < -cell || p.y > rowBox.height + cell)
            return -1;
        const n = rowIds.filter(x => x !== dragId).length;
        return Math.max(0, Math.min(n, Math.round((p.x - cells.x - cell / 2) / step)));
    }
    function dragStart(id, from, scene) {
        dragId = id;
        dragFrom = from;
        dragMove(scene);
    }
    function dragMove(scene) {
        dragPos = mapFromItem(null, scene.x, scene.y);
    }
    function dragEnd() {
        const id = dragId, at = dropAt, from = dragFrom;
        dragId = "";
        dragFrom = "";
        if (id === "")
            return;
        if (at >= 0)
            add(id, at);
        else if (from === "row")
            remove(id);
    }

    Column {
        id: col
        width: parent.width
        spacing: Theme.u * 3

        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            kind: "tiny"
            dim: true
            text: I18n.t("Перетащи кнопку с полки в ряд (или щёлкни по ней — встанет в конец), внутри ряда — поменять порядок, из ряда наружу или × — убрать. Сон срабатывает сразу, без вопроса.", "Drag a button from the shelf into the row (or click it: it goes at the end), drag inside the row to reorder, out of the row or × to remove. Sleep works at once, without asking.")
        }

        // the row, as Start draws it
        PxBox {
            id: rowBox
            // always room for one more at the end
            width: Math.max(4, root.row.length + 1) * root.step - Theme.u * 5 + Theme.u * 16 + inset * 2
            height: root.cell + Theme.u * 14 + inset * 2
            sunken: true
            color: root.dropAt >= 0 ? Theme.mix(Theme.sunken, Theme.accent, 0.12) : Theme.sunken
            Item {
                id: cells
                x: Theme.u * 8
                y: Theme.u * 7
                width: Math.max(0, root.row.length * root.step - Theme.u * 5)
                height: root.cell
                Repeater {
                    model: root.row
                    Item {
                        id: slot
                        required property var modelData
                        required property int index
                        readonly property bool dragged: root.dragId === modelData.id
                        // the others make room where the dragged one would go
                        readonly property int place: {
                            if (root.dragId === "" || root.dropAt < 0)
                                return index;
                            const rest = root.rowIds.filter(x => x !== root.dragId);
                            const i = rest.indexOf(modelData.id);
                            return dragged ? root.dropAt : (i >= root.dropAt ? i + 1 : i);
                        }
                        x: place * root.step
                        width: root.cell
                        height: root.cell
                        opacity: dragged ? 0.35 : 1
                        Behavior on x {
                            NumberAnimation {
                                duration: Motion.ms(90)
                            }
                        }
                        StartButtonCell {
                            id: btn
                            anchors.fill: parent
                            button: slot.modelData
                            tip: root.dragId === ""
                        }
                        DragHandler {
                            target: null
                            grabPermissions: PointerHandler.CanTakeOverFromAnything
                            cursorShape: Qt.ClosedHandCursor
                            onActiveChanged: active ? root.dragStart(slot.modelData.id, "row", centroid.scenePosition) : root.dragEnd()
                            onCentroidChanged: if (active)
                                root.dragMove(centroid.scenePosition)
                        }
                        // × in the corner while the pointer is on it
                        PxBox {
                            visible: (btn.hovered || closer.containsMouse) && root.dragId === ""
                            x: parent.width - width / 2 - Theme.u
                            y: -height / 2 + Theme.u
                            z: 2
                            width: Theme.u * 7
                            height: Theme.u * 7
                            flat: true
                            color: closer.containsMouse ? Theme.danger : Theme.face
                            PxText {
                                anchors.centerIn: parent
                                kind: "tiny"
                                text: "×"
                                color: closer.containsMouse ? "#ffffff" : Theme.text
                            }
                            MouseArea {
                                id: closer
                                anchors.fill: parent
                                anchors.margins: -Theme.u
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.remove(slot.modelData.id)
                            }
                        }
                    }
                }
                // where a button from the shelf would go: the gap the others made, outlined
                Rectangle {
                    visible: root.dragFrom === "shelf" && root.dropAt >= 0
                    x: root.dropAt * root.step
                    width: root.cell
                    height: root.cell
                    color: "transparent"
                    border.width: Theme.u
                    border.color: Theme.accent
                }
            }
            PxText {
                visible: root.row.length === 0
                anchors.centerIn: parent
                kind: "tiny"
                dim: true
                text: I18n.t("пусто — перетащи сюда", "empty: drag here")
            }
        }

        PxText {
            text: I18n.t("Полка — что можно поставить:", "Shelf: what can go there:")
            kind: "tiny"
            dim: true
        }
        Flow {
            width: parent.width
            spacing: Theme.u * 2
            Repeater {
                model: root.shelf
                PxButton {
                    id: shelfBtn
                    required property var modelData
                    compact: true
                    icon: modelData.icon
                    text: modelData.label
                    opacity: root.dragId === modelData.id ? 0.35 : 1
                    onClicked: root.add(modelData.id)
                    DragHandler {
                        target: null
                        grabPermissions: PointerHandler.CanTakeOverFromAnything
                        cursorShape: Qt.ClosedHandCursor
                        onActiveChanged: active ? root.dragStart(shelfBtn.modelData.id, "shelf", centroid.scenePosition) : root.dragEnd()
                        onCentroidChanged: if (active)
                            root.dragMove(centroid.scenePosition)
                    }
                }
            }
        }
        PxText {
            visible: root.shelf.length === 0
            text: I18n.t("всё уже в ряду", "everything is in the row")
            kind: "tiny"
            dim: true
        }
        PxButton {
            compact: true
            flat: true
            icon: "refresh"
            text: I18n.t("Как было", "Reset")
            enabled: JSON.stringify(root.rowIds) !== JSON.stringify(["updates", "lock", "sleep", "power"])
            onClicked: Config.resetKeys(["bar.startButtons"])
        }
    }

    // the button under the pointer while it is dragged
    StartButtonCell {
        visible: root.dragId !== ""
        z: 10
        x: Math.round(root.dragPos.x - width / 2)
        y: Math.round(root.dragPos.y - height / 2)
        button: StartItems.buttons[root.dragId] || ({})
        tip: false
        enabled: false
        opacity: 0.9
    }
}
