#include <QFile>
#include <QFontDatabase>
#include <QSettings>
#include <QGuiApplication>
#include <QQmlContext>
#include <QStringList>
#include <QUrl>

#ifdef SAILFISH
#include <sailfishapp.h>
#include <QQuickView>
#include <QScopedPointer>
#else
#include <QQmlApplicationEngine>
#include <QQuickWindow>
#include <QTimer>
#endif

#include "BtLink.h"
#include "GameController.h"
#include "LanSession.h"
#include "QuestionBank.h"

#ifdef BIOQUIZ_STATIC_QML
// Static Qt (the portable Windows exe): QML plugins are linked in and
// registered here.
#include <QtQml/qqmlextensionplugin.h>
Q_IMPORT_QML_PLUGIN(QtQuick2Plugin)
Q_IMPORT_QML_PLUGIN(QtQmlPlugin)
Q_IMPORT_QML_PLUGIN(QtQmlModelsPlugin)
Q_IMPORT_QML_PLUGIN(QtQmlWorkerScriptPlugin)
Q_IMPORT_QML_PLUGIN(QtQuick_WindowPlugin)
#endif

#ifndef BIOQUIZ_VERSION
#define BIOQUIZ_VERSION "0.0.0"
#endif

namespace {

// Where bioquiz.json and the pictures live. BIOQUIZ_DATA overrides it, which
// is handy for running a desktop build straight from the source tree.
QString dataDir()
{
    const QByteArray env = qgetenv("BIOQUIZ_DATA");
    if (!env.isEmpty())
        return QString::fromLocal8Bit(env);
#if defined(BIOQUIZ_EMBEDDED_DATA)
    return QStringLiteral(":/data");
#elif defined(SAILFISH)
    return SailfishApp::pathTo(QStringLiteral("data")).toLocalFile();
#elif defined(Q_OS_ANDROID)
    return QStringLiteral("assets:/data");
#elif defined(Q_OS_MACOS)
    return QCoreApplication::applicationDirPath() + QStringLiteral("/../Resources/data");
#else
    return QCoreApplication::applicationDirPath() + QStringLiteral("/data");
#endif
}

// Data-folder URL for QML: assets:/ on Android, qrc: for the embedded
// Windows catalogue, file: everywhere else.
QString dirUrl(const QString& dir)
{
    if (dir.startsWith(QLatin1String("assets:")))
        return dir + QLatin1Char('/');
    if (dir.startsWith(QLatin1String(":/")))
        return QStringLiteral("qrc") + dir + QLatin1Char('/');
    return QUrl::fromLocalFile(dir + QLatin1Char('/')).toString();
}

// The Harmattan graphics and Nokia Pure belong to Nokia and travel only in
// the private data folder (data/harmattan, data/fonts). Without them the
// app uses its own look-alike graphics and the system font.
QString themeImageBase(const QString& dir)
{
    if (QFile::exists(dir + QStringLiteral("/harmattan/meegotouch-button-inverted-background.png")))
        return dirUrl(dir + QStringLiteral("/harmattan"));
    return QStringLiteral("qrc:/harmattan-free/");
}

QString loadFonts(const QString& dir)
{
    QString family;
    const QStringList files = { QStringLiteral("/fonts/NokiaPureText_Rg.ttf"),
                                QStringLiteral("/fonts/NokiaPureText_Lt.ttf"),
                                QStringLiteral("/fonts/NokiaPureText_Bd.ttf") };
    for (const QString& file : files) {
        const int id = QFontDatabase::addApplicationFont(dir + file);
        if (id >= 0 && family.isEmpty()) {
            const QStringList families = QFontDatabase::applicationFontFamilies(id);
            if (!families.isEmpty())
                family = families.first();
        }
    }
    return family.isEmpty() ? QGuiApplication::font().family() : family;
}

void exportObjects(QQmlContext* context, QuestionBank* bank, GameController* game,
                   LanBrowser* browser, BtDevices* bluetooth, const QString& fontFamily,
                   const QString& imageBase)
{
    context->setContextProperty(QStringLiteral("bank"), bank);
    context->setContextProperty(QStringLiteral("game"), game);
    context->setContextProperty(QStringLiteral("lanBrowser"), browser);
    context->setContextProperty(QStringLiteral("btDevices"), bluetooth);
    context->setContextProperty(QStringLiteral("btAvailable"), bluetooth->available());
    context->setContextProperty(QStringLiteral("appVersion"), QStringLiteral(BIOQUIZ_VERSION));
    context->setContextProperty(QStringLiteral("qtVersion"), QString::fromLatin1(qVersion()));
    context->setContextProperty(QStringLiteral("uiFontFamily"), fontFamily);
    context->setContextProperty(QStringLiteral("themeImageBase"), imageBase);
    context->setContextProperty(QStringLiteral("testSteps"), QString::fromLocal8Bit(qgetenv("BIOQUIZ_TEST")));
}

} // namespace

