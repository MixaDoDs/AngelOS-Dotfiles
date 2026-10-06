import QtQuick
import qs.services

// A found file's picture (FileSearch): the thumbnail cache, else the picture itself; `ok` false
// = none (a folder, a song, no thumbnail yet, previews off) and the caller shows its icon
Item {
    id: root
    property var hit: null
    property int decode: 96            // decode at most this many pixels a side
    property bool crop: true           // fill the square; false fits it whole (the preview)
    readonly property bool ok: img.status === Image.Ready
    readonly property var candidates: FileSearch.preview ? FileSearch.thumbs(hit) : []
    property int attempt: 0
    onCandidatesChanged: attempt = 0

    Image {
        id: img
        anchors.fill: parent
        visible: root.ok
        asynchronous: true
        smooth: true
        fillMode: root.crop ? Image.PreserveAspectCrop : Image.PreserveAspectFit
        sourceSize: Qt.size(root.decode, root.decode)
        source: root.attempt < root.candidates.length ? root.candidates[root.attempt] : ""
        onStatusChanged: if (status === Image.Error)
            root.attempt++
    }
}
