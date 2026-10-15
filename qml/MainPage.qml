import QtQuick 2.6
import "."

HPage {
    id: page
    pageName: "main"
    title: "BioQuiz"
    subtitle: !bank.loaded ? bank.error
            : bank.bookCount > 1 ? Lang.t("%1 Fragen aus %2 Schulbüchern").arg(bank.questionCount).arg(bank.bookCount)
            : Lang.t("%1 Fragen").arg(bank.questionCount)
    backVisible: false

    Flickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.margin
        clip: true

        Column {
            id: column
            width: parent.width

            Item {
                width: parent.width
                height: 200 * Theme.u
                Image {
                    id: logo
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -12 * Theme.u
                    source: "qrc:/appicon/bioquiz-256.png"
                    width: 128 * Theme.u
                    height: width
                    smooth: true
                    mipmap: true
                }
                HLabel {
                    anchors.top: logo.bottom
                    anchors.topMargin: Theme.spacing
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Lang.t("Das Biologie-Duell")
                    font.pixelSize: Theme.fontSmall
                    color: Theme.secondaryText
                }
            }

            HSection { text: Lang.t("Spielen") }

            HListItem {
                title: Lang.t("Gegen den Computer")
                subtitle: Lang.t("Allein, sechs Runden wie im Quizduell")
                icon: "qrc:/appicon/bioquiz-128.png"
                enabled: bank.loaded
                onClicked: page.app.push("LevelPage.qml", { purpose: "solo" })
            }
            HListItem {
                title: Lang.t("Spiel eröffnen")
                subtitle: btAvailable ? Lang.t("Andere treten über WLAN oder Bluetooth bei")
                                      : Lang.t("Andere treten über WLAN bei")
                icon: Theme.img + "icon-m-common-wlan-strength3.png"
                enabled: bank.loaded
                onClicked: page.app.push("LevelPage.qml", { purpose: "host" })
            }
            HListItem {
                title: Lang.t("Spiel beitreten")
                subtitle: Lang.t("Ein eröffnetes Spiel in der Nähe")
                icon: Theme.img + "icon-m-content-avatar-placeholder-inverse.png"
                enabled: bank.loaded
                onClicked: page.app.push("JoinPage.qml", {})
            }

            HSection { text: Lang.t("Mehr") }

            HListItem {
                title: Lang.t("Einstellungen")
                subtitle: Lang.t("Name: %1").arg(game.playerName)
                onClicked: page.app.push("SettingsPage.qml", {})
            }
            HListItem {
                title: Lang.t("Über BioQuiz")
                onClicked: page.app.push("AboutPage.qml", {})
            }

            Item { width: 1; height: Theme.margin }
            HLabel {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                visible: game.gamesPlayed > 0
                text: Lang.t("%1 Spiele gespielt, %2 gewonnen").arg(game.gamesPlayed).arg(game.gamesWon)
                font.pixelSize: Theme.fontXSmall
                color: Theme.dimText
            }
        }
    }
}
