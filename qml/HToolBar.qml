import QtQuick 2.6
import "."

// Harmattan bottom tool bar: back on the left, page tools on the right.
Item {
    id: bar
    property bool backVisible: true
    property alias toolRow: right
    signal back

    width: parent ? parent.width : 0
    height: Theme.toolbarHeight

    Image {
        anchors.fill: parent
        source: Theme.img + "meegotouch-toolbar-portrait-inverted-background.png"
    }
    HToolIcon {
        anchors.left: parent.left
        visible: bar.backVisible
        icon: "icon-m-toolbar-back-white"
        onClicked: bar.back()
    }
    Row {
        id: right
        anchors.right: parent.right
        height: parent.height
    }
}
