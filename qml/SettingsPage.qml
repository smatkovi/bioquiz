import QtQuick 2.6
import "."

HPage {
    id: page
    pageName: "settings"
    title: Lang.t("Einstellungen")

    Flickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.margin
        clip: true

        Column {
            id: column
            width: parent.width

            HSection { text: Lang.t("Dein Name") }
            HTextField {
                x: Theme.margin
                width: parent.width - 2 * Theme.margin
                text: game.playerName
                placeholder: Lang.t("Name im Spiel")
                onTextChanged: if (text.length > 0) game.playerName = text
            }
            HLabel {
                x: Theme.margin
                width: parent.width - 2 * Theme.margin
                text: Lang.t("So sehen dich die anderen im WLAN-Spiel.")
                color: Theme.dimText
                font.pixelSize: Theme.fontXSmall
            }

            HSection { text: Lang.t("Computergegner") }
            HButtonRow {
                x: Theme.margin
                width: parent.width - 2 * Theme.margin
                model: [Lang.t("Leicht"), Lang.t("Mittel"), Lang.t("Schwer")]
                currentIndex: game.computerSkill - 1
                onPicked: game.computerSkill = index + 1
            }

            HSection { text: Lang.t("Sprache / Language") }
            HButtonRow {
                x: Theme.margin
                width: parent.width - 2 * Theme.margin
                model: ["Deutsch", "English"]
                currentIndex: game.language === "en" ? 1 : 0
                onPicked: game.language = index === 1 ? "en" : "de"
            }

            HSection { text: Lang.t("Statistik") }
            HLabel {
                x: Theme.margin
                width: parent.width - 2 * Theme.margin
                text: Lang.t("%1 Spiele gespielt, %2 gewonnen").arg(game.gamesPlayed).arg(game.gamesWon)
                color: Theme.secondaryText
            }
        }
    }
}
