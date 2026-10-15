import QtQuick 2.6
import "."

// Choose the question pool: one school level (all books of that level) or
// everything. `purpose`: solo (start against the computer), host (open a
// network game), lobby (change the level of an open game).
HPage {
    id: page
    pageName: "level"
    property string purpose: "solo"
    title: qsTr("Schulstufe wählen")
    subtitle: purpose === "solo" ? qsTr("Gegen den Computer") : qsTr("Für alle Mitspieler")

    function pick(key) {
        if (purpose === "solo") {
            game.startSolo(key)
        } else if (purpose === "host") {
            if (!game.host(key, 1))
                return
        } else {
            game.setLobbyConfig(key, game.lobbyPasses)
            page.app.pop()
        }
    }

    ListView {
        id: list
        anchors.fill: parent
        clip: true
        header: Column {
            width: list.width
            HListItem {
                title: qsTr("Alle Schulstufen")
                subtitle: qsTr("%1 Fragen aus allen Büchern").arg(bank.questionCount)
                icon: "qrc:/appicon/bioquiz-128.png"
                titleColor: game.lastLevel === "all" ? Theme.highlight : Theme.text
                onClicked: page.pick("all")
            }
            HSection { text: qsTr("Eine Schulstufe") }
        }
        model: bank.levels
        delegate: HListItem {
            title: modelData.name
            subtitle: qsTr("%1 · %2 Fragen").arg(modelData.sub).arg(modelData.count)
            enabled: modelData.count >= 30
            titleColor: game.lastLevel === modelData.key ? Theme.highlight : Theme.text
            onClicked: page.pick(modelData.key)
        }
    }
}
