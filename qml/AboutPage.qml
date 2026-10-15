import QtQuick 2.6
import "."

HPage {
    id: page
    pageName: "about"
    title: Lang.t("Über BioQuiz")
    subtitle: Lang.t("Version %1").arg(appVersion)

    Flickable {
        anchors.fill: parent
        contentHeight: column.height + 2 * Theme.margin
        clip: true

        Column {
            id: column
            x: Theme.margin
            y: Theme.margin
            width: parent.width - 2 * Theme.margin
            spacing: Theme.spacing

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                source: "qrc:/appicon/bioquiz-256.png"
                width: 128 * Theme.u
                height: width
                mipmap: true
            }
            HLabel {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: Lang.t("Biologie-Duell im Stil von Quizduell: allein gegen den Computer oder mit Freunden über WLAN und Bluetooth.")
                color: Theme.secondaryText
            }

            HSection { text: Lang.t("Fragen"); x: -Theme.margin; width: column.width + 2 * Theme.margin }
            HLabel {
                width: parent.width
                text: Lang.t("%1 Fragen, entstanden aus österreichischen Biologie-Schulbüchern (%2 Bände). Nur für den privaten Gebrauch. Katalog %3.")
                      .arg(bank.questionCount).arg(bank.bookCount).arg(bank.version)
                font.pixelSize: Theme.fontSmall
            }

            HSection { text: Lang.t("Mitwirkende"); x: -Theme.margin; width: column.width + 2 * Theme.margin }
            HLabel {
                width: parent.width
                text: Lang.t("Oberfläche im Stil von MeeGo 1.2 Harmattan (Grafiken und Nokia Pure © Nokia). Kategorie-Symbole: Material Symbols (Apache 2.0). Netzwerkcode aus Snapszer (MIT). Qt %1.").arg(qtVersion)
                font.pixelSize: Theme.fontSmall
                color: Theme.secondaryText
            }
        }
    }
}
