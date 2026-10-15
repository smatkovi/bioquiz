import QtQuick 2.6
import "."

// One round: three questions, 20 seconds each, four answers in a 2x2 grid.
// After a tap (or when time is up) the right answer turns green, a wrong
// pick red, and the other players' picks show up as small avatars.
HPage {
    id: page
    pageName: "question"
    property int roundIndex: 0
    property var round: (game.match.rounds || [])[roundIndex] || ({})
    property var qids: round.qids || []
    property var orders: round.orders || []

    property int q: 0
    property var picks: []
    property var times: []
    property bool revealed: false
    property int picked: -2            // original index, -1 = time out
    property real startedAt: 0
    property real elapsed: 0
    property bool submitted: false
    readonly property int limit: 20000

    property var question: qids.length > q ? bank.question(qids[q]) : ({})
    property var category: bank.category(round.cat || "")
    property bool imageReady: !question.image || picture.status === Image.Ready || picture.status === Image.Error

    title: category.name || ""
    subtitle: qsTr("Frage %1 von %2").arg(q + 1).arg(qids.length)
    headerAccent: category.color || Theme.highlight
    toolBarVisible: false

    backRequested: function() {
        if (!submitted)
            abortQuery.open()
    }

    HQuery {
        id: abortQuery
        title: qsTr("Runde abbrechen?")
        message: qsTr("Die offenen Fragen zählen als falsch.")
        acceptText: qsTr("Abbrechen")
        rejectText: qsTr("Weiterspielen")
        onAccepted: page.abort()
    }

    Component.onCompleted: if (imageReady) startClock()
    onImageReadyChanged: if (imageReady && !revealed) startClock()

    function startClock() {
        startedAt = new Date().getTime()
        elapsed = 0
    }

    function answer(orig) {
        if (revealed)
            return
        revealed = true
        picked = orig
        var p = picks.slice(); p.push(orig); picks = p
        var t = times.slice(); t.push(Math.min(limit, Math.round(elapsed))); times = t
    }

    function proceed() {
        if (!revealed)
            return
        if (q + 1 < qids.length) {
            q = q + 1
            revealed = false
            picked = -2
            if (imageReady)
                startClock()
            else
                elapsed = 0
        } else {
            finish()
        }
    }

    function finish() {
        if (submitted)
            return
        submitted = true
        game.submit(roundIndex, picks, times)
        page.app.pop()
    }

    function abort() {
        var p = picks.slice(), t = times.slice()
        if (revealed)
            q = q + 1
        while (p.length < qids.length) { p.push(-1); t.push(limit) }
        picks = p
        times = t
        finish()
    }

    // Original answer index shown at display position i.
    function origAt(i) {
        var order = orders[q]
        return order ? order[i] : i
    }

    // Other players who picked `orig` for the current question.
    function othersWith(orig) {
        var result = []
        var live = (game.match.rounds || [])[roundIndex]
        if (!live || !live.picks)
            return result
        var players = game.match.players || []
        for (var i = 0; i < players.length; ++i) {
            var id = players[i].id
            if (id === game.myId)
                continue
            var pk = live.picks[String(id)]
            if (pk !== undefined && pk[q] === orig)
                result.push({ name: players[i].name, index: i })
        }
        return result
    }

    Timer {
        interval: 50
        repeat: true
        running: !page.revealed && page.imageReady && !page.submitted && page.qids.length > 0
        onTriggered: {
            page.elapsed = new Date().getTime() - page.startedAt
            if (page.elapsed >= page.limit)
                page.answer(-1)
        }
    }

    // --- layout ------------------------------------------------------------------
    // Portrait: question on top, the four answers below. Wide windows: the
    // question (and picture) on the left, answers and "Weiter" on the right,
    // so nothing has to scroll.
    property bool wide: Theme.landscape
    property real gap: Theme.margin
    property real areaTop: clockRow.y + clockRow.height + gap
    property real sideWidth: wide ? (bodyWidth - 3 * gap) * 0.45 : bodyWidth - 2 * gap
    property real footerHeight: 110 * Theme.u
    property real cellHeight: wide ? Math.min(200 * Theme.u, (bodyHeight - areaTop - footerHeight - gap - answers.spacing) / 2)
                                   : 118 * Theme.u
    // wide: answers and footer as one block, centred in the right column
    property real wideBlockTop: areaTop + Math.max(0, (bodyHeight - areaTop - gap - (2 * cellHeight + answers.spacing) - Theme.spacing - footerHeight) / 2)

    fullWidth: true
    keyPressed: function(key) {
        if (zoom.visible) { zoom.visible = false; return true }
        if (!revealed && key >= Qt.Key_1 && key <= Qt.Key_4) { answer(origAt(key - Qt.Key_1)); return true }
        if (revealed && (key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Space)) { proceed(); return true }
        return false
    }

    Item {
        id: clockRow
        x: page.gap
        y: page.gap
        width: page.bodyWidth - 2 * page.gap
        height: 32 * Theme.u
        HTimerBar {
            anchors.left: parent.left
            anchors.right: seconds.left
            anchors.rightMargin: Theme.spacing
            anchors.verticalCenter: parent.verticalCenter
            value: 1 - page.elapsed / page.limit
            urgent: page.limit - page.elapsed < 5000
            opacity: page.revealed ? 0.4 : 1
        }
        HLabel {
            id: seconds
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 40 * Theme.u
            horizontalAlignment: Text.AlignRight
            text: Math.max(0, Math.ceil((page.limit - page.elapsed) / 1000))
            font.bold: true
            color: page.limit - page.elapsed < 5000 && !page.revealed ? Theme.negative : Theme.text
            wrapMode: Text.NoWrap
        }
    }

    Rectangle {
        id: panel
        x: page.gap
        y: page.areaTop
        width: page.wide ? page.bodyWidth - 3 * page.gap - page.sideWidth : page.bodyWidth - 2 * page.gap
        height: page.wide ? page.bodyHeight - page.areaTop - page.gap
                          : answers.y - page.gap - page.areaTop
        radius: 18 * Theme.u
        color: Theme.panel
        border.color: "#2A2A2A"
        border.width: Math.max(1, Theme.u)

        Image {
            id: picture
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Theme.spacing
            height: page.question.image ? Math.max(0, parent.height - questionText.height - 3 * Theme.spacing) : 0
            visible: !!page.question.image
            source: page.question.image || ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
            MouseArea {
                anchors.fill: parent
                onClicked: zoom.visible = true
            }
        }
        HSpinner {
            anchors.centerIn: picture
            visible: picture.visible && picture.status === Image.Loading
        }

        HLabel {
            id: questionText
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Theme.margin
            anchors.verticalCenter: page.question.image ? undefined : parent.verticalCenter
            anchors.bottom: page.question.image ? parent.bottom : undefined
            anchors.bottomMargin: Theme.spacing
            horizontalAlignment: Text.AlignHCenter
            text: page.question.text || ""
            font.pixelSize: page.question.image ? Theme.fontDefault : Theme.fontLarge
            font.weight: Font.Normal
        }
    }

    Grid {
        id: answers
        x: page.wide ? page.bodyWidth - page.gap - page.sideWidth : page.gap
        y: page.wide ? page.wideBlockTop : page.bodyHeight - page.footerHeight - height - Theme.spacing
        columns: 2
        spacing: Theme.spacing
        property real cellWidth: (page.sideWidth - spacing) / 2

        Repeater {
            model: 4
            HButton {
                id: answerButton
                property int orig: page.origAt(index)
                property var others: page.revealed ? page.othersWith(orig) : []
                width: answers.cellWidth
                height: page.cellHeight
                text: page.question.answers ? page.question.answers[orig] : ""
                fontSize: page.wide ? Theme.fontLarge : Theme.fontDefault
                bold: false
                enabled: !page.revealed || orig === 0 || orig === page.picked
                look: !page.revealed ? "normal"
                    : orig === 0 ? "positive"
                    : orig === page.picked ? "negative" : "normal"
                onClicked: page.answer(orig)

                HLabel {
                    // key hint on wide screens (keyboard play)
                    visible: page.wide && !page.revealed
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: 8 * Theme.u
                    text: index + 1
                    font.pixelSize: Theme.fontXXSmall
                    color: Theme.dimText
                    wrapMode: Text.NoWrap
                }
                Row {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 6 * Theme.u
                    spacing: 3 * Theme.u
                    Repeater {
                        model: answerButton.others
                        Avatar {
                            width: 26 * Theme.u
                            name: modelData.name
                            colorIndex: modelData.index
                        }
                    }
                }
            }
        }
    }

    Item {
        id: footer
        x: answers.x
        y: page.wide ? answers.y + answers.height + Theme.spacing : page.bodyHeight - page.footerHeight
        width: page.sideWidth
        height: page.footerHeight

        HLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            visible: page.revealed
            text: page.picked === -1 ? qsTr("Zeit abgelaufen · %1").arg(page.question.source || "")
                                     : qsTr("Quelle: %1").arg(page.question.source || "")
            font.pixelSize: Theme.fontXXSmall
            color: Theme.dimText
            elide: Text.ElideRight
            maximumLineCount: 1
        }
        HButton {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.margin
            width: parent.width - 2 * Theme.margin
            visible: page.revealed
            look: "accent"
            text: page.q + 1 < page.qids.length ? qsTr("Weiter") : qsTr("Fertig")
            onClicked: page.proceed()
        }
    }

    // Full-screen view of the picture.
    Rectangle {
        id: zoom
        anchors.fill: parent
        visible: false
        color: "#F0000000"
        z: 50
        Image {
            anchors.fill: parent
            anchors.margins: Theme.margin
            source: zoom.visible ? (page.question.image || "") : ""
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
        MouseArea {
            anchors.fill: parent
            onClicked: zoom.visible = false
        }
    }
}
