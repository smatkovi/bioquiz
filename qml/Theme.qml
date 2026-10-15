pragma Singleton
import QtQuick 2.6

// MeeGo 1.2 Harmattan, inverted (black) theme "blanco": colours from its
// constants.ini, sizes from the N9's 480 px wide portrait screen. `u` scales
// those 480 px to the actual window width and is set by AppView.
QtObject {
    property real u: 1.0
    // Wide windows (desktop, tablets turned sideways) get side-by-side layouts.
    property bool landscape: false

    property string fontFamily: typeof uiFontFamily !== "undefined" ? uiFontFamily : "Nokia Pure Text"

    readonly property color background: "#000000"
    readonly property color text: "#FFFFFF"              // COLOR_INVERTED_FOREGROUND
    readonly property color secondaryText: "#C8C8C8"     // COLOR_INVERTED_SECONDARY_FOREGROUND
    readonly property color dimText: "#8C8C8C"           // COLOR_BUTTON_SECONDARY_FOREGROUND
    readonly property color disabledText: "#5A5A5A"
    readonly property color highlight: "#1080DD"         // COLOR_LINK, the Harmattan blue
    readonly property color highlightDark: "#1C51AF"     // COLOR_LINK_ACTIVE
    readonly property color positive: "#62B700"          // COLOR_ACCENT2
    readonly property color negative: "#DA201E"          // COLOR_WARNING
    readonly property color attention: "#CC9900"         // COLOR_ATTENTION
    readonly property color panel: "#161616"
    readonly property color separator: "#333333"
    readonly property color empty: "#3A3A3A"
    readonly property color fieldText: "#282828"         // COLOR_FOREGROUND, on the light text field
    readonly property color fieldPlaceholder: "#8C8C8C"

    readonly property real fontXLarge: 32 * u
    readonly property real fontLarge: 28 * u
    readonly property real fontDefault: 24 * u
    readonly property real fontSmall: 20 * u
    readonly property real fontXSmall: 18 * u
    readonly property real fontXXSmall: 16 * u

    readonly property real margin: 16 * u        // default page margin
    readonly property real spacing: 12 * u
    readonly property real headerHeight: 72 * u
    readonly property real toolbarHeight: 72 * u
    readonly property real buttonHeight: 64 * u
    readonly property real listItemHeight: 88 * u

    // Menus and lists stay a readable column on wide screens.
    readonly property real maxColumn: 760 * u

    // Nokia's own graphics from the data folder, else the free look-alikes.
    readonly property string img: typeof themeImageBase !== "undefined" ? themeImageBase : "qrc:/harmattan-free/"
}
