import QtQuick 2.6
import "."

// The whole app below the platform window: a page stack with Harmattan-style
// sliding transitions, the info banner, and the switch between menus and the
// running game. Sailfish OS wraps it in a Silica page, Android and iOS in a
// plain window.
//
// Context properties from C++: game (GameController), bank (QuestionBank),
// lanBrowser (LanBrowser), btAvailable (bool), appVersion (string).
Rectangle {
    id: app
    color: Theme.background
    focus: true

    property var pages: []
    property Item currentPage: pages.length > 0 ? pages[pages.length - 1] : null

    Component.onCompleted: {
        updateScale()
        push("MainPage.qml", {})
    }
    onWidthChanged: updateScale()
    onHeightChanged: updateScale()

    // Portrait (phones): the N9's 480 px scaled to the width. Landscape
    // (desktop windows): scaled to the height, so a page never needs more
    // room than the screen has; the width is used by side-by-side layouts.
    function updateScale() {
        if (width <= 0 || height <= 0)
            return
        Theme.landscape = width > height * 1.15
        // Portrait is limited by the height too, so a nearly square window
        // does not grow the phone layout beyond the screen.
        Theme.u = Theme.landscape ? Math.max(0.8, Math.min(2.2, height / 860))
                                  : Math.min(width / 480, height / 800)
    }

    // --- page stack ------------------------------------------------------------
    function createPage(file, props) {
        var component = Qt.createComponent(Qt.resolvedUrl(file))
        if (component.status !== Component.Ready) {
            console.warn("BioQuiz: " + file + ": " + component.errorString())
            return null
        }
        var p = props || {}
        p.app = app
        return component.createObject(stage, p)
    }

    function push(file, props) {
        var page = createPage(file, props)
        if (!page)
            return null
        var previous = currentPage
        var list = pages.slice()
        list.push(page)
        pages = list
        slide(page, previous, true, false)
        return page
    }

    function pop() {
        if (pages.length <= 1)
            return
        var list = pages.slice()
        var old = list.pop()
        pages = list
        slide(currentPage, old, false, true)
    }

    // Swaps the top page for another one, sliding forward.
    function replace(file, props) {
        var page = createPage(file, props)
        if (!page)
            return null
        var list = pages.slice()
        var old = list.pop()
        list.push(page)
        pages = list
        slide(page, old, true, true)
        return page
    }

    // Back to the main menu, dropping everything above it.
    function popToRoot() {
        while (pages.length > 2) {
            var list = pages.slice()
            var below = list.splice(list.length - 2, 1)[0]
            pages = list
            below.destroy()
        }
        pop()
    }

    // Replaces everything above the main menu with one page.
    function showOnly(file, props) {
        var page = createPage(file, props)
        if (!page)
            return null
        var old = currentPage
        var list = pages.slice()
        for (var i = 1; i < list.length - 1; ++i)
            list[i].destroy()
        pages = [list[0], page]
        // The main menu at the bottom stays, anything above it goes. Counted,
        // not compared: Qt 4's QtScript (MeeGo) may wrap one page in several
        // objects, so `old !== list[0]` can be true for the same page.
        slide(page, old, true, list.length > 1)
        return page
    }

    function slide(incoming, outgoing, forward, discard) {
        // Finish a transition still running, so its page is hidden or gone.
        if (outAnim.running)
            outAnim.complete()
        if (inAnim.running)
            inAnim.complete()
        if (!incoming)
            return
        incoming.visible = true
        incoming.x = forward ? app.width : -app.width / 3
        if (outgoing) {
            outgoing.destroyLater = discard
            outAnim.target = outgoing
            outAnim.to = forward ? -app.width / 3 : app.width
            outAnim.restart()
        }
        inAnim.target = incoming
        inAnim.restart()
    }

    NumberAnimation {
        id: inAnim
        property: "x"
        to: 0
        duration: 250
        easing.type: Easing.OutQuad
    }
    NumberAnimation {
        id: outAnim
        property: "x"
        duration: 250
        easing.type: Easing.OutQuad
        onStopped: {
            if (!target)
                return
            if (target.destroyLater)
                target.destroy()
            else
                target.visible = false
        }
    }

    function pageIs(name) {
        return currentPage && currentPage.pageName === name
    }

    function goBack() {
        if (currentPage && currentPage.backRequested)
            currentPage.backRequested()
        else
            pop()
    }

    // Desktop: answers with 1-4, Enter for "Weiter"; the page decides.
    Keys.onPressed: {
        if (currentPage && currentPage.keyPressed && currentPage.keyPressed(event.key))
            event.accepted = true
    }

    Keys.onReleased: {
        if (event.key === Qt.Key_Back || event.key === Qt.Key_Escape) {
            if (pages.length > 1) {
                event.accepted = true
                goBack()
            }
        }
    }

    Item {
        id: stage
        anchors.fill: parent
        clip: true
    }

    HBanner {
        id: banner
    }

    function notify(text) { banner.show(text) }

    // --- test aid ------------------------------------------------------------------
    // BIOQUIZ_TEST="solo:5,act,pick:0,answer:1,next" drives the app step by
    // step (desktop builds), for screenshots and smoke tests.
    property var testQueue: (typeof testSteps !== "undefined" && testSteps.length > 0) ? testSteps.split(",") : []
    Timer {
        interval: 900
        repeat: true
        running: app.testQueue.length > 0
        onTriggered: {
            var q = app.testQueue.slice()
            var step = q.shift().split(":")
            app.testQueue = q
            var p = app.currentPage
            if (step[0] === "solo") game.startSolo(step[1])
            else if (step[0] === "act" && p.doAction) p.doAction()
            else if (step[0] === "pick" && p.round) { p.chosen = true; game.choose(p.round.options[parseInt(step[1])]); p.check() }
            else if (step[0] === "answer" && p.answer) p.answer(p.origAt(parseInt(step[1])))
            else if (step[0] === "next" && p.proceed) p.proceed()
            else if (step[0] === "push") app.push(step[1], {})
            else if (step[0] === "host") game.host(step[1], 1)
            else if (step[0] === "join") game.join(step[1])
            else if (step[0] === "start") game.startHostedMatch()
            console.log("test step " + step.join(":") + " -> " + (app.currentPage ? app.currentPage.pageName : "?"))
        }
    }

    // --- following the game ----------------------------------------------------
    Connections {
        target: game
        onModeChanged: app.followGame()
        onNotice: app.notify(text)
    }

    function followGame() {
        if (game.phase === "match") {
            if (!pageIs("game") && !pageIs("question") && !pageIs("choose"))
                showOnly("GamePage.qml", {})
        } else if (game.phase === "lobby") {
            if (!pageIs("lobby"))
                showOnly("LobbyPage.qml", {})
        } else if (game.phase === "idle") {
            if (pageIs("game") || pageIs("question") || pageIs("choose") || pageIs("lobby"))
                popToRoot()
        }
    }
}
