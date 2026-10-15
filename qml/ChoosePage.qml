import QtQuick 2.6
import "."

HPage {
    id: page
    pageName: "choose"
    property int roundIndex: 0
    property var round: (game.match.rounds || [])[roundIndex] || ({})
    property bool chosen: false
    property bool started: false
    title: Lang.t("Wähle ein Thema")
    subtitle: Lang.t("Runde %1").arg(roundIndex + 1)

    // As soon as the questions of the chosen category are there, play them.
    Connections {
        target: game
        onMatchChanged: page.check()
    }
    function check() {
        if (page.started || !page.chosen || !round.cat || !round.qids || round.qids.length === 0)
            return
        page.started = true
        page.app.replace("QuestionPage.qml", { roundIndex: page.roundIndex })
    }

    // Portrait: three cards stacked. Wide windows: side by side, tile above
    // the name.
    fullWidth: true
    property bool wide: Theme.landscape
    keyPressed: function(key) {
        var options = round.options || []
        if (!chosen && key >= Qt.Key_1 && key < Qt.Key_1 + options.length) {
            chosen = true
            game.choose(options[key - Qt.Key_1])
            check()
            return true
        }
        return false
    }

    Grid {
        anchors.centerIn: parent
        columns: page.wide ? 3 : 1
        spacing: Theme.margin

        Repeater {
            model: page.round.options || []
            Item {
                id: card
                property var cat: Lang.cat(modelData)
                width: page.wide ? Math.min((page.bodyWidth - 4 * Theme.margin) / 3, 360 * Theme.u)
                                 : page.bodyWidth - 2 * Theme.margin
                height: page.wide ? width * 1.1 : 150 * Theme.u

                HFrame {
                    anchors.fill: parent
                    name: mouse.pressed ? "meegotouch-button-inverted-background-pressed" : "meegotouch-button-inverted-background"
                }
                Image {
                    id: tile
                    x: page.wide ? (parent.width - width) / 2 : Theme.margin
                    y: page.wide ? parent.height * 0.12 : (parent.height - height) / 2
                    source: "qrc:/cat/" + modelData + ".png"
                    width: page.wide ? parent.width * 0.5 : 112 * Theme.u
                    height: width
                    sourceSize.width: 256
                    sourceSize.height: 256
                    smooth: true
                    mipmap: true
                }
                HLabel {
                    x: page.wide ? Theme.margin : tile.x + tile.width + Theme.margin
                    y: page.wide ? tile.y + tile.height + Theme.margin : (parent.height - height) / 2
                    width: page.wide ? parent.width - 2 * Theme.margin : parent.width - x - Theme.margin
                    horizontalAlignment: page.wide ? Text.AlignHCenter : Text.AlignLeft
                    text: card.cat.name || modelData
                    font.pixelSize: Theme.fontXLarge
                    font.weight: Font.Light
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    enabled: !page.chosen
                    onClicked: {
                        page.chosen = true
                        game.choose(modelData)
                        page.check()
                    }
                }
            }
        }
    }

    HSpinner {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2 * Theme.margin
        visible: page.chosen
    }
}
