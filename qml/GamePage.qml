import QtQuick 2.6
import "."

// The duel overview, like Quizduell's game screen: players and score on top,
// one row per round with everybody's three result boxes, and one big button
// for whatever is next (choose a category, play, wait, play again).
HPage {
    id: page
    pageName: "game"
    title: m.over ? resultTitle() : bank.levelName(m.level)
    subtitle: m.over ? bank.levelName(m.level)
                     : qsTr("Runde %1 von %2").arg(Math.max(1, rounds.length)).arg(m.totalRounds || 0)
    headerAccent: m.over ? (resultKind() === "won" ? Theme.positive : resultKind() === "lost" ? "#7A1010" : "#555555")
                         : "transparent"

    property var m: game.match
    property var players: m.players || []
    property var rounds: m.rounds || []
    property int me: game.myId
    property bool duel: players.length === 2
    // More than 8 players: each round row shows only the own boxes and how
    // many have finished, the full picture is the ranking above.
    property bool bigTable: players.length > 8

    backVisible: false
    HToolIcon {
        parent: page.toolRow
        icon: "icon-m-framework-close-thumbnail"
        onClicked: page.backRequested()
    }

    backRequested: function() {
        if (m.over)
            game.leave()
        else
            leaveQuery.open()
    }

    HQuery {
        id: leaveQuery
        title: qsTr("Spiel verlassen?")
        message: game.mode === "host" ? qsTr("Das Spiel endet dann für alle.")
               : game.mode === "guest" ? qsTr("Die anderen spielen ohne dich weiter.") : ""
        acceptText: qsTr("Verlassen")
        onAccepted: game.leave()
    }

    // --- helpers -----------------------------------------------------------------
    function indexOfPlayer(id) {
        for (var i = 0; i < players.length; ++i)
            if (players[i].id === id) return i
        return -1
    }
    function nameOf(id) {
        var i = indexOfPlayer(id)
        return i >= 0 ? players[i].name : "?"
    }
    function picksOf(round, id) {
        if (!round || !round.picks) return null
        var v = round.picks[String(id)]
        return v === undefined ? null : v
    }
    function othersHidden(r) {
        return !m.over && r < rounds.length && picksOf(rounds[r], me) === null
    }
    function opponent() {
        for (var i = 0; i < players.length; ++i)
            if (players[i].id !== me) return players[i]
        return { id: -1, name: "", score: 0 }
    }
    function myself() {
        var i = indexOfPlayer(me)
        return i >= 0 ? players[i] : { id: me, name: game.playerName, score: 0 }
    }
    function doneCount(round) {
        var n = 0
        if (!round || !round.picks) return 0
        for (var i = 0; i < players.length; ++i)
            if (round.picks[String(players[i].id)] !== undefined) n += 1
        return n
    }
    function ranking() {
        var list = players.slice()
        list.sort(function(a, b) { return b.score - a.score })
        return list
    }
    function resultKind() {
        var best = -1, count = 0
        for (var i = 0; i < players.length; ++i) {
            if (players[i].score > best) { best = players[i].score; count = 1 }
            else if (players[i].score === best) count += 1
        }
        var mine = myself().score
        if (mine < best) return "lost"
        return count > 1 ? "draw" : "won"
    }
    function resultTitle() {
        if (m.aborted) return qsTr("Spiel abgebrochen")
        var k = resultKind()
        return k === "won" ? qsTr("Gewonnen!") : k === "draw" ? qsTr("Unentschieden") : qsTr("Verloren")
    }
    function catName(key) {
        var c = bank.category(key)
        return c && c.name ? c.name : ""
    }

    // What the big button does now.
    function action() {
        if (m.over) {
            if (game.mode === "guest")
                return { text: qsTr("Warte auf den Gastgeber …"), look: "normal", enabled: false, act: "" }
            return { text: qsTr("Nochmal spielen"), look: "accent", enabled: true, act: "rematch" }
        }
        if (rounds.length === 0)
            return { text: qsTr("Einen Moment …"), look: "normal", enabled: false, act: "" }
        var r = rounds.length - 1
        var round = rounds[r]
        if (!round.cat) {
            if (round.chooser === me)
                return { text: qsTr("Thema wählen"), look: "accent", enabled: true, act: "choose" }
            return { text: qsTr("%1 wählt ein Thema …").arg(nameOf(round.chooser)), look: "normal", enabled: false, act: "" }
        }
        if (picksOf(round, me) === null)
            return { text: qsTr("Spielen: %1").arg(catName(round.cat)), look: "accent", enabled: true, act: "play" }
        var waiting = []
        for (var i = 0; i < players.length; ++i)
            if (picksOf(round, players[i].id) === null) waiting.push(players[i].name)
        var who = waiting.length <= 3 ? waiting.join(", ") : qsTr("%1 Spieler").arg(waiting.length)
        return { text: qsTr("Warte auf %1 …").arg(who), look: "normal", enabled: false, act: "" }
    }
    property var next: action()

    function doAction() {
        var r = rounds.length - 1
        if (next.act === "choose")
            page.app.push("ChoosePage.qml", { roundIndex: r })
        else if (next.act === "play")
            page.app.push("QuestionPage.qml", { roundIndex: r })
        else if (next.act === "rematch")
            game.rematch()
    }

    // --- layout ------------------------------------------------------------------
    // Portrait: score on top, rounds below, the big button at the bottom.
    // Wide windows: score/ranking and buttons on the left, rounds on the right.
    fullWidth: true
    property bool wide: Theme.landscape
    property real leftWidth: wide ? Math.min(bodyWidth * 0.42, 560 * Theme.u) : bodyWidth
    property real scoreHeight: wide ? bodyHeight - buttons.height - 2 * Theme.margin
                             : duel ? 190 * Theme.u
                             : Math.min(rankingColumn.height, bodyHeight * 0.35)

    keyPressed: function(key) {
        if ((key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Space) && next.enabled) {
            doAction()
            return true
        }
        return false
    }

    Flickable {
        id: scoreArea
        x: 0
        y: 0
        width: page.leftWidth
        height: page.scoreHeight
        contentHeight: scoreColumn.height
        clip: true
        interactive: contentHeight > height

        Column {
            id: scoreColumn
            width: parent.width

            Item { width: 1; height: page.wide && page.duel ? (page.scoreHeight - duelBox.height) / 3 : 0 }

            // Two players: the classic face-off.
            Item {
                id: duelBox
                visible: page.duel
                width: parent.width
                height: page.duel ? 190 * Theme.u : 0
                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.margin
                    anchors.verticalCenter: parent.verticalCenter
                    width: 150 * Theme.u
                    spacing: 6 * Theme.u
                    Avatar {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 80 * Theme.u
                        name: page.myself().name
                        colorIndex: page.indexOfPlayer(page.me)
                    }
                    HLabel {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: page.myself().name
                        font.bold: true
                        font.pixelSize: Theme.fontSmall
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }
                HLabel {
                    anchors.centerIn: parent
                    text: page.myself().score + " : " + page.opponent().score
                    font.pixelSize: 56 * Theme.u
                    font.weight: Font.Light
                    wrapMode: Text.NoWrap
                }
                Column {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.margin
                    anchors.verticalCenter: parent.verticalCenter
                    width: 150 * Theme.u
                    spacing: 6 * Theme.u
                    Avatar {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 80 * Theme.u
                        name: page.opponent().name
                        colorIndex: page.indexOfPlayer(page.opponent().id)
                        dim: page.opponent().connected === false
                    }
                    HLabel {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: page.opponent().name
                        font.bold: true
                        font.pixelSize: Theme.fontSmall
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }
            }

            // Three or more: a ranking.
            Column {
                id: rankingColumn
                visible: !page.duel
                width: parent.width
                Item { width: 1; height: Theme.spacing }
                Repeater {
                    model: page.duel ? [] : page.ranking()
                    Item {
                        width: rankingColumn.width
                        height: 56 * Theme.u
                        HLabel {
                            id: rank
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.margin
                            anchors.verticalCenter: parent.verticalCenter
                            width: 44 * Theme.u
                            text: (index + 1) + "."
                            color: Theme.secondaryText
                            wrapMode: Text.NoWrap
                        }
                        Avatar {
                            id: av
                            anchors.left: rank.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 44 * Theme.u
                            name: modelData.name
                            colorIndex: page.indexOfPlayer(modelData.id)
                            dim: modelData.connected === false
                        }
                        HLabel {
                            anchors.left: av.right
                            anchors.leftMargin: Theme.spacing
                            anchors.right: score.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.name + (modelData.id === page.me ? qsTr(" (du)") : "")
                            font.bold: modelData.id === page.me
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                        HLabel {
                            id: score
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.margin
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.score
                            font.pixelSize: Theme.fontLarge
                            wrapMode: Text.NoWrap
                        }
                    }
                }
            }
        }
    }

    Flickable {
        id: flick
        x: page.wide ? page.leftWidth : 0
        y: page.wide ? 0 : scoreArea.height
        width: page.wide ? page.bodyWidth - page.leftWidth : page.bodyWidth
        height: page.wide ? page.bodyHeight : buttons.y - Theme.margin - y
        contentHeight: column.height + Theme.margin
        clip: true

        Column {
            id: column
            width: parent.width

            HSection { text: qsTr("Runden") }

            Repeater {
                model: page.m.totalRounds || 0
                Item {
                    id: roundRow
                    property var round: index < page.rounds.length ? page.rounds[index] : null
                    property bool hide: page.othersHidden(index)
                    width: column.width
                    height: page.duel || page.bigTable ? 76 * Theme.u : multi.height + 70 * Theme.u

                    // middle: category of the round
                    Column {
                        id: middle
                        anchors.horizontalCenter: page.duel ? parent.horizontalCenter : undefined
                        anchors.left: page.duel ? undefined : parent.left
                        anchors.leftMargin: Theme.margin
                        y: 6 * Theme.u
                        width: page.duel ? 220 * Theme.u : parent.width - 2 * Theme.margin
                        Row {
                            anchors.horizontalCenter: page.duel ? parent.horizontalCenter : undefined
                            spacing: Theme.spacing / 2
                            Image {
                                visible: roundRow.round !== null && roundRow.round.cat !== ""
                                source: visible ? "qrc:/cat/" + roundRow.round.cat + ".png" : ""
                                width: 40 * Theme.u
                                height: width
                                sourceSize.width: 80
                                sourceSize.height: 80
                                smooth: true
                            }
                            HLabel {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: page.duel && !(roundRow.round !== null && roundRow.round.cat !== "")
                                text: qsTr("Runde %1").arg(index + 1)
                                color: roundRow.round !== null ? Theme.secondaryText : Theme.disabledText
                                font.pixelSize: Theme.fontSmall
                                wrapMode: Text.NoWrap
                            }
                            HLabel {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !page.duel
                                text: qsTr("Runde %1").arg(index + 1)
                                      + (roundRow.round !== null && roundRow.round.cat !== "" ? " · " + page.catName(roundRow.round.cat) : "")
                                color: roundRow.round !== null ? Theme.text : Theme.disabledText
                                font.pixelSize: Theme.fontSmall
                                font.bold: true
                                wrapMode: Text.NoWrap
                            }
                        }
                        HLabel {
                            width: parent.width
                            visible: page.duel && roundRow.round !== null && roundRow.round.cat !== ""
                            horizontalAlignment: Text.AlignHCenter
                            text: roundRow.round !== null ? page.catName(roundRow.round.cat) : ""
                            font.pixelSize: Theme.fontXXSmall
                            color: Theme.secondaryText
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }

                    // two players: boxes left and right
                    Squares {
                        visible: page.duel
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.margin
                        anchors.verticalCenter: parent.verticalCenter
                        picks: page.picksOf(roundRow.round, page.me)
                    }
                    Squares {
                        visible: page.duel
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.margin
                        anchors.verticalCenter: parent.verticalCenter
                        picks: page.picksOf(roundRow.round, page.opponent().id)
                        hidden: roundRow.hide
                    }

                    // big table: own boxes and how many are done
                    Row {
                        visible: page.bigTable
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.margin
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacing
                        HLabel {
                            anchors.verticalCenter: parent.verticalCenter
                            text: page.doneCount(roundRow.round) + "/" + page.players.length
                            color: Theme.secondaryText
                            font.pixelSize: Theme.fontXSmall
                            wrapMode: Text.NoWrap
                        }
                        Squares {
                            anchors.verticalCenter: parent.verticalCenter
                            picks: page.picksOf(roundRow.round, page.me)
                        }
                    }

                    // more players: everybody's boxes in a flow
                    Flow {
                        id: multi
                        visible: !page.duel && !page.bigTable
                        anchors.top: middle.bottom
                        anchors.topMargin: 8 * Theme.u
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.margin
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.margin
                        spacing: Theme.spacing
                        Repeater {
                            model: page.duel || page.bigTable ? [] : page.players
                            Row {
                                spacing: 6 * Theme.u
                                Avatar {
                                    width: 26 * Theme.u
                                    name: modelData.name
                                    colorIndex: index
                                    dim: modelData.connected === false
                                }
                                Squares {
                                    anchors.verticalCenter: parent.verticalCenter
                                    size: 18 * Theme.u
                                    picks: page.picksOf(roundRow.round, modelData.id)
                                    hidden: modelData.id !== page.me && roundRow.hide
                                }
                            }
                        }
                    }

                    Image {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: Theme.margin
                        anchors.rightMargin: Theme.margin
                        height: 2 * Theme.u
                        source: Theme.img + "meegotouch-separator-inverted-background-horizontal.png"
                        fillMode: Image.Stretch
                        opacity: 0.6
                    }
                }
            }
        }
    }

    // a thin line between the two halves on wide screens
    Rectangle {
        visible: page.wide
        x: page.leftWidth
        y: Theme.margin
        width: Math.max(1, Theme.u)
        height: page.bodyHeight - 2 * Theme.margin
        color: Theme.separator
    }

    Column {
        id: buttons
        x: 2 * Theme.margin
        width: (page.wide ? page.leftWidth : page.bodyWidth) - 4 * Theme.margin
        y: page.bodyHeight - height - Theme.margin
        spacing: Theme.spacing

        HButton {
            width: parent.width
            height: 80 * Theme.u
            text: page.next.text
            look: page.next.look
            enabled: page.next.enabled
            fontSize: Theme.fontLarge
            maxLines: 2
            onClicked: page.doAction()
        }
        HButton {
            width: parent.width
            visible: page.m.over === true
            text: qsTr("Zum Menü")
            onClicked: game.leave()
        }
    }
}
