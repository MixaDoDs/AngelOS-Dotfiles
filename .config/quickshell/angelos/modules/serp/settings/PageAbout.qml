import QtQuick
import qs.services
import qs.modules.serp

// serp-skin settings: О скине — where it comes from
SPage {
    title: "О скине"

    Rectangle {
        property string rowKey: "about"
        width: parent.width
        height: body.height + Serp.px(40)
        radius: Serp.radius
        color: Qt.alpha(Serp.surface0, 0.4)
        Column {
            id: body
            x: Serp.px(20)
            y: Serp.px(20)
            width: parent.width - Serp.px(40)
            spacing: Serp.px(12)
            Row {
                spacing: Serp.px(14)
                Rectangle {
                    width: Serp.px(48)
                    height: width
                    radius: Serp.radiusSmall
                    color: Qt.alpha(Serp.accent, 0.16)
                    SIcon {
                        anchors.centerIn: parent
                        name: "angel"
                        size: Serp.px(28)
                        color: Serp.accent
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Serp.px(2)
                    SText {
                        text: "Serpantinum для angelOS"
                        size: Serp.px(16)
                        black: true
                    }
                    SText {
                        text: "локальный скин · не для публикации"
                        size: Serp.px(11)
                        color: Serp.subtext0
                    }
                }
            }
            SText {
                width: parent.width
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
                textFormat: Text.StyledText
                linkColor: Serp.accent
                text: "Вдохновлено оболочкой <b>Serpantinum</b> от ilyamiro (AGPL-3): " + "<a href=\"https://github.com/ilyamiro/serpantinum\">github.com/ilyamiro/serpantinum</a>. " + "Её облик собран здесь заново для angelOS: службы, окна, ореол и ангел остаются своими, " + "а скин отвечает только за панель, док, палитры и это окно."
                size: Serp.px(13)
                color: Serp.subtext1
                onLinkActivated: link => Qt.openUrlExternally(link)
                HoverHandler {
                    cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                }
            }
        }
    }
    SetRow {
        rowKey: "version"
        icon: "info"
        title: "Версия"
        desc: "serp-skin"
        SText {
            text: "0.1"
            bold: true
            color: Serp.accent
        }
    }
    SetRow {
        rowKey: "palettes"
        icon: "palette"
        title: "Палитры"
        desc: "Пресеты Serpantinum, angelOS и цвета из обоев"
        SText {
            text: String(Serp.paletteIds.length + 1)
            bold: true
        }
    }
}
