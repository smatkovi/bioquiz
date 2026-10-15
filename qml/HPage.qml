import QtQuick 2.6
import "."

// A page: header on top, tool bar at the bottom, content in between.
Rectangle {
    id: page
    property var app
    property string pageName
    property string title
    property string subtitle
    property color headerAccent: "transparent"
    property bool toolBarVisible: true
    property bool backVisible: true
    property bool destroyLater: false
    // false: content in a centred column of at most Theme.maxColumn on wide
    // screens; true: the page lays out the full width itself.
    property bool fullWidth: false
    // Handles a key press (desktop); returns true when used.
    property var keyPressed
    property alias toolRow: toolBar.toolRow
    default property alias content: body.data
    // Size of the area between header and tool bar, for pages that lay out
    // their content by hand.
    readonly property alias bodyWidth: body.width
    readonly property alias bodyHeight: body.height
    // Overrides the plain pop() of the back key/button.
    property var backRequested

    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    color: Theme.background
    visible: false

    HHeader {
        id: header
        title: page.title
        subtitle: page.subtitle
        accent: page.headerAccent
        visible: page.title.length > 0
    }

    Item {
        id: body
        anchors.top: header.visible ? header.bottom : parent.top
        anchors.bottom: toolBar.visible ? toolBar.top : parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: page.fullWidth ? parent.width : Math.min(parent.width, Theme.maxColumn)
    }

    HToolBar {
        id: toolBar
        anchors.bottom: parent.bottom
        visible: page.toolBarVisible
        backVisible: page.backVisible
        onBack: page.app.goBack()
    }
}
