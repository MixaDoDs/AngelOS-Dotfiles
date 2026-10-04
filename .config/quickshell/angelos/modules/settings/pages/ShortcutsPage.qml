pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// Settings → Shortcuts: every niri key binding from cfg/keybinds.kdl, changeable
// in place, plus new shortcuts for apps, angelOS / niri actions or any command.
PxPage {
    id: page

    heading: I18n.t("Горячие клавиши", "Shortcuts")
    subtitle: I18n.t("Все сочетания niri из cfg/keybinds.kdl. Нажми на сочетание, чтобы поменять его; изменения проверяются niri и сохраняются с бэкапом.", "Every niri binding from cfg/keybinds.kdl. Click a combination to change it; changes are validated by niri and backed up.")

    Component.onCompleted: Keybinds.refresh()

    property string filter: ""
    property int editing: -1               // bind id whose combination is being recorded
    readonly property var shown: {
        const f = filter.trim().toLowerCase();
        return Keybinds.binds.filter(b => {
            if (!f)
                return true;
            const d = Keybinds.describe(b);
            return (b.key + " " + Keybinds.pretty(b.key) + " " + d.label + " " + d.detail + " " + b.title + " " + b.section).toLowerCase().includes(f);
        });
    }

    // modifier buttons + "press a key" field; emits the combination
    component Recorder: Row {
        id: rec
        property var mods: ({
                "mod": true,
                "ctrl": false,
                "alt": false,
                "shift": false
            })
        property string key: ""
        property int exceptId: -1
        readonly property string combo: Keybinds.compose(mods, key)
        readonly property var clash: combo ? Keybinds.bindFor(combo, exceptId) : null
        function load(k) {
            const parts = String(k || "").split("+");
            const m = {
                "mod": false,
                "ctrl": false,
                "alt": false,
                "shift": false
            };
            for (const p of parts.slice(0, -1)) {
                const n = (Keybinds.modNames[p.toLowerCase()] || p).toLowerCase();
                if (m[n] !== undefined)
                    m[n] = true;
            }
            mods = m;
            key = parts[parts.length - 1] || "";
        }
        spacing: Theme.u * 2
        Repeater {
            model: [["mod", "Win"], ["ctrl", "Ctrl"], ["alt", "Alt"], ["shift", "Shift"]]
            PxButton {
                required property var modelData
                compact: true
                text: modelData[1]
                checked: !!rec.mods[modelData[0]]
                onClicked: {
                    const m = Object.assign({}, rec.mods);
                    m[modelData[0]] = !m[modelData[0]];
                    rec.mods = m;
                }
            }
        }
        PxText {
            text: "+"
            anchors.verticalCenter: parent.verticalCenter
        }
        // focus it and press the key; modifiers held at the same time are taken too
        Item {
            id: catcher
            width: Theme.u * 60
            height: Theme.u * 13
            focus: false
            activeFocusOnTab: true
            PxBox {
                anchors.fill: parent
                sunken: true
                color: Theme.sunken
                edgeColor: catcher.activeFocus ? Theme.accent : Theme.edge
            }
            PxText {
                anchors.centerIn: parent
                width: parent.width - Theme.u * 4
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: catcher.activeFocus ? I18n.t("нажми клавишу…", "press a key…") : rec.key ? Keybinds.pretty(rec.key) : I18n.t("клавиша", "key")
                dim: !rec.key || catcher.activeFocus
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: catcher.forceActiveFocus()
            }
            Keys.onPressed: e => {
                e.accepted = true;
                if (e.key === Qt.Key_Escape && !(e.modifiers & ~Qt.KeypadModifier)) {
                    catcher.focus = false;
                    return;
                }
                if (Keybinds.isModifier(e))
                    return;
                const name = Keybinds.keyName(e);
                if (!name)
                    return;
                const m = Keybinds.mods(e);
                if (m.mod || m.ctrl || m.alt || m.shift)
                    rec.mods = m;
                rec.key = name;
                catcher.focus = false;
            }
        }
        PxField {
            width: Theme.u * 44
            placeholder: I18n.t("или имя", "or a name")
            onEdited: rec.key = text.trim()
        }
    }

    PxGroup {
        name: "new-shortcut"
        title: I18n.t("Новое сочетание", "New shortcut")
        icon: "plus"
        width: parent.width

        property string kind: "app"
        property string appId: ""
        property int actionIndex: 0
        id: addGroup

        SettingRow {
            label: I18n.t("Что запускать", "What it does")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("Приложение", "App"),
                        "value": "app"
                    },
                    {
                        "label": I18n.t("Действие системы", "System action"),
                        "value": "action"
                    },
                    {
                        "label": I18n.t("Команда", "Command"),
                        "value": "command"
                    }
                ]
                currentValue: addGroup.kind
                onActivated: v => addGroup.kind = v
            }
        }
        SettingRow {
            visible: addGroup.kind === "app"
            label: I18n.t("Хоткей для приложения", "Shortcut for an app")
            hint: I18n.t("запускается через gtk-launch, как из меню", "Started with gtk-launch, like from the menu")
            PxCombo {
                width: parent.width
                model: StartApps.apps.map(a => ({
                            "label": a.name,
                            "value": a.id
                        }))
                currentValue: addGroup.appId
                placeholder: I18n.t("выбери приложение", "pick an app")
                onActivated: v => addGroup.appId = v
            }
        }
        SettingRow {
            visible: addGroup.kind === "action"
            label: I18n.t("Системный вызов", "System call")
            hint: I18n.t("действия angelOS (лаунчер, «Пуск», буфер, блокировка…) и niri", "angelOS actions (launcher, Start, clipboard, lock…) and niri ones")
            PxCombo {
                width: parent.width
                model: Keybinds.catalog.map((c, i) => ({
                            "label": c.label,
                            "value": i
                        }))
                currentValue: addGroup.actionIndex
                onActivated: v => addGroup.actionIndex = v
            }
        }
        SettingRow {
            visible: addGroup.kind === "command"
            label: I18n.t("Команда", "Command")
            hint: I18n.t("выполняется через sh -c", "Run with sh -c")
            PxField {
                id: cmdField
                width: parent.width
                placeholder: "notify-send hi"
            }
        }
        SettingRow {
            label: I18n.t("Сочетание", "Combination")
            hint: addRec.clash ? I18n.t("⚠ уже занято: ", "⚠ already used: ") + Keybinds.describe(addRec.clash).label : I18n.t("кнопками выбери модификаторы, потом нажми клавишу в поле", "Pick modifiers with the buttons, then press the key in the box")
            Recorder {
                id: addRec
            }
        }
        Row {
            spacing: Theme.u * 3
            PxButton {
                text: I18n.t("Добавить", "Add")
                icon: "plus"
                accent: true
                enabled: !Keybinds.busy && addRec.combo !== "" && !addRec.clash && (addGroup.kind === "app" ? addGroup.appId !== "" : addGroup.kind === "command" ? cmdField.text.trim() !== "" : true)
                onClicked: {
                    let action = "", title = "";
                    if (addGroup.kind === "app") {
                        const app = StartApps.apps.find(a => a.id === addGroup.appId);
                        action = 'spawn "gtk-launch" ' + JSON.stringify(addGroup.appId);
                        title = app ? app.name : addGroup.appId;
                    } else if (addGroup.kind === "action") {
                        const c = Keybinds.catalog[addGroup.actionIndex];
                        action = c.action;
                        title = c.label;
                    } else {
                        action = "spawn-sh " + JSON.stringify(cmdField.text.trim());
                        title = cmdField.text.trim();
                    }
                    Keybinds.apply([
                        {
                            "op": "add",
                            "key": addRec.combo,
                            "action": action,
                            "title": title
                        }
                    ]);
                }
            }
            PxText {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.u * 220
                wrapMode: Text.Wrap
                text: Keybinds.log
                kind: "tiny"
                color: Keybinds.failed ? Theme.danger : Theme.textDim
            }
        }
    }

    PxGroup {
        name: "all-shortcuts"
        title: I18n.t("Все сочетания", "All shortcuts") + " (" + Keybinds.binds.length + ")"
        icon: "keyboard"
        width: parent.width

        PxField {
            width: parent.width
            icon: "search"
            placeholder: I18n.t("Фильтр: клавиша, действие, приложение…", "Filter: key, action, app…")
            onEdited: page.filter = text
        }
        PxText {
            visible: !Keybinds.loaded
            text: Keybinds.failed ? Keybinds.log : "…"
            color: Keybinds.failed ? Theme.danger : Theme.textDim
        }

        Repeater {
            model: page.shown
            Column {
                id: entry
                required property var modelData
                required property int index
                readonly property var info: Keybinds.describe(modelData)
                readonly property bool newSection: index === 0 || page.shown[index - 1].section !== modelData.section
                width: parent.width
                spacing: Theme.u

                PxText {
                    visible: entry.newSection && entry.modelData.section !== ""
                    text: "✧ " + entry.modelData.section
                    kind: "tiny"
                    dim: true
                    topPadding: Theme.u * 3
                }
                Item {
                    width: parent.width
                    height: Math.max(Theme.u * 15, rowInfo.implicitHeight + Theme.u * 2)

                    // the combination: click to record a new one
                    PxButton {
                        id: keyChip
                        visible: page.editing !== entry.modelData.id
                        width: Theme.u * 72
                        anchors.verticalCenter: parent.verticalCenter
                        compact: true
                        enabled: entry.modelData.editable && !Keybinds.busy
                        text: Keybinds.pretty(entry.modelData.key)
                        onClicked: page.editing = entry.modelData.id
                    }
                    // only the row being edited gets a recorder
                    Loader {
                        active: page.editing === entry.modelData.id
                        visible: active
                        anchors.verticalCenter: parent.verticalCenter
                        sourceComponent: Row {
                            spacing: Theme.u * 2
                            Recorder {
                                id: editRec
                                exceptId: entry.modelData.id
                                Component.onCompleted: load(entry.modelData.key)
                            }
                            PxButton {
                                compact: true
                                icon: "check"
                                accent: true
                                enabled: editRec.combo !== "" && !editRec.clash
                                onClicked: {
                                    Keybinds.apply([
                                        {
                                            "op": "set",
                                            "id": entry.modelData.id,
                                            "key": editRec.combo
                                        }
                                    ]);
                                    page.editing = -1;
                                }
                            }
                            PxButton {
                                compact: true
                                icon: "close"
                                onClicked: page.editing = -1
                            }
                            PxText {
                                visible: !!editRec.clash
                                anchors.verticalCenter: parent.verticalCenter
                                text: editRec.clash ? I18n.t("⚠ занято: ", "⚠ used by: ") + Keybinds.describe(editRec.clash).label : ""
                                color: Theme.danger
                                kind: "tiny"
                            }
                        }
                    }
                    Row {
                        id: rowInfo
                        visible: page.editing !== entry.modelData.id
                        anchors.left: keyChip.right
                        anchors.leftMargin: Theme.u * 5
                        anchors.right: del.left
                        anchors.rightMargin: Theme.u * 3
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.u * 3
                        Item {
                            width: Theme.u * 9
                            height: Theme.u * 9
                            anchors.verticalCenter: parent.verticalCenter
                            AppIcon {
                                visible: entry.info.appId !== ""
                                anchors.centerIn: parent
                                appId: entry.info.appId
                                size: Theme.u * 9
                            }
                            PxIcon {
                                visible: entry.info.appId === ""
                                anchors.centerIn: parent
                                name: entry.info.icon
                            }
                        }
                        Column {
                            width: rowInfo.width - Theme.u * 12
                            anchors.verticalCenter: parent.verticalCenter
                            PxText {
                                width: parent.width
                                text: entry.info.label
                                elide: Text.ElideRight
                            }
                            PxText {
                                width: parent.width
                                visible: entry.info.detail !== entry.info.label
                                text: entry.info.detail + (entry.modelData.editable ? "" : I18n.t("  · правится только в файле", "  · edit it in the file"))
                                kind: "tiny"
                                dim: true
                                elide: Text.ElideMiddle
                            }
                        }
                    }
                    PxButton {
                        id: del
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        compact: true
                        flat: true
                        danger: true
                        icon: "trash"
                        visible: entry.modelData.editable && page.editing !== entry.modelData.id
                        enabled: !Keybinds.busy
                        onClicked: Keybinds.apply([
                            {
                                "op": "delete",
                                "id": entry.modelData.id
                            }
                        ])
                    }
                }
            }
        }
    }
}
