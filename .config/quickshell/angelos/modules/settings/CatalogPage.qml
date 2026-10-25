pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings.kit

// A page of the settings catalog (modules/settings/catalog/<Name>.qml) in the looks that draw
// settings with the pixel widgets — angelOS, Golden Gate, hell's dresses, the setup wizard:
// every group a PxGroup, every entry a SettingRow with its control, bound both ways to the
// entry. ComposedPage and the wizard load it as they loaded a page file (embedded, only, …).
PxPage {
    id: root

    property string catalog: ""
    property var cat: null
    heading: cat && !embedded ? cat.heading : ""
    subtitle: cat ? cat.subtitle : ""

    Component.onCompleted: {
        const c = Qt.createComponent(Qt.resolvedUrl("catalog/" + catalog + ".qml"));
        if (c.status !== Component.Ready) {
            console.warn("CatalogPage: " + catalog + ": " + c.errorString());
            return;
        }
        cat = c.createObject(root, {
            "host": root
        });
    }

    // ---- a row's control, bound to its entry ----
    component Actions: Repeater {
        id: acts
        property var entry: null
        property bool lead: false
        model: entry ? entry.actions.filter(a => a.lead === acts.lead) : []
        PxButton {
            required property var modelData
            compact: modelData.compact
            text: modelData.text
            icon: modelData.icon
            accent: modelData.accent
            danger: modelData.danger
            checkable: modelData.checkable
            checked: modelData.checked
            enabled: modelData.enabled
            visible: modelData.present
            onClicked: modelData.clicked()
        }
    }
    component Row: SettingRow {
        id: row
        required property var entry
        label: entry.label
        hint: entry.hint
        preview: entry.preview
        visible: entry.present
        enabled: entry.enabled
        opacity: entry.fade
        Connections {
            target: row.entry
            function onShowPreview(value, caption) {
                row.show(value, caption);
            }
        }
    }
    component ToggleRow: Row {
        id: r
        Flow {
            width: parent.width
            spacing: Theme.u * 3
            Actions {
                entry: r.entry
                lead: true
            }
            PxToggle {
                checked: r.entry.checked
                text: r.entry.text
                onToggled: c => r.entry.toggled(c)
            }
            Actions {
                entry: r.entry
            }
        }
    }
    component ChoiceRow: Row {
        id: r
        Flow {
            width: parent.width
            spacing: Theme.u * 3
            // the buttons wrap onto the next line when they don't fit (PxSegmented), not cut
            readonly property bool fixedWidth: true
            Actions {
                entry: r.entry
                lead: true
            }
            PxSegmented {
                visible: !r.entry.combo
                model: r.entry.combo ? [] : r.entry.model
                currentValue: r.entry.currentValue
                onActivated: v => r.entry.activated(v)
            }
            PxCombo {
                visible: r.entry.combo
                width: r.entry.actions.length ? Math.min(parent.width / 2, Theme.u * 110) : Math.min(parent.width, Theme.u * 140)
                model: r.entry.combo ? r.entry.model : []
                currentValue: r.entry.currentValue
                placeholder: r.entry.placeholder
                onActivated: v => r.entry.activated(v)
            }
            Actions {
                entry: r.entry
            }
        }
    }
    component SliderRow: Row {
        id: r
        Flow {
            width: parent.width
            spacing: Theme.u * 3
            Actions {
                entry: r.entry
                lead: true
            }
            PxSlider {
                width: r.entry.actions.length ? parent.width - Theme.u * 24 * r.entry.actions.length : parent.width
                from: r.entry.from
                to: r.entry.to
                value: r.entry.value
                stepSize: r.entry.stepSize
                live: r.entry.live
                suffix: r.entry.suffix
                decimals: r.entry.decimals
                showValue: r.entry.showValue
                valueScale: r.entry.valueScale
                fill: r.entry.fill
                onMoved: v => r.entry.moved(v)
                onReleased: v => r.entry.released(v)
            }
            Actions {
                entry: r.entry
            }
        }
    }
    component SpinRow: Row {
        id: r
        Flow {
            width: parent.width
            spacing: Theme.u * 3
            Actions {
                entry: r.entry
                lead: true
            }
            PxSpin {
                value: r.entry.value
                from: r.entry.from
                to: r.entry.to
                stepSize: r.entry.stepSize
                decimals: r.entry.decimals
                suffix: r.entry.suffix
                onMoved: v => r.entry.moved(v)
            }
            Actions {
                entry: r.entry
            }
        }
    }
    component FieldRow: Row {
        id: r
        Flow {
            width: parent.width
            spacing: Theme.u * 3
            Actions {
                entry: r.entry
                lead: true
            }
            PxField {
                width: r.entry.actions.length ? Math.max(Theme.u * 60, parent.width - Theme.u * 50 * r.entry.actions.length) : parent.width
                text: r.entry.text
                placeholder: r.entry.placeholder
                password: r.entry.password
                icon: r.entry.icon
                onEdited: r.entry.edit(text)
                onAccepted: r.entry.accepted()
                onEditingFinished: {
                    r.entry.editingFinished();
                    r.entry.release();
                }
            }
            Actions {
                entry: r.entry
            }
        }
    }
    component ButtonRow: Row {
        id: r
        Flow {
            width: parent.width
            spacing: Theme.u * 3
            Actions {
                entry: r.entry
                lead: true
            }
            PxButton {
                compact: r.entry.compact
                text: r.entry.text
                icon: r.entry.icon
                accent: r.entry.accent
                danger: r.entry.danger
                checkable: r.entry.checkable
                checked: r.entry.checked
                onClicked: r.entry.clicked()
            }
            Actions {
                entry: r.entry
            }
        }
    }
    // a button row without a label: the buttons across the group
    component Buttons: Flow {
        id: b
        required property var entry
        visible: entry.present
        enabled: entry.enabled
        width: parent.width
        spacing: Theme.u * 3
        Actions {
            entry: b.entry
            lead: true
        }
        PxButton {
            compact: b.entry.compact
            text: b.entry.text
            icon: b.entry.icon
            accent: b.entry.accent
            danger: b.entry.danger
            checkable: b.entry.checkable
            checked: b.entry.checked
            onClicked: b.entry.clicked()
        }
        Actions {
            entry: b.entry
        }
    }
    component LinkRow: SettingLink {
        required property var entry
        label: entry.label
        hint: entry.hint
        page: entry.page
        group: entry.group
        visible: entry.present
    }
    component Note: PxText {
        required property var entry
        width: parent.width
        wrapMode: Text.Wrap
        text: entry.text
        dim: entry.dim
        // an explanation as small as a line's hint (decision №22, 25.10)
        kind: entry.dim && entry.textKind === "body" ? "tiny" : entry.textKind
        visible: entry.present
    }
    component CustomRow: Row {
        id: r
        CatHost {
            entry: r.entry
        }
    }
    component Wide: CatHost {
        visible: !!entry && entry.present
        enabled: !entry || entry.enabled
    }

    // one entry in its group's column
    component Entry: Loader {
        id: slot
        required property var modelData
        readonly property bool catRow: true
        readonly property bool fixedWidth: true
        // PxGroup's summary of a folded card reads its rows' names
        readonly property string label: modelData.label
        readonly property string hint: modelData.hint
        // the row's «new» star (SettingsNews): what finds a row by its name finds this slot
        readonly property bool isNew: !!item && item.isNew === true
        width: parent ? parent.width : 0
        visible: modelData.present
        sourceComponent: {
            const k = modelData.kind;
            if (k === "custom")
                return modelData.wide || !modelData.label ? wide : customRow;
            if (k === "button")
                return modelData.label ? buttonRow : buttons;
            return ({
                    "toggle": toggleRow,
                    "choice": choiceRow,
                    "slider": sliderRow,
                    "spin": spinRow,
                    "field": fieldRow,
                    "link": linkRow,
                    "note": note
                })[k] || null;
        }
        onLoaded: item.entry = modelData
        Component {
            id: toggleRow
            ToggleRow {
                entry: slot.modelData
            }
        }
        Component {
            id: choiceRow
            ChoiceRow {
                entry: slot.modelData
            }
        }
        Component {
            id: sliderRow
            SliderRow {
                entry: slot.modelData
            }
        }
        Component {
            id: spinRow
            SpinRow {
                entry: slot.modelData
            }
        }
        Component {
            id: fieldRow
            FieldRow {
                entry: slot.modelData
            }
        }
        Component {
            id: buttonRow
            ButtonRow {
                entry: slot.modelData
            }
        }
        Component {
            id: buttons
            Buttons {
                entry: slot.modelData
            }
        }
        Component {
            id: linkRow
            LinkRow {
                entry: slot.modelData
            }
        }
        Component {
            id: note
            Note {
                entry: slot.modelData
            }
        }
        Component {
            id: customRow
            CustomRow {
                entry: slot.modelData
            }
        }
        Component {
            id: wide
            Wide {
                entry: slot.modelData
            }
        }
    }

    // the groups in order; what sat outside them on the page is a bare group (no card)
    Repeater {
        model: root.cat ? root.cat.parts : []
        PxGroup {
            id: part
            required property var modelData
            readonly property bool isGroup: modelData.isCatGroup === true
            bare: !isGroup
            name: isGroup ? modelData.name : ""
            title: isGroup ? modelData.title : ""
            icon: isGroup ? modelData.icon : ""
            advanced: isGroup && modelData.advanced
            wide: isGroup && modelData.wide
            shown: modelData.present
            enabled: modelData.enabled
            width: parent ? parent.width : 0
            Repeater {
                model: part.isGroup ? part.modelData.entries : [part.modelData]
                Entry {}
            }
        }
    }
}
