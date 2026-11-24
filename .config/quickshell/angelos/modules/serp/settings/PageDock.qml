import QtQuick
import qs.services
import qs.modules.serp

// serp-skin settings: Док — the skin's own dock
SPage {
    title: "Док"
    subtitle: "Док внизу экрана: закреплённые и запущенные приложения"

    SetRow {
        rowKey: "dock"
        icon: "app-window"
        title: "Док"
        desc: "Показывать док скина"
        STog {
            checked: Serp.cfg.dock
            onToggled: on => Serp.cfg.dock = on
        }
    }
    Column {
        width: parent.width
        spacing: Serp.px(8)
        opacity: Serp.cfg.dock ? 1 : 0.45
        enabled: Serp.cfg.dock
        Behavior on opacity {
            NumberAnimation {
                duration: Serp.normal
            }
        }
        SetRow {
            rowKey: "magnify"
            icon: "maximize-2"
            title: "Увеличение при наведении"
            desc: "Значки под курсором подрастают, как в macOS"
            STog {
                checked: Serp.cfg.dockMagnify
                onToggled: on => Serp.cfg.dockMagnify = on
            }
        }
        SetRow {
            rowKey: "autohide"
            icon: "minimize-2"
            title: "Автоскрытие"
            desc: "Док прячется и выезжает, когда курсор у нижнего края"
            STog {
                checked: Serp.cfg.dockAutohide
                onToggled: on => Serp.cfg.dockAutohide = on
            }
        }
        SetRow {
            rowKey: "running"
            icon: "activity"
            title: "Запущенные приложения"
            desc: "Незакреплённые окна после разделителя"
            STog {
                checked: Serp.cfg.dockRunning
                onToggled: on => Serp.cfg.dockRunning = on
            }
        }
        SetRow {
            rowKey: "size"
            icon: "scan"
            title: "Размер значков"
            desc: "От 32 до 64 px"
            SNumber {
                from: 32
                to: 64
                stepSize: 4
                value: Serp.cfg.dockSize
                suffix: " px"
                onPicked: v => Serp.cfg.dockSize = v
            }
        }
    }
}
