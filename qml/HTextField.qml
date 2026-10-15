import QtQuick 2.6
import "."

Item {
    id: field
    property alias text: input.text
    property string placeholder
    property alias inputMethodHints: input.inputMethodHints
    signal accepted

    width: parent ? parent.width : 0
    height: 56 * Theme.u

    HFrame {
        anchors.fill: parent
        name: input.activeFocus ? "meegotouch-textedit-inverted-background-selected" : "meegotouch-textedit-inverted-background"
        border: 20
    }
    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: Theme.spacing
        anchors.rightMargin: Theme.spacing
        verticalAlignment: TextInput.AlignVCenter
        // The Harmattan text field is light even in the inverted theme, so
        // the text is dark there (COLOR_FOREGROUND).
        color: Theme.fieldText
        selectionColor: Theme.highlight
        selectedTextColor: "#FFFFFF"
        cursorDelegate: Rectangle { width: Math.max(2, 2 * Theme.u); color: Theme.highlight }
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontDefault
        clip: true
        onAccepted: field.accepted()
    }
    HLabel {
        anchors.fill: input
        verticalAlignment: Text.AlignVCenter
        visible: input.text.length === 0 && !input.activeFocus
        text: field.placeholder
        color: Theme.fieldPlaceholder
        wrapMode: Text.NoWrap
        elide: Text.ElideRight
    }
}
