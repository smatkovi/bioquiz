# BioQuiz

Ein Biologie-Quiz im Stil von Quizduell: allein gegen den Computer oder mit
bis zu 32 Leuten im selben WLAN (auf Sailfish OS, Linux und Android auch über
Bluetooth). Jede Runde wählt ein Spieler eins von drei Themen, dann
beantworten alle dieselben drei Fragen; zu zweit sechs Runden, bei mehr
Spielern wählt jeder einmal. Die Oberfläche ist MeeGo 1.2 Harmattan
nachempfunden.

Ein Quelltext für Sailfish OS (Qt 5.6, Silica-Hülle) und Qt 6 (Android, iOS,
macOS, Linux, Windows):

| Ordner | Inhalt |
|---|---|
| `src/` | Fragenbank, Spielregeln, Netzwerk (LAN, Bluetooth) |
| `qml/` | die gemeinsame Oberfläche; `sailfish/` und `main.qml` sind die Hüllen |
| `android/` | Qt-6-Projekt für Android, iOS, macOS, Linux und Windows |
| `ios/`, `macos/`, `windows/`, `linux/` | Plattform-Dateien |
| `tools/` | Katalog, Icons, freie Grafiken, Querbau |

## Was hier fehlt

Dieses öffentliche Repository enthält **keine Inhalte aus Schulbüchern**. Statt
der privaten Fragensammlung liegen in `data/` 85 eigene Beispielfragen
(`content/demo-questions.json`). Auch die Original-Grafiken von Harmattan und
die Schrift Nokia Pure sind nicht dabei: Die App nimmt dann die frei
nachgezeichneten Bilder aus `assets/harmattan-free/` und die Systemschrift.

Die App liest alles aus ihrem Datenordner (`bioquiz.json`, `figs/`, optional
`harmattan/` und `fonts/`); ein anderer Katalog lässt sich also ohne neuen
Build einsetzen.

## Bauen

- **macOS / iOS:** siehe `.github/workflows/apple.yml` (macOS-Disk-Image,
  unsigniertes iOS-Paket, Probelauf im iOS-Simulator).
- **Desktop:** `cmake -S android -B build && cmake --build build`, dann
  `build/bioquiz` (findet `data/` über einen Link neben der ausführbaren Datei).
- **Sailfish OS:** `mb2 build` mit `rpm/harbour-bioquiz.spec`.

## Lizenzen

`src/LanSession.*` und `src/BtLink.*` stammen aus
[Snapszer](https://github.com/edp17/harbour-snapszer) (MIT). Die Symbole der
Kategorien und Werkzeugleisten sind
[Material Symbols](https://github.com/google/material-design-icons)
(Apache 2.0).
