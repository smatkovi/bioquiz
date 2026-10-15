import QtQuick 2.6
import Sailfish.Silica 1.0
import ".." as App

CoverBackground {
    property var m: game.match
    property var players: m.players || []

    function scoreLine() {
        if (players.length === 0)
            return ""
        var parts = []
        for (var i = 0; i < players.length; ++i)
            parts.push(players[i].score)
        return parts.join(" : ")
    }

    Column {
        anchors.centerIn: parent
        width: parent.width - 2 * Theme.paddingLarge
        spacing: Theme.paddingMedium

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            source: "qrc:/appicon/bioquiz-172.png"
            width: Theme.iconSizeLarge
            height: width
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "BioQuiz"
            font.pixelSize: Theme.fontSizeLarge
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: game.phase === "match"
            text: scoreLine()
            font.pixelSize: Theme.fontSizeExtraLarge
            color: Theme.highlightColor
        }
        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            visible: game.phase === "match" && m !== null && game.myTurnToPlay()
            text: App.Lang.t("Du bist dran")
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.Wrap
        }
    }
}
