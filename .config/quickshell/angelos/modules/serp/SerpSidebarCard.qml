import QtQuick
import qs.services

// serp-skin: a block of the skin's sidebar (SerpSidebarPanel) — a rounded surface0 card, a small
// header in the skin's text, the block's content in a column under it
Rectangle {
    id: card
    property string title: ""
    default property alias content: body.data
    radius: Serp.radius
    color: Serp.surface0
    border.width: 1
    border.color: Qt.tint(Serp.base, Qt.alpha(Serp.text, 0.12))  // opaque: blur noise showed through the clear line
    implicitHeight: inner.implicitHeight + Serp.px(24)
    height: visible ? implicitHeight : 0

    Column {
        id: inner
        x: Serp.px(12)
        y: Serp.px(12)
        width: card.width - Serp.px(24)
        spacing: Serp.px(8)
        SText {
            visible: card.title !== ""
            width: parent.width
            text: card.title
            size: Serp.smallSize
            bold: true
            dim: true
        }
        Column {
            id: body
            width: parent.width
            spacing: Serp.px(8)
        }
    }
}
