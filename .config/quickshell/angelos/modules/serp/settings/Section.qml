import QtQuick
import qs.services
import qs.modules.serp

// serp-skin settings: a group's caption inside a page (the search and the sidebar's sub-rows
// scroll to it by rowKey)
Item {
    id: sec
    property string rowKey: ""
    property string title: ""
    width: parent ? parent.width : 0
    height: Serp.px(34)
    SText {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Serp.px(4)
        x: Serp.px(4)
        text: sec.title
        size: Serp.px(12)
        bold: true
        color: Serp.subtext1
    }
}
