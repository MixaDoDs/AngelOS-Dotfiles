import QtQuick
import qs.config
import qs.services

// serp-skin: «Restart the computer?» (modules/session/SessionConfirmCard) in Serpantinum's look.
// `host` is the card itself: its texts (say), its pick (current: Cancel first), its grace (a
// pointer resting where the yes appears picks nothing until `ready`), cancel() and confirm().
SerpDialog {
    id: root

    property var host: null
    readonly property var say: host ? host.say : ["", "", "", "power"]
    readonly property var lines: ({
            "logout": "log-out",
            "refresh": "refresh-cw",
            "power": "power"
        })

    icon: lines[say[3]] || "power"
    iconTint: Serp.red
    title: say[0]
    body: say[1]
    note: I18n.t("← → выбрать · Enter — выбранное · Esc — отмена", "← → pick · Enter: the picked one · Esc: cancel")
    cardWidth: Serp.px(400)
    current: host ? host.current : 0
    buttons: [
        {
            "label": I18n.t("Отмена", "Cancel")
        },
        {
            "label": say[2],
            "icon": lines[say[3]] || "power",
            "kind": "danger"
        }
    ]
    onDismissed: if (host)
        host.cancel()
    onPicked: i => {
        if (!host)
            return;
        if (i === 1)
            host.confirm();
        else
            host.cancel();
    }
    onHoveredButton: i => {
        if (!host)
            return;
        if (i === 0)
            host.current = 0;
        else if (host.ready)
            host.current = 1;
    }
}
