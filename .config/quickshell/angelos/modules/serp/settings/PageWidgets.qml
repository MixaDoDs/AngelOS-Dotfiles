import QtQuick
import qs.services
import qs.modules.serp

// serp-skin settings: Виджеты — angelOS's widgets wear the skin's look; adding / removing them is angelOS's
SPage {
    title: "Виджеты"
    subtitle: "Что живёт на рабочем столе"

    SetRow {
        rowKey: "more"
        icon: "layers"
        title: "Виджеты рабочего стола"
        desc: "Твои виджеты angelOS сами надевают облик Serpantinum; добавить или убрать — в настройках angelOS"
        PillButton {
            icon: "external-link"
            label: "Открыть"
            onClicked: {
                Serp.settingsOpen = false;
                Shell.openSettings("widgets", "");
            }
        }
    }
}
