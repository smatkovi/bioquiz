import QtQuick 2.6
import "."

// Harmattan button (inverted theme). `look`: normal, accent (blue),
// positive (green), negative (red), selected (blue, pressed-in).
Item {
    id: button
    property string text
    property string look: "normal"
    property real fontSize: Theme.fontDefault
    property bool bold: true
    property int maxLines: 3
    property alias pressed: mouse.pressed
    signal clicked

    implicitHeight: Theme.buttonHeight
    implicitWidth: Math.max(label.implicitWidth + 4 * Theme.margin, 220 * Theme.u)
    opacity: enabled ? 1.0 : 0.6

    function frameName() {
        var base = "meegotouch-button-"
        if (look === "positive")
            return base + "positive-inverted-background"
        if (look === "negative")
            return base + "negative-inverted-background"
        if (look === "selected")
            return base + "inverted-background-selected"
        if (look === "accent") {
            if (!enabled) return base + "accent-inverted-background-disabled"
            return base + (mouse.pressed ? "accent-inverted-background-pressed" : "accent-inverted-background")
        }
        if (!enabled) return base + "inverted-background-disabled"
        return base + (mouse.pressed ? "inverted-background-pressed" : "inverted-background")
    }

    HFrame {
        anchors.fill: parent
        name: button.frameName()
    }

    HLabel {
        id: label
        anchors.fill: parent
        anchors.leftMargin: Theme.margin
        anchors.rightMargin: Theme.margin
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: button.text
        font.pixelSize: button.fontSize
        font.bold: button.bold
        maximumLineCount: button.maxLines
        elide: Text.ElideRight
        fontSizeMode: Text.Fit
        minimumPixelSize: Theme.fontXXSmall
        color: button.enabled ? Theme.text : Theme.dimText
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: button.enabled
        onClicked: button.clicked()
    }
}
