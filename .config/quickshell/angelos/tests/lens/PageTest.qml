// tests/lens/run.sh: scripts/lens/page.js over two pages made after the spec (visual.html, the
// "All" tab; exact.html, the exact matches) in a hidden QtWebEngine view, no network; prints
// "PAGE {json}" lines the runner checks
import QtQuick
import QtQuick.Window
import QtWebEngine

Window {
    id: win
    width: 960
    height: 640
    visible: false

    readonly property string dir: Qt.resolvedUrl(".").toString()
    function read(url) {
        const x = new XMLHttpRequest();
        x.open("GET", url, false);
        x.send();
        return x.responseText;
    }
    readonly property string pageJs: read(Qt.resolvedUrl("../../scripts/lens/page.js").toString())
    property var pages: [["visual", "visual.html", "__aosLens.results()"], ["exact", "exact.html", "__aosLens.exact()"]]
    property int at: 0

    function load() {
        view.url = dir + pages[at][1];
    }
    WebEngineView {
        id: view
        anchors.fill: parent
        onLoadingChanged: info => {
            if (info.status !== WebEngineView.LoadSucceededStatus)
                return;
            const p = win.pages[win.at];
            runJavaScript(win.pageJs + "\n" + p[2], WebEngineScript.ApplicationWorld, r => {
                console.warn("PAGE " + JSON.stringify({
                    "page": p[0],
                    "out": JSON.parse(r)
                }));
                if (++win.at < win.pages.length)
                    win.load();
                else
                    Qt.quit();
            });
        }
    }
    Component.onCompleted: load()
}
