import QtQuick 2.6
import "."

HPage {
    id: page
    pageName: "settings"
    title: qsTr("Einstellungen")

    Flickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.margin
        clip: true

        Column {
            id: column
            width: parent.width

            HSection { text: qsTr("Dein Name") }
            HTextField {
                x: Theme.margin
                width: parent.width - 2 * Theme.margin
                text: game.playerName
                placeholder: qsTr("Name im Spiel")
                onTextChanged: if (text.length > 0) game.playerName = text
            }
            HLabel {
                x: Theme.margin
                width: parent.width - 2 * Theme.margin
                text: qsTr("So sehen dich die anderen im WLAN-Spiel.")
                color: Theme.dimText
                font.pixelSize: Theme.fontXSmall
            }

            HSection { text: qsTr("Computergegner") }
            HButtonRow {
                x: Theme.margin
                width: parent.width - 2 * Theme.margin
                model: [qsTr("Leicht"), qsTr("Mittel"), qsTr("Schwer")]
                currentIndex: game.computerSkill - 1
                onPicked: game.computerSkill = index + 1
            }

            HSection { text: qsTr("Statistik") }
            HLabel {
                x: Theme.margin
                width: parent.width - 2 * Theme.margin
                text: qsTr("%1 Spiele gespielt, %2 gewonnen").arg(game.gamesPlayed).arg(game.gamesWon)
                color: Theme.secondaryText
            }
        }
    }
}
