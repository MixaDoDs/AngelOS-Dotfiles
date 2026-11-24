import QtQuick
import qs.services
import qs.modules.serp

// serp-skin settings: the welcome page — what the skin is and the way back
SPage {
    id: pg
    title: "Добро пожаловать"
    subtitle: "Скин Serpantinum поверх angelOS"

    Rectangle {
        width: parent.width
        height: hero.height + Serp.px(48)
        radius: Serp.radius
        color: Qt.alpha(Serp.surface0, 0.4)
        Column {
            id: hero
            anchors.centerIn: parent
            width: parent.width - Serp.px(48)
            spacing: Serp.px(12)
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Serp.px(72)
                height: width
                radius: width / 2
                color: Qt.alpha(Serp.accent, 0.16)
                SIcon {
                    anchors.centerIn: parent
                    name: "angel"
                    size: Serp.px(40)
                    color: Serp.accent
                }
            }
            SText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "angelOS · Serpantinum"
                size: Serp.px(24)
                black: true
            }
            SText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "Острова, док и палитры Serpantinum, а под ними всё то же angelOS: его службы, окна, ореол и ангел."
                size: Serp.px(13)
                color: Serp.subtext1
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Serp.px(10)
                PillButton {
                    rowKey: "classic"
                    icon: "undo-2"
                    label: "Вернуться на Classic"
                    onClicked: {
                        Serp.settingsOpen = false;
                        Serp.setSkin("classic");
                    }
                }
                PillButton {
                    rowKey: "angelos"
                    primary: true
                    icon: "settings"
                    label: "Настройки angelOS"
                    onClicked: {
                        Serp.settingsOpen = false;
                        Shell.openSettings("", "");
                    }
                }
            }
        }
    }

    Section {
        title: "Что умеет"
    }
    Repeater {
        model: [
            {
                "icon": "layout-dashboard",
                "t": "Панель-острова",
                "d": "часы, погода, сейчас играет и столы пилюлями или цифрами"
            },
            {
                "icon": "app-window",
                "t": "Свой док",
                "d": "увеличение при наведении, автоскрытие и запущенные приложения"
            },
            {
                "icon": "palette",
                "t": Serp.paletteIds.length + " палитр и цвета из обоев",
                "d": "всё окно перекрашивается сразу, без перезапуска"
            },
            {
                "icon": "type",
                "t": "Шрифт, скругление и прозрачность",
                "d": "внешний вид островов, панелей и этого окна"
            },
            {
                "icon": "search",
                "t": "Поиск по настройкам",
                "d": "просто начни печатать, Enter прыгает к нужной строке"
            },
            {
                "icon": "clock",
                "t": "Волнистые часы",
                "d": "аналоговый виджет на рабочем столе"
            }
        ]
        delegate: SetRow {
            required property var modelData
            icon: modelData.icon
            title: modelData.t
            desc: modelData.d
        }
    }
}
