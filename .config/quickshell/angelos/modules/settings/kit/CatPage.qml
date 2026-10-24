import QtQuick
import qs.config
import qs.services

// One settings page as data (modules/settings/catalog/<Name>.qml): its groups (CatGroup) of
// settings (CatToggle, CatChoice, …) and whatever state, processes and helpers the page needs.
// It draws nothing: a look renders it — the angelOS/Mac/hell looks through CatalogPage, the
// P5 window through its own rows. A look puts the page inside itself (invisible), so lookups
// up the parents (the window's place, its skin) work from here as from a page; the custom
// parts (CatCustom) are moved into the look's rows while shown.
Item {
    id: root

    property string heading: ""
    property string subtitle: ""
    // what PxPage gave the old pages, for the code that came along with them
    property var host: null                 // the look rendering it (CatalogPage), if any
    readonly property var view: Shell.settingsViewFor(root.parent)
    readonly property var nav: Shell.settingsNavFor(root.parent)
    // the page is on screen (the look rendering it is): what a page's own `visible` said
    readonly property bool showing: !!host && host.visible
    readonly property real innerWidth: host ? host.innerWidth : Theme.u * 240
    readonly property real contentY: host && host.contentY !== undefined ? host.contentY : 0
    function scrollBy(dy) {
        if (host && host.scrollBy)
            host.scrollBy(dy);
    }
    readonly property var parts: Array.prototype.filter.call(children, c => c.isCatGroup === true || c.kind === "custom")

    visible: false
    width: innerWidth
}
