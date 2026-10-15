import QtQuick 2.6
import Sailfish.Silica 1.0
import ".."

// Sailfish OS shell: one Silica page that holds the whole Harmattan-style
// app, plus the cover.
ApplicationWindow {
    id: window
    allowedOrientations: Orientation.Portrait
    _defaultPageOrientations: Orientation.Portrait
    cover: Qt.resolvedUrl("CoverPage.qml")

    initialPage: Component {
        Page {
            allowedOrientations: Orientation.Portrait
            backNavigation: false
            AppView {
                id: appView
                anchors.fill: parent
            }
        }
    }
}
