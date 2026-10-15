import QtQuick 2.6
import "."

// A Harmattan 9-patch image. The N9 graphics are made for 480 px wide
// screens, so the image is laid out at 1/u of the size and scaled up; that
// keeps corners and borders in proportion on any screen.
Item {
    id: frame
    property string name
    property real border: 22

    BorderImage {
        width: frame.width / Theme.u
        height: frame.height / Theme.u
        scale: Theme.u
        transformOrigin: Item.TopLeft
        source: frame.name ? Theme.img + frame.name + ".png" : ""
        border { left: frame.border; right: frame.border; top: frame.border; bottom: frame.border }
        smooth: true
    }
}
