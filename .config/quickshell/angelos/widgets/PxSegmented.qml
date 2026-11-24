import QtQuick
import qs.config

// Row of toggle buttons; model: [{label, value, icon}]. In a settings row (a parent with
// fixedWidth, SettingRow's control column) the buttons wrap onto the next line when they don't
// fit (big fonts, a big art pixel) instead of running out of it.
Flow {
    id: root

    property var model: []
    property var currentValue
    property real buttonWidthLimit: 0
    signal activated(var value)

    spacing: Theme.u * 2
    readonly property real natural: {
        let w = 0, n = 0;
        for (const c of children)
            if (c.visible && c.checkable !== undefined) {
                w += c.implicitWidth;
                n++;
            }
        return w + Math.max(0, n - 1) * spacing;
    }
    width: parent && parent.fixedWidth === true ? Math.min(natural, parent.width) : natural

    Repeater {
        model: root.model
        PxButton {
            required property var modelData
            maxWidth: root.buttonWidthLimit
            text: modelData.label || ""
            icon: modelData.icon || ""
            checked: root.currentValue === modelData.value
            onClicked: {
                // the owner's binding (currentValue: Config.x, onActivated: Config.x = v)
                // updates it; assigning here first would break that binding and leave a
                // stale pick when the value later changes elsewhere (issue #15)
                const picked = modelData.value;
                root.activated(picked);
                if (root.currentValue !== picked)
                    root.currentValue = picked;
            }
        }
    }
}
