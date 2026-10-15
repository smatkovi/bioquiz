import QtQuick 2.6
import "."

// The page header of Harmattan apps: dark bar, title in Nokia Pure Text
// Light 32 px. With `accent` set it becomes the coloured header bar that
// apps like Store or Feeds used.
Item {
    id: header
    property string title
    property string subtitle
    property color accent: "transparent"

    width: parent ? parent.width : 0
    height: Theme.headerHeight

    Image {
        anchors.fill: parent
        source: Theme.img + "meegotouch-view-header-inverted.png"
        visible: header.accent.a === 0
    }
    Rectangle {
        anchors.fill: parent
        visible: header.accent.a > 0
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.lighter(header.accent, 1.18) }
            GradientStop { position: 1.0; color: Qt.darker(header.accent, 1.18) }
        }
    }

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.margin
        anchors.rightMargin: Theme.margin
        anchors.verticalCenter: parent.verticalCenter
        HLabel {
            width: parent.width
            text: header.title
            font.pixelSize: Theme.fontXLarge
            font.weight: Font.Light
            elide: Text.ElideRight
            maximumLineCount: 1
        }
        HLabel {
            width: parent.width
            visible: header.subtitle.length > 0
            text: header.subtitle
            font.pixelSize: Theme.fontXSmall
            color: header.accent.a > 0 ? "#E6FFFFFF" : Theme.secondaryText
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }
}
