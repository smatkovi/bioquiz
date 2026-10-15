import QtQuick 2.6
import "."

// Harmattan QueryDialog: dims the page, title, message, two buttons.
Item {
    id: query
    property string title
    property string message
    property string acceptText: Lang.t("Ja")
    property string rejectText: Lang.t("Abbrechen")
    signal accepted
    signal rejected

    anchors.fill: parent
    visible: false
    z: 900

    function open() { visible = true }

    Rectangle {
        anchors.fill: parent
        color: "#E0000000"
    }
    MouseArea {
        anchors.fill: parent // swallow taps on the page below
    }
    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width - 4 * Theme.margin, 600 * Theme.u)
        spacing: Theme.margin
        HLabel {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: query.title
            font.pixelSize: Theme.fontXLarge
            font.weight: Font.Light
        }
        HLabel {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: query.message
            color: Theme.secondaryText
            visible: text.length > 0
        }
        Item { width: 1; height: Theme.spacing }
        HButton {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 320 * Theme.u
            look: "accent"
            text: query.acceptText
            onClicked: { query.visible = false; query.accepted() }
        }
        HButton {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 320 * Theme.u
            text: query.rejectText
            onClicked: { query.visible = false; query.rejected() }
        }
    }
}