int main(int argc, char* argv[])
{
#ifdef SAILFISH
    QScopedPointer<QGuiApplication> app(SailfishApp::application(argc, argv));
#else
    QScopedPointer<QGuiApplication> app(new QGuiApplication(argc, argv));
#endif
    // Must match OrganizationName/ApplicationName of the Sailjail section in
    // the desktop file, or the settings are not kept on Sailfish OS.
    QCoreApplication::setOrganizationName(QStringLiteral("org.smatkovi"));
    QCoreApplication::setApplicationName(QStringLiteral("harbour-bioquiz"));

#ifdef Q_OS_WIN
    // Portable: settings in an INI file next to BioQuiz.exe instead of the
    // registry, as long as that folder is writable (e.g. a USB stick).
    {
        const QString dir = QCoreApplication::applicationDirPath();
        QFile probe(dir + QStringLiteral("/.bioquiz-write-test"));
        if (probe.open(QIODevice::WriteOnly)) {
            probe.close();
            probe.remove();
            QSettings::setDefaultFormat(QSettings::IniFormat);
            QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, dir);
        }
    }
#endif

    const QString data = dataDir();
    const QString fontFamily = loadFonts(data);
    const QString imageBase = themeImageBase(data);

    // Declared before the QML side, so they outlive every binding to them.
    QuestionBank bank;
    bank.load(data);
    GameController game(&bank);
    LanBrowser browser;
    BtDevices bluetooth;

#ifdef SAILFISH
    QScopedPointer<QQuickView> view(SailfishApp::createView());
    exportObjects(view->rootContext(), &bank, &game, &browser, &bluetooth, fontFamily, imageBase);
    view->setSource(QUrl(QStringLiteral("qrc:/qml/sailfish/harbour-bioquiz.qml")));
    view->show();
    return app->exec();
#else
    QQmlApplicationEngine engine;
    exportObjects(engine.rootContext(), &bank, &game, &browser, &bluetooth, fontFamily, imageBase);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, app.data(),
                     []() { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.load(QUrl(QStringLiteral("qrc:/qml/main.qml")));

    // Test aid: BIOQUIZ_SHOT=<file.png> saves the window after BIOQUIZ_SHOT_MS
    // (default 1500) and quits; works with QT_QPA_PLATFORM=offscreen.
    const QString shot = QString::fromLocal8Bit(qgetenv("BIOQUIZ_SHOT"));
    if (!shot.isEmpty()) {
        const int delay = qEnvironmentVariableIsSet("BIOQUIZ_SHOT_MS") ? qEnvironmentVariableIntValue("BIOQUIZ_SHOT_MS") : 1500;
        QTimer::singleShot(delay, app.data(), [&engine, shot]() {
            const QList<QObject*> roots = engine.rootObjects();
            if (QQuickWindow* window = roots.isEmpty() ? nullptr : qobject_cast<QQuickWindow*>(roots.first()))
                window->grabWindow().save(shot);
            QCoreApplication::quit();
        });
    }
    return app->exec();
#endif
}
