import QtQuick
import qs.services

// serp-skin: a device's line icon (services/Peripherals kinds) in the skin's look — Lucide's own
// shapes (ISC), the ones angelOS's line set lacks (headphones above all) included, drawn as SVG
// at its size in any colour, as SIcon draws the rest.
Image {
    id: root

    property string kind: "other"
    property color color: Serp.text
    property real size: Serp.px(15)
    property real stroke: 2

    readonly property var paths: ({
            "headset": '<path d="M3 14h3a2 2 0 0 1 2 2v3a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-7a9 9 0 0 1 18 0v7a2 2 0 0 1-2 2h-1a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2h3"/>',
            "mouse": '<rect x="5" y="2" width="14" height="20" rx="7"/><path d="M12 6v4"/>',
            "keyboard": '<rect width="20" height="16" x="2" y="4" rx="2"/><path d="M6 8h.01M10 8h.01M14 8h.01M18 8h.01M8 12h.01M12 12h.01M16 12h.01M7 16h10"/>',
            "gamepad": '<path d="M6 11h4M8 9v4M15 12h.01M18 10h.01"/><path d="M17.32 5H6.68a4 4 0 0 0-3.98 3.59C2.6 9.42 2 14.46 2 16a3 3 0 0 0 3 3c1 0 1.5-.5 2-1l1.41-1.41A2 2 0 0 1 9.83 16h4.34a2 2 0 0 1 1.41.59L17 18c.5.5 1 1 2 1a3 3 0 0 0 3-3c0-1.55-.6-6.58-.69-7.26A4 4 0 0 0 17.32 5z"/>',
            "phone": '<rect width="14" height="20" x="5" y="2" rx="2"/><path d="M12 18h.01"/>',
            "pen": '<path d="M21.17 6.81a1 1 0 0 0-3.98-3.98L3.84 16.17a2 2 0 0 0-.5.83l-1.32 4.35a.5.5 0 0 0 .62.62l4.35-1.32a2 2 0 0 0 .83-.5z"/>',
            "speaker": '<rect width="16" height="20" x="4" y="2" rx="2"/><circle cx="12" cy="14" r="4"/><path d="M12 6h.01"/>',
            "touchpad": '<rect width="20" height="16" x="2" y="4" rx="2"/><path d="M2 14h20M12 14v6"/>',
            "other": '<path d="M12 22v-5M9 8V2M15 8V2M18 8v5a4 4 0 0 1-4 4h-4a4 4 0 0 1-4-4V8z"/>'
        })
    readonly property string rgb: "#" + [color.r, color.g, color.b].map(c => ("0" + Math.round(c * 255).toString(16)).slice(-2)).join("")

    width: size
    height: size
    sourceSize.width: Math.ceil(size)
    sourceSize.height: Math.ceil(size)
    opacity: color.a
    smooth: true
    asynchronous: false
    source: "data:image/svg+xml;utf8," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="' + rgb + '" stroke-width="' + stroke + '" stroke-linecap="round" stroke-linejoin="round">' + (paths[kind] || paths.other) + '</svg>')
}
