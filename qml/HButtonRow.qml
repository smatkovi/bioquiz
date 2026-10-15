import QtQuick 2.6
import "."

// Harmattan ButtonRow: segmented exclusive buttons.
Item {
    id: row
    property var model: []
    property int currentIndex: 0
    signal picked(int index)

    width: parent ? parent.width : 0
    height: Theme.buttonHeight

    Row {
        anchors.fill: parent
        Repeater {
            model: row.model
            Item {
                width: row.width / row.model.length
                height: row.height
                property string segment: row.model.length === 1 ? "" : index === 0 ? "-horizontal-left"
                                     : index === row.model.length - 1 ? "-horizontal-right" : "-horizontal-center"
                HFrame {
                    anchors.fill: parent
                    name: "meegotouch-button-inverted-background"
                          + (index === row.currentIndex ? "-selected" : (seg.pressed ? "-pressed" : "")) + parent.segment
                }
                HLabel {
                    anchors.centerIn: parent
                    text: modelData
                    font.bold: true
                    font.pixelSize: Theme.fontSmall
                }
                MouseArea {
                    id: seg
                    anchors.fill: parent
                    onClicked: { row.currentIndex = index; row.picked(index) }
                }
            }
        }
    }
}
