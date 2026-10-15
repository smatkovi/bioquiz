import QtQuick 2.6
import "."

// The Harmattan busy indicator: a ring of dots with a travelling light.
Item {
    id: spinner
    property bool running: visible
    property int dots: 12
    property int lit: 0
    width: 64 * Theme.u
    height: width

    Repeater {
        model: spinner.dots
        Image {
            property real angle: index * 2 * Math.PI / spinner.dots
            x: spinner.width / 2 + Math.sin(angle) * spinner.width * 0.4 - width / 2
            y: spinner.height / 2 - Math.cos(angle) * spinner.height * 0.4 - height / 2
            width: 10 * Theme.u
            height: width
            source: Theme.img + "meegotouch-progressindicator-inverted-spinner-medium-"
                    + ((spinner.lit - index + spinner.dots) % spinner.dots < 4 ? "on" : "off") + ".png"
            opacity: 1.0 - ((spinner.lit - index + spinner.dots) % spinner.dots) * 0.15
            smooth: true
        }
    }
    Timer {
        interval: 80
        repeat: true
        running: spinner.running
        onTriggered: spinner.lit = (spinner.lit + 1) % spinner.dots
    }
}
