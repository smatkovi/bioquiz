import QtQuick 2.6
import "."

HPage {
    id: page
    pageName: "join"
    title: Lang.t("Spiel beitreten")
    subtitle: game.phase === "joining" ? Lang.t("Verbinde …") : Lang.t("Im selben WLAN")

    Component.onCompleted: { lanBrowser.search(); btDevices.refresh() }
    backRequested: function() {
        if (game.phase === "joining")
            game.leave()
        page.app.pop()
    }

    HToolIcon {
        parent: page.toolRow
        icon: "icon-m-toolbar-refresh-white"
        onClicked: { lanBrowser.search(); btDevices.refresh() }
    }

    Flickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.margin
        clip: true
        enabled: game.phase !== "joining"

        Column {
            id: column
            width: parent.width

            HSection { text: Lang.t("Gefundene Spiele") }

            Repeater {
                model: lanBrowser.hosts
                HListItem {
                    title: modelData.name
                    subtitle: Lang.t("%1 · noch %2 Plätze frei").arg(modelData.address).arg(modelData.openSeats)
                    icon: Theme.img + "icon-m-common-wlan-strength3.png"
                    onClicked: game.join(modelData.address)
                }
            }
            Item {
                width: parent.width
                height: 96 * Theme.u
                visible: lanBrowser.hosts.length === 0
                HSpinner {
                    anchors.centerIn: parent
                    visible: lanBrowser.searching
                }
                HLabel {
                    anchors.centerIn: parent
                    visible: !lanBrowser.searching
                    text: Lang.t("Kein Spiel gefunden")
                    color: Theme.dimText
                }
            }

            HSection {
                text: Lang.t("Bluetooth (gekoppelte Geräte)")
                visible: btDevices.available
            }
            Repeater {
                model: btDevices.available ? btDevices.devices : []
                HListItem {
                    title: modelData.name
                    subtitle: modelData.address
                    icon: Theme.img + "icon-m-bluetooth-active.png"
                    onClicked: game.joinBluetooth(modelData.address)
                }
            }
            HLabel {
                x: Theme.margin
                width: parent.width - 2 * Theme.margin
                visible: btDevices.available && btDevices.devices.length === 0
                text: Lang.t("Noch kein Gerät gekoppelt. Koppel das Gerät des Gastgebers einmal in den Bluetooth-Einstellungen.")
                color: Theme.dimText
                font.pixelSize: Theme.fontXSmall
            }

            HSection { text: Lang.t("Adresse eingeben") }
            Column {
                x: Theme.margin
                width: parent.width - 2 * Theme.margin
                spacing: Theme.spacing
                HTextField {
                    id: address
                    placeholder: Lang.t("z. B. 192.168.1.20")
                    inputMethodHints: Qt.ImhPreferNumbers | Qt.ImhNoPredictiveText
                    onAccepted: if (text.length > 0) game.join(text)
                }
                HButton {
                    width: parent.width
                    look: "accent"
                    text: Lang.t("Beitreten")
                    enabled: address.text.length > 0
                    onClicked: game.join(address.text)
                }
                HLabel {
                    width: parent.width
                    text: Lang.t("Die Adresse steht beim Gastgeber unter „So treten andere bei“.")
                    color: Theme.dimText
                    font.pixelSize: Theme.fontXSmall
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#B0000000"
        visible: game.phase === "joining"
        HSpinner {
            anchors.centerIn: parent
            visible: parent.visible
        }
    }
}
