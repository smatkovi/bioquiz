import QtQuick 2.6
import "."

Item {
    id: tool
    property string icon
    signal clicked

    width: 80 * Theme.u
    height: Theme.toolbarHeight

    // Pressed: the blue Nokia squircle, as in the harmattan-openbox theme.
    Image {
        anchors.centerIn: parent
        width: 60 * Theme.u
        height: width
        source: "qrc:/ui/squircle-highlight.png"
        sourceSize.width: 128
        sourceSize.height: 128
        smooth: true
        visible: mouse.pressed
    }
    Image {
        anchors.centerIn: parent
        source: Theme.img + tool.icon + ".png"
        width: sourceSize.width * Theme.u
        height: sourceSize.height * Theme.u
        smooth: true
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        onClicked: tool.clicked()
    }
}
