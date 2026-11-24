import QtQuick
import qs.services

// serp-skin: a card on a panel — surface0, the skin's radius, a hair of a line
Rectangle {
    radius: Serp.radius
    color: Serp.surface0
    border.width: 1
    border.color: Qt.tint(Serp.base, Qt.alpha(Serp.text, 0.12))  // opaque: blur noise showed through the clear line
}
