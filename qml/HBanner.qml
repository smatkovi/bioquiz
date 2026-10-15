import QtQuick 2.6
import "."

// Harmattan InfoBanner: slides in at the top for a few seconds.
Item {
    id: banner
    property string text
    width: parent ? Math.min(parent.width, Theme.maxColumn) : 0
    x: parent ? (parent.width - width) / 2 : 0
    height: label.implicitHeight + 2 * Theme.margin
    y: shown ? Theme.spacing : -height - Theme.margin
    z: 1000
    property bool shown: false

    Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }

    function show(message) {
        text = message
        shown = true
        hideTimer.restart()
    }

    HFrame {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacing
        anchors.rightMargin: Theme.spacing
        name: "meegotouch-notification-information-background"
        border: 16
    }
    HLabel {
        id: label
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 2 * Theme.margin
        anchors.rightMargin: 2 * Theme.margin
        anchors.verticalCenter: parent.verticalCenter
        text: banner.text
        font.pixelSize: Theme.fontSmall
    }
    MouseArea {
        anchors.fill: parent
        onClicked: banner.shown = false
    }
    Timer {
        id: hideTimer
        interval: 3500
        onTriggered: banner.shown = false
    }
}
