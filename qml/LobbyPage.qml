import QtQuick 2.6
import "."

// Waiting room of a network game. The host sees who has joined, can change
// the level and the number of passes and starts the match; guests wait.
HPage {
    id: page
    pageName: "lobby"
    property bool isHost: game.mode === "host"
    title: isHost ? Lang.t("Spiel eröffnet") : Lang.t("Warteraum")
    subtitle: isHost ? Lang.t("Warte auf Mitspieler") : Lang.t("Gastgeber: %1").arg(game.hostName)

    backVisible: false
    HToolIcon {
        parent: page.toolRow
        icon: "icon-m-framework-close-thumbnail"
        onClicked: page.backRequested()
    }

    backRequested: function() { leaveQuery.open() }

    HQuery {
        id: leaveQuery
        title: page.isHost ? Lang.t("Spiel schließen?") : Lang.t("Warteraum verlassen?")
        acceptText: page.isHost ? Lang.t("Schließen") : Lang.t("Verlassen")
        onAccepted: game.leave()
    }

    Flickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.margin
        clip: true

        Column {
            id: column
            width: parent.width

            HSection { text: Lang.t("Fragen") }
            HListItem {
                title: Lang.level(game.lobbyLevel)
                subtitle: Lang.t("%1 Fragen").arg(bank.poolSize(game.lobbyLevel))
                drilldown: page.isHost
                enabled: true
                onClicked: if (page.isHost) page.app.push("LevelPage.qml", { purpose: "lobby" })
            }

            HSection {
                text: Lang.t("Runden")
            }
            HLabel {
                x: Theme.margin
                width: parent.width - 2 * Theme.margin
                text: game.lobbyPlayers.length <= 2
                      ? Lang.t("Zu zweit: 6 Runden, ihr wählt abwechselnd das Thema.")
                      : Lang.t("%1 Spieler: jeder wählt %2 ein Thema, also %3 Runden.")
                            .arg(game.lobbyPlayers.length)
                            .arg(game.lobbyPasses === 1 ? Lang.t("einmal") : Lang.t("%1-mal").arg(game.lobbyPasses))
                            .arg(game.lobbyPlayers.length * game.lobbyPasses)
                color: Theme.secondaryText
                font.pixelSize: Theme.fontSmall
            }
            Item { width: 1; height: Theme.spacing }
            HButtonRow {
                x: Theme.margin
                width: parent.width - 2 * Theme.margin
                visible: page.isHost
                model: [Lang.t("1× herum"), Lang.t("2× herum"), Lang.t("3× herum")]
                currentIndex: game.lobbyPasses - 1
                onPicked: game.setLobbyConfig(game.lobbyLevel, index + 1)
            }

            HSection { text: Lang.t("Spieler (%1)").arg(game.lobbyPlayers.length) }
            Repeater {
                model: game.lobbyPlayers
                HListItem {
                    title: modelData.name + (modelData.id === game.myId ? Lang.t(" (du)") : "")
                    subtitle: modelData.id === 0 ? Lang.t("Gastgeber") : ""
                    drilldown: false
                }
            }

            HSection {
                text: Lang.t("So treten andere bei")
                visible: page.isHost
            }
            HLabel {
                x: Theme.margin
                width: parent.width - 2 * Theme.margin
                visible: page.isHost
                text: Lang.t("Im selben WLAN „Spiel beitreten“ antippen – das Spiel erscheint von selbst. Sonst diese Adresse eingeben:")
                color: Theme.secondaryText
                font.pixelSize: Theme.fontSmall
            }
            HLabel {
                x: Theme.margin
                width: parent.width - 2 * Theme.margin
                visible: page.isHost
                text: game.localAddresses.length > 0 ? game.localAddresses : Lang.t("(keine Netzwerkadresse)")
                font.pixelSize: Theme.fontLarge
                color: Theme.highlight
            }

            HLabel {
                x: Theme.margin
                width: parent.width - 2 * Theme.margin
                visible: page.isHost && game.bluetoothHosting
                text: Lang.t("Per Bluetooth: Geräte einmal koppeln, dann beim Gast unter „Spiel beitreten“ dieses Gerät wählen: %1").arg(btDevices.localName || btDevices.localAddress)
                color: Theme.secondaryText
                font.pixelSize: Theme.fontSmall
            }

            Item { width: 1; height: 2 * Theme.margin }

            HButton {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 4 * Theme.margin
                visible: page.isHost
                look: "accent"
                enabled: game.lobbyPlayers.length >= 2
                text: game.lobbyPlayers.length >= 2 ? Lang.t("Spiel starten") : Lang.t("Warte auf Mitspieler …")
                onClicked: game.startHostedMatch()
            }
            Column {
                visible: !page.isHost
                width: parent.width
                spacing: Theme.spacing
                HSpinner { anchors.horizontalCenter: parent.horizontalCenter }
                HLabel {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: Lang.t("Warte, bis %1 das Spiel startet").arg(game.hostName)
                    color: Theme.secondaryText
                }
            }
        }
    }
}
