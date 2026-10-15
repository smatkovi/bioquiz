pragma Singleton
import QtQuick 2.6

// The interface language. German texts are the keys; `t()` returns the
// English one when English is chosen. Bindings that call t() re-evaluate on
// a language change (the read of `lang` is tracked), so switching works at
// once, also on Sailfish OS's Qt 5.6, which has no QQmlEngine::retranslate().
//
// Question texts, categories and school levels come translated from the
// catalogue (QuestionBank follows game.language); cat(), level() and
// question() go through here so that their bindings follow the switch too.
QtObject {
    property string lang: typeof game !== "undefined" ? game.language : "de"

    function t(s) {
        if (lang !== "en")
            return s
        var e = en[s]
        return e !== undefined ? e : s
    }
    function cat(key) {
        var l = lang
        return typeof bank !== "undefined" ? bank.category(key) : ({})
    }
    function catName(key) {
        var c = cat(key)
        return c && c.name ? c.name : ""
    }
    function level(key) {
        var l = lang
        return typeof bank !== "undefined" ? bank.levelName(key) : key
    }
    function question(id) {
        var l = lang
        return typeof bank !== "undefined" ? bank.question(id) : ({})
    }

    readonly property var en: ({
        "%1 · %2 Fragen": "%1 · %2 questions",
        "%1 Fragen": "%1 questions",
        "%1 Fragen aus %2 Schulbüchern": "%1 questions from %2 school books",
        "%1 Fragen aus allen Büchern": "%1 questions from all books",
        "%1 Fragen, entstanden aus österreichischen Biologie-Schulbüchern (%2 Bände). Nur für den privaten Gebrauch. Katalog %3.":
            "%1 questions, made from Austrian biology school books (%2 volumes). For private use only. Catalogue %3.",
        "1× herum": "1× round",
        "%1-mal": "%1 times",
        "%1 · noch %2 Plätze frei": "%1 · %2 seats left",
        "%1 Spiele gespielt, %2 gewonnen": "%1 games played, %2 won",
        "%1 Spieler": "%1 players",
        "%1 Spieler: jeder wählt %2 ein Thema, also %3 Runden.": "%1 players: everyone picks a topic %2, so %3 rounds.",
        "%1 wählt ein Thema …": "%1 is picking a topic …",
        "2× herum": "2× round",
        "3× herum": "3× round",
        "Abbrechen": "Cancel",
        "Adresse eingeben": "Enter address",
        "Allein, sechs Runden wie im Quizduell": "On your own, six rounds like QuizClash",
        "Alle Schulstufen": "All levels",
        "Andere treten über WLAN bei": "Others join over Wi-Fi",
        "Andere treten über WLAN oder Bluetooth bei": "Others join over Wi-Fi or Bluetooth",
        "Beitreten": "Join",
        "Biologie-Duell im Stil von Quizduell: allein gegen den Computer oder mit Freunden über WLAN und Bluetooth.":
            "A biology duel in the style of QuizClash: alone against the computer or with friends over Wi-Fi and Bluetooth.",
        "Bluetooth (gekoppelte Geräte)": "Bluetooth (paired devices)",
        "Computergegner": "Computer opponent",
        "Das Biologie-Duell": "The biology duel",
        "Das Spiel endet dann für alle.": "The game then ends for everyone.",
        "Dein Name": "Your name",
        "Die Adresse steht beim Gastgeber unter „So treten andere bei“.": "The host sees the address under “How others join”.",
        "Die anderen spielen ohne dich weiter.": "The others play on without you.",
        "Die offenen Fragen zählen als falsch.": "The remaining questions count as wrong.",
        " (du)": " (you)",
        "Du bist dran": "Your turn",
        "Einen Moment …": "One moment …",
        "Ein eröffnetes Spiel in der Nähe": "A game opened nearby",
        "Eine Schulstufe": "One school level",
        "einmal": "once",
        "Einstellungen": "Settings",
        "Fertig": "Done",
        "Frage %1 von %2": "Question %1 of %2",
        "Fragen": "Questions",
        "Für alle Mitspieler": "For all players",
        "Gastgeber": "Host",
        "Gastgeber: %1": "Host: %1",
        "Gefundene Spiele": "Games found",
        "Gegen den Computer": "Against the computer",
        "Gewonnen!": "You won!",
        "Im selben WLAN": "In the same Wi-Fi",
        "Im selben WLAN „Spiel beitreten“ antippen – das Spiel erscheint von selbst. Sonst diese Adresse eingeben:":
            "In the same Wi-Fi, tap “Join game” – the game shows up by itself. Otherwise enter this address:",
        "Ja": "Yes",
        "(keine Netzwerkadresse)": "(no network address)",
        "Kein Spiel gefunden": "No game found",
        "Leicht": "Easy",
        "Mehr": "More",
        "Mittel": "Medium",
        "Mitwirkende": "Credits",
        "Name: %1": "Name: %1",
        "Name im Spiel": "Name in the game",
        "Noch kein Gerät gekoppelt. Koppel das Gerät des Gastgebers einmal in den Bluetooth-Einstellungen.":
            "No device paired yet. Pair the host's device once in the Bluetooth settings.",
        "Nochmal spielen": "Play again",
        "Oberfläche im Stil von MeeGo 1.2 Harmattan (Grafiken und Nokia Pure © Nokia). Kategorie-Symbole: Material Symbols (Apache 2.0). Netzwerkcode aus Snapszer (MIT). Qt %1.":
            "Interface in the style of MeeGo 1.2 Harmattan (graphics and Nokia Pure © Nokia). Category icons: Material Symbols (Apache 2.0). Network code from Snapszer (MIT). Qt %1.",
        "Per Bluetooth: Geräte einmal koppeln, dann beim Gast unter „Spiel beitreten“ dieses Gerät wählen: %1":
            "Over Bluetooth: pair the devices once, then pick this device under “Join game” on the guest: %1",
        "Quelle: %1": "Source: %1",
        "Runde %1": "Round %1",
        "Runde %1 von %2": "Round %1 of %2",
        "Runde abbrechen?": "Abandon this round?",
        "Runden": "Rounds",
        "Schließen": "Close",
        "Schulstufe wählen": "Choose a level",
        "Schwer": "Hard",
        "So sehen dich die anderen im WLAN-Spiel.": "This is how the others see you in a network game.",
        "So treten andere bei": "How others join",
        "Spiel abgebrochen": "Game abandoned",
        "Spiel beitreten": "Join game",
        "Spielen": "Play",
        "Spielen: %1": "Play: %1",
        "Spieler (%1)": "Players (%1)",
        "Spiel eröffnen": "Host a game",
        "Spiel eröffnet": "Game open",
        "Spiel schließen?": "Close the game?",
        "Spiel starten": "Start game",
        "Spiel verlassen?": "Leave the game?",
        "Statistik": "Statistics",
        "Thema wählen": "Pick a topic",
        "Über BioQuiz": "About BioQuiz",
        "Unentschieden": "Draw",
        "Verbinde …": "Connecting …",
        "Verlassen": "Leave",
        "Verloren": "You lost",
        "Version %1": "Version %1",
        "Wähle ein Thema": "Pick a topic",
        "Warte auf %1 …": "Waiting for %1 …",
        "Warte auf den Gastgeber …": "Waiting for the host …",
        "Warte auf Mitspieler": "Waiting for players",
        "Warte auf Mitspieler …": "Waiting for players …",
        "Warte, bis %1 das Spiel startet": "Waiting for %1 to start the game",
        "Warteraum": "Waiting room",
        "Warteraum verlassen?": "Leave the waiting room?",
        "Weiter": "Next",
        "Weiterspielen": "Keep playing",
        "z. B. 192.168.1.20": "e.g. 192.168.1.20",
        "Zeit abgelaufen · %1": "Time's up · %1",
        "Zum Menü": "To the menu",
        "Zu zweit: 6 Runden, ihr wählt abwechselnd das Thema.": "Two players: 6 rounds, you take turns picking the topic.",
        "Sprache / Language": "Language / Sprache"
    })
}
