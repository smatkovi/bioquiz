import QtQuick 2.6
import "."

// Two-line Harmattan list item: bold title, light subtitle, optional icon on
// the left and the drill-down arrow on the right.
Item {
    id: item
    property string title
    property string subtitle
    property string icon
    property bool drilldown: true
    property color titleColor: Theme.text
    signal clicked

    width: parent ? parent.width : 0
    height: subtitle.length > 0 || icon.length > 0 ? Theme.listItemHeight : 72 * Theme.u
    opacity: enabled ? 1.0 : 0.45

    HFrame {
        anchors.fill: parent
        visible: mouse.pressed
        name: "meegotouch-list-fullwidth-inverted-background-pressed"
        border: 8
    }

    Image {
        id: iconImage
        anchors.left: parent.left
        anchors.leftMargin: Theme.margin
        anchors.verticalCenter: parent.verticalCenter
        visible: item.icon.length > 0
        source: item.icon
        width: 64 * Theme.u
        height: width
        sourceSize.width: 128
        sourceSize.height: 128
        smooth: true
        mipmap: true
    }

    Column {
        anchors.left: iconImage.visible ? iconImage.right : parent.left
        anchors.leftMargin: Theme.margin
        anchors.right: arrow.visible ? arrow.left : parent.right
        anchors.rightMargin: Theme.margin
        anchors.verticalCenter: parent.verticalCenter
        HLabel {
            width: parent.width
            text: item.title
            font.pixelSize: 26 * Theme.u
            font.bold: true
            color: item.titleColor
            elide: Text.ElideRight
            maximumLineCount: 1
        }
        HLabel {
            width: parent.width
            visible: item.subtitle.length > 0
            text: item.subtitle
            font.pixelSize: 22 * Theme.u
            font.weight: Font.Light
            color: Theme.secondaryText
            elide: Text.ElideRight
            maximumLineCount: 2
        }
    }

    Image {
        id: arrow
        anchors.right: parent.right
        anchors.rightMargin: Theme.margin
        anchors.verticalCenter: parent.verticalCenter
        visible: item.drilldown
        source: Theme.img + "icon-m-common-drilldown-arrow-inverse.png"
        width: 32 * Theme.u
        height: width
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: item.enabled
        onClicked: item.clicked()
    }
}
