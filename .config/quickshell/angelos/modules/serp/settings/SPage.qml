import QtQuick
import qs.services
import qs.modules.serp

// serp-skin settings: one page of the window — a title, then its rows in a scrolling column.
// flash(key) scrolls to the row with that rowKey and lights it up.
Flickable {
    id: page
    property string title: ""
    property string subtitle: ""
    default property alias content: col.data
    readonly property int pad: Serp.px(24)
    clip: true
    contentWidth: width
    contentHeight: col.y + col.implicitHeight + pad
    boundsBehavior: Flickable.StopAtBounds

    function find(item, key) {
        for (let i = 0; i < item.children.length; i++) {
            const c = item.children[i];
            if (c.rowKey === key)
                return c;
            const deeper = find(c, key);
            if (deeper)
                return deeper;
        }
        return null;
    }
    function flash(key) {
        const it = key ? find(col, key) : null;
        if (!it)
            return;
        const y = it.mapToItem(col, 0, 0).y + col.y - Serp.px(12);
        scroll.to = Math.max(0, Math.min(contentHeight - height, y));
        scroll.restart();
        if (typeof it.flash === "function")
            it.flash();
    }
    NumberAnimation {
        id: scroll
        target: page
        property: "contentY"
        duration: Serp.slow
        easing.type: Easing.OutQuint
    }

    Column {
        id: head
        x: page.pad
        y: page.pad
        width: page.width - page.pad * 2
        spacing: Serp.px(4)
        SText {
            width: parent.width
            text: page.title
            size: Serp.px(22)
            black: true
        }
        SText {
            width: parent.width
            visible: text !== ""
            text: page.subtitle
            size: Serp.px(12)
            color: Serp.subtext0
            wrapMode: Text.WordWrap
        }
    }
    Column {
        id: col
        x: page.pad
        y: head.y + head.height + Serp.px(18)
        width: page.width - page.pad * 2
        spacing: Serp.px(8)
    }

    // a hair of a scrollbar while the page is longer than the window
    Rectangle {
        visible: page.contentHeight > page.height
        parent: page
        x: page.width - Serp.px(6)
        width: Serp.px(3)
        radius: width / 2
        height: Math.max(Serp.px(30), page.height * page.height / page.contentHeight)
        y: (page.height - height) * page.contentY / Math.max(1, page.contentHeight - page.height)
        color: Qt.alpha(Serp.text, page.moving ? 0.3 : 0.12)
        Behavior on color {
            ColorAnimation {
                duration: Serp.normal
            }
        }
    }
}
