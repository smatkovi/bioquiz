import QtQuick 2.6
import "."

// Harmattan progress bar, used as the countdown of a question. Turns red for
// the last five seconds.
Item {
    id: bar
    property real value: 1.0      // 1 = full time left, 0 = time is up
    property bool urgent: false
    width: parent ? parent.width : 0
    height: 10 * Theme.u

    HFrame {
        anchors.fill: parent
        name: "meegotouch-progressindicator-inverted-bar-background"
        border: 4
    }
    Item {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width * Math.max(0, Math.min(1, bar.value))
        clip: true
        Image {
            visible: !bar.urgent
            width: bar.width / Theme.u
            height: bar.height / Theme.u
            scale: Theme.u
            transformOrigin: Item.TopLeft
            source: Theme.img + "meegotouch-progressindicator-inverted-bar-known-texture.png"
            fillMode: Image.TileHorizontally
        }
        Rectangle {
            visible: bar.urgent
            anchors.fill: parent
            radius: height / 2
            color: Theme.negative
        }
    }
}
