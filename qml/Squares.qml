import QtQuick 2.6
import "."

// The three result boxes of one player in one round: green right, red
// wrong, grey not played yet, dark with "?" when played but still hidden
// (Quizduell only reveals the others' answers once you played the round).
Row {
    id: squares
    property var picks: null       // array of original answer indices, or null
    property bool hidden: false
    property int count: 3
    property real size: 22 * Theme.u
    spacing: 5 * Theme.u

    Repeater {
        model: squares.count
        Image {
            width: squares.size
            height: squares.size
            property int pick: squares.picks && index < squares.picks.length ? squares.picks[index] : -9
            source: "qrc:/ui/squircle-" + (squares.picks === null ? "empty"
                                         : squares.hidden ? "hidden"
                                         : pick === 0 ? "right" : "wrong") + ".png"
            sourceSize.width: 64
            sourceSize.height: 64
            smooth: true
            HLabel {
                anchors.centerIn: parent
                visible: squares.picks !== null && squares.hidden
                text: "?"
                font.pixelSize: squares.size * 0.7
                font.bold: true
                color: "#BBBBBB"
                wrapMode: Text.NoWrap
            }
        }
    }
}
