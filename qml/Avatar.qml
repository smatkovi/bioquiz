import QtQuick 2.6
import "."

// Squircle with the initial of a player, in one of the Harmattan accent
// colours (same silhouette as the app icons).
Item {
    id: avatar
    property string name
    property int colorIndex: 0
    property bool dim: false
    width: 64 * Theme.u
    height: width
    opacity: dim ? 0.4 : 1.0

    Image {
        anchors.fill: parent
        source: "qrc:/ui/avatar-" + (Math.max(0, avatar.colorIndex) % 8) + ".png"
        sourceSize.width: 128
        sourceSize.height: 128
        smooth: true
        mipmap: true
    }
    HLabel {
        anchors.centerIn: parent
        text: avatar.name.length > 0 ? avatar.name.charAt(0).toUpperCase() : "?"
        font.pixelSize: avatar.width * 0.5
        font.bold: true
        wrapMode: Text.NoWrap
    }
}
