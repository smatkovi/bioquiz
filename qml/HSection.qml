import QtQuick 2.6
import "."

// Harmattan group header: thin line, label on the right.
Item {
    id: section
    property string text
    width: parent ? parent.width : 0
    height: 48 * Theme.u

    HLabel {
        id: label
        anchors.right: parent.right
        anchors.rightMargin: Theme.margin
        anchors.verticalCenter: parent.verticalCenter
        text: section.text
        font.pixelSize: Theme.fontXSmall
        font.bold: true
        color: Theme.dimText
        wrapMode: Text.NoWrap
    }
    Image {
        anchors.left: parent.left
        anchors.leftMargin: Theme.margin
        anchors.right: label.left
        anchors.rightMargin: Theme.spacing
        anchors.verticalCenter: parent.verticalCenter
        height: 2 * Theme.u
        source: Theme.img + "meegotouch-groupheader-inverted-background.png"
        fillMode: Image.Stretch
    }
}
