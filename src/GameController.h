#pragma once

#include <QObject>
#include <QSettings>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

#include "LanSession.h"
#include "Match.h"

class QuestionBank;

// Everything QML talks to during a game: solo games against the computer,
// hosting and joining over the local network. The host (or the solo game)
// owns the Match and sends a full snapshot of it after every change; guests
// only render what they receive and send their choices back.
class GameController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString mode READ mode NOTIFY modeChanged)            // none, solo, host, guest
    Q_PROPERTY(QString phase READ phase NOTIFY modeChanged)          // idle, joining, lobby, match
    Q_PROPERTY(int myId READ myId NOTIFY modeChanged)
    Q_PROPERTY(QVariantMap match READ match NOTIFY matchChanged)
    Q_PROPERTY(QVariantList lobbyPlayers READ lobbyPlayers NOTIFY lobbyChanged)
    Q_PROPERTY(QString lobbyLevel READ lobbyLevel NOTIFY lobbyChanged)
    Q_PROPERTY(int lobbyPasses READ lobbyPasses NOTIFY lobbyChanged)
    Q_PROPERTY(QString hostName READ hostName NOTIFY lobbyChanged)
    Q_PROPERTY(QString localAddresses READ localAddresses NOTIFY modeChanged)
    Q_PROPERTY(bool bluetoothHosting READ bluetoothHosting NOTIFY modeChanged)

    Q_PROPERTY(QString playerName READ playerName WRITE setPlayerName NOTIFY settingsChanged)
    Q_PROPERTY(int computerSkill READ computerSkill WRITE setComputerSkill NOTIFY settingsChanged)
    Q_PROPERTY(QString lastLevel READ lastLevel WRITE setLastLevel NOTIFY settingsChanged)
    // "de" or "en"; only what this device shows -- players of both languages
    // share a table, the network carries question ids, not texts.
    Q_PROPERTY(QString language READ language WRITE setLanguage NOTIFY settingsChanged)
    Q_PROPERTY(int gamesPlayed READ gamesPlayed NOTIFY settingsChanged)
    Q_PROPERTY(int gamesWon READ gamesWon NOTIFY settingsChanged)

public:
    explicit GameController(QuestionBank* bank, QObject* parent = nullptr);
    ~GameController() override;

    QString mode() const { return m_mode; }
    QString phase() const { return m_phase; }
    int myId() const { return m_myId; }
    QVariantMap match() const { return m_snapshot; }
    QVariantList lobbyPlayers() const { return m_lobby; }
    QString lobbyLevel() const { return m_level; }
    int lobbyPasses() const { return m_passes; }
    QString hostName() const { return m_hostName; }
    QString localAddresses() const;
    bool bluetoothHosting() const { return m_lan.bluetoothHosting(); }

    QString playerName() const;
    void setPlayerName(const QString& name);
    int computerSkill() const;
    void setComputerSkill(int skill);
    QString lastLevel() const;
    void setLastLevel(const QString& level);
    QString language() const { return m_language; }
    void setLanguage(const QString& language);
    int gamesPlayed() const;
    int gamesWon() const;

    Q_INVOKABLE void startSolo(const QString& level);
    Q_INVOKABLE bool host(const QString& level, int passes);
    Q_INVOKABLE void setLobbyConfig(const QString& level, int passes);
    Q_INVOKABLE void join(const QString& address);
    Q_INVOKABLE void joinBluetooth(const QString& address);
    Q_INVOKABLE bool startHostedMatch();
    Q_INVOKABLE void choose(const QString& cat);
    Q_INVOKABLE void submit(int round, const QVariantList& picks, const QVariantList& times);
    Q_INVOKABLE void rematch();
    Q_INVOKABLE void leave();
    // True while the local player still has to answer the current round.
    Q_INVOKABLE bool myTurnToPlay() const;

signals:
    void modeChanged();
    void matchChanged();
    void lobbyChanged();
    void settingsChanged();
    // A message for the user, e.g. "connection lost".
    void notice(const QString& text);
    void matchFinished(bool won);

private:
    void setMode(const QString& mode, const QString& phase);
    void reset();
    void publish();               // host/solo: snapshot to QML and all guests
    void hostChanged();           // host/solo: after any change of m_match
    void scheduleComputers();
    void broadcastLobby();
    void onMessage(int peer, const QVariantMap& message);
    void onPeerLost(int peer);
    void hostMessage(int peer, const QVariantMap& message);
    void guestMessage(const QVariantMap& message);
    void rememberQuestions();
    void recordResult();
    QString uniqueName(const QString& wanted) const;
    // German or English text, by the language of this device.
    QString txt(const char* de, const char* en) const;
    QString translateReason(const QString& reason) const;

    QuestionBank* m_bank;
    LanSession m_lan;
    QSettings m_settings;
    QString m_mode = QStringLiteral("none");
    QString m_phase = QStringLiteral("idle");
    int m_myId = 0;
    Match m_match;               // authoritative copy (host/solo only)
    QVariantMap m_snapshot;      // what QML shows
    QVariantList m_lobby;
    QString m_level = QStringLiteral("all");
    int m_passes = 1;
    QString m_hostName;
    int m_generation = 0;        // invalidates timers of an earlier match
    bool m_resultRecorded = false;
    QString m_language;
};
