import QtQuick
import QtQuick.Window

// Android, iOS, Linux, Windows and macOS shell (Qt 6): a plain window around the shared app, kept
// clear of status bar, notch and gesture bar.
Window {
    id: window
    visible: true
    // Phones fill the screen anyway; on a PC the window opens maximised.
    readonly property bool desktop: Qt.platform.os === "linux" || Qt.platform.os === "windows" || Qt.platform.os === "osx" || Qt.platform.os === "macos"
    width: desktop ? 1280 : 480
    height: desktop ? 800 : 854
    minimumWidth: 400
    minimumHeight: 560
    visibility: desktop ? Window.Maximized : Window.AutomaticVisibility
    color: "#000000"
    title: "BioQuiz"

    AppView {
        anchors.fill: parent
        anchors.topMargin: window.SafeArea.margins.top
        anchors.bottomMargin: window.SafeArea.margins.bottom
        anchors.leftMargin: window.SafeArea.margins.left
        anchors.rightMargin: window.SafeArea.margins.right
        focus: true
    }
}
