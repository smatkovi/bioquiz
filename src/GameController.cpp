#include "GameController.h"

#include "QuestionBank.h"

#include <QDateTime>
#include <QLocale>
#include <QSet>
#include <QTimer>

#include <random>

namespace {

// Bumped whenever the messages below change incompatibly.
const int kProtocol = 1;
// Player id of the computer opponent in a solo game.
const int kComputerId = 99;
// Guests a host accepts (32 players in all).
const int kMaxGuests = 31;
// How many recently played questions a device tries not to repeat.
const int kRecentLimit = 900;

QString t(const QVariantMap& m) { return m.value(QStringLiteral("t")).toString(); }

QVariantMap msg(const QString& type)
{
    QVariantMap m;
    m.insert(QStringLiteral("t"), type);
    return m;
}

QSet<QString> toSet(const QStringList& list)
{
    QSet<QString> set; // QSet's range constructor needs Qt 5.14, Sailfish has 5.6
    for (const QString& s : list)
        set.insert(s);
    return set;
}

quint32 freshSeed()
{
    std::random_device rd;
    return rd() ^ static_cast<quint32>(QDateTime::currentMSecsSinceEpoch());
}

} // namespace

GameController::GameController(QuestionBank* bank, QObject* parent)
    : QObject(parent)
    , m_bank(bank)
{
    // German on German systems, English everywhere else, until chosen.
    const QString saved = m_settings.value(QStringLiteral("language")).toString();
    m_language = !saved.isEmpty() ? saved
               : QLocale::system().language() == QLocale::German ? QStringLiteral("de") : QStringLiteral("en");
    m_bank->setLanguage(m_language);

    // By signature, so the same code builds against Qt 4 (MeeGo) as well.
    connect(&m_lan, SIGNAL(messageReceived(int,QVariantMap)), this, SLOT(onMessage(int,QVariantMap)));
    connect(&m_lan, SIGNAL(peerLost(int)), this, SLOT(onPeerLost(int)));
    connect(&m_lan, SIGNAL(peerJoined(int)), this, SLOT(onPeerJoined(int)));
    connect(&m_lan, SIGNAL(connectionFailed(QString)), this, SLOT(onConnectionFailed(QString)));
}

void GameController::onPeerJoined(int peer)
{
    if (m_mode == QLatin1String("guest")) {
        QVariantMap hello = msg(QStringLiteral("hello"));
        hello.insert(QStringLiteral("name"), playerName());
        hello.insert(QStringLiteral("protocol"), kProtocol);
        hello.insert(QStringLiteral("data"), m_bank->version());
        m_lan.sendTo(peer, hello);
    }
}

void GameController::onConnectionFailed(const QString& reason)
{
    emit notice(txt("Verbindung fehlgeschlagen: %1", "Connection failed: %1").arg(translateReason(reason)));
    reset();
}

void GameController::computerChooses()
{
    if (m_pendingChoices.isEmpty())
        return;
    const PendingChoice pending = m_pendingChoices.takeFirst();
    if (pending.generation != m_generation || m_match.current() != pending.round || m_match.rounds.isEmpty())
        return;
    const QStringList options = m_match.rounds.last().options;
    if (options.isEmpty())
        return;
    std::mt19937 rng(freshSeed());
    const QString cat = options.at(static_cast<int>(rng() % options.size()));
    if (m_match.choose(*m_bank, pending.player, cat))
        hostChanged();
}

void GameController::refreshIfCurrent(int generation)
{
    if (generation == m_generation)
        hostChanged();
}

void GameController::dropRejectedPeer()
{
    if (!m_rejectedPeers.isEmpty())
        m_lan.dropPeer(m_rejectedPeers.takeFirst());
}

GameController::~GameController()
{
    m_lan.blockSignals(true);
    m_lan.stop();
}

// --- settings ------------------------------------------------------------------

QString GameController::playerName() const
{
    const QString name = m_settings.value(QStringLiteral("playerName")).toString().trimmed();
    return name.isEmpty() ? txt("Ich", "Me") : name;
}

void GameController::setPlayerName(const QString& name)
{
    m_settings.setValue(QStringLiteral("playerName"), name.trimmed().left(20));
    emit settingsChanged();
}

int GameController::computerSkill() const
{
    return qBound(1, m_settings.value(QStringLiteral("computerSkill"), 2).toInt(), 3);
}

void GameController::setComputerSkill(int skill)
{
    m_settings.setValue(QStringLiteral("computerSkill"), qBound(1, skill, 3));
    emit settingsChanged();
}

QString GameController::lastLevel() const
{
    return m_settings.value(QStringLiteral("lastLevel"), QStringLiteral("all")).toString();
}

void GameController::setLastLevel(const QString& level)
{
    m_settings.setValue(QStringLiteral("lastLevel"), level);
    emit settingsChanged();
}

void GameController::setLanguage(const QString& language)
{
    const QString lang = language == QLatin1String("en") ? QStringLiteral("en") : QStringLiteral("de");
    if (lang == m_language)
        return;
    m_language = lang;
    m_settings.setValue(QStringLiteral("language"), lang);
    m_bank->setLanguage(lang); // before the signal, so bindings read the new texts
    emit settingsChanged();
}

QString GameController::txt(const char* de, const char* en) const
{
    return QString::fromUtf8(m_language == QLatin1String("en") ? en : de);
}

QString GameController::translateReason(const QString& reason) const
{
    // The transport layers report in German; Qt's own socket errors are English.
    if (m_language != QLatin1String("en"))
        return reason;
    static const char* const pairs[][2] = {
        { "Keine Antwort von dieser Adresse", "No answer from that address" },
        { "Keine Bluetooth-Adresse", "Not a Bluetooth address" },
        { "Dieses Gerät hat kein Bluetooth", "This device has no Bluetooth" },
        { "Bluetooth ist ausgeschaltet", "Bluetooth is switched off" },
        { "Bluetooth ist aus oder nicht erlaubt", "Bluetooth is off or not permitted" },
        { "Verbindung fehlgeschlagen", "Connection failed" },
        { "Bluetooth nicht verfügbar", "Bluetooth not available" },
        { "Keine Antwort über Bluetooth", "No answer over Bluetooth" },
    };
    for (const auto& pair : pairs) {
        if (reason == QString::fromUtf8(pair[0]))
            return QString::fromUtf8(pair[1]);
    }
    return reason;
}

int GameController::gamesPlayed() const { return m_settings.value(QStringLiteral("gamesPlayed")).toInt(); }
int GameController::gamesWon() const { return m_settings.value(QStringLiteral("gamesWon")).toInt(); }

QString GameController::localAddresses() const
{
    return LanSession::localAddresses().join(QStringLiteral(", "));
}

// --- state ---------------------------------------------------------------------

void GameController::setMode(const QString& mode, const QString& phase)
{
    m_mode = mode;
    m_phase = phase;
    emit modeChanged();
}

void GameController::reset()
{
    ++m_generation;
    m_lan.stop();
    m_match = Match();
    m_snapshot.clear();
    m_lobby.clear();
    m_hostName.clear();
    m_myId = 0;
    m_resultRecorded = false;
    setMode(QStringLiteral("none"), QStringLiteral("idle"));
    emit matchChanged();
    emit lobbyChanged();
}

void GameController::leave()
{
    if (m_mode == QLatin1String("guest"))
        m_lan.send(msg(QStringLiteral("bye")));
    else if (m_mode == QLatin1String("host"))
        m_lan.send(msg(QStringLiteral("closed")));
    reset();
}

bool GameController::myTurnToPlay() const
{
    const QVariantList rounds = m_snapshot.value(QStringLiteral("rounds")).toList();
    if (rounds.isEmpty() || m_snapshot.value(QStringLiteral("over")).toBool())
        return false;
    const QVariantMap round = rounds.last().toMap();
    return !round.value(QStringLiteral("cat")).toString().isEmpty()
        && !round.value(QStringLiteral("picks")).toMap().contains(QString::number(m_myId));
}

// --- solo ----------------------------------------------------------------------

void GameController::startSolo(const QString& level)
{
    reset();
    setLastLevel(level);
    m_match = Match();
    m_match.level = level;
    MatchPlayer me;
    me.id = 0;
    me.name = playerName();
    MatchPlayer computer;
    computer.id = kComputerId;
    computer.computer = true;
    computer.skill = computerSkill();
    computer.name = computer.skill == 1 ? txt("Computer (leicht)", "Computer (easy)")
                  : computer.skill == 3 ? txt("Computer (schwer)", "Computer (hard)") : QStringLiteral("Computer");
    m_match.players << me << computer;
    m_match.begin(*m_bank, freshSeed(), toSet(m_settings.value(QStringLiteral("recent")).toStringList()));
    m_myId = 0;
    setMode(QStringLiteral("solo"), QStringLiteral("match"));
    hostChanged();
}

// --- hosting -------------------------------------------------------------------

bool GameController::host(const QString& level, int passes)
{
    reset();
    QString error;
    // Up to 32 at one table: the host and 31 guests. Over Bluetooth a device
    // keeps at most 7 links, so large tables play over the WLAN.
    if (!m_lan.startHosting(playerName(), 2, kMaxGuests, &error)) {
        emit notice(txt("Spiel kann nicht eröffnet werden: %1", "Cannot host a game: %1").arg(translateReason(error)));
        return false;
    }
    m_level = level;
    m_passes = qMax(1, passes);
    setLastLevel(level);
    m_myId = 0;
    QVariantMap me;
    me.insert(QStringLiteral("id"), 0);
    me.insert(QStringLiteral("name"), playerName());
    m_lobby.append(me);
    m_hostName = playerName();
    setMode(QStringLiteral("host"), QStringLiteral("lobby"));
    broadcastLobby();
    return true;
}

void GameController::setLobbyConfig(const QString& level, int passes)
{
    if (m_mode != QLatin1String("host") || m_phase != QLatin1String("lobby"))
        return;
    m_level = level;
    m_passes = qMax(1, passes);
    setLastLevel(level);
    broadcastLobby();
}

void GameController::broadcastLobby()
{
    QVariantMap lobby = msg(QStringLiteral("lobby"));
    lobby.insert(QStringLiteral("players"), m_lobby);
    lobby.insert(QStringLiteral("level"), m_level);
    lobby.insert(QStringLiteral("passes"), m_passes);
    lobby.insert(QStringLiteral("host"), m_hostName);
    m_lan.send(lobby);
    emit lobbyChanged();
}

QString GameController::uniqueName(const QString& wanted) const
{
    QString base = wanted.trimmed().left(20);
    if (base.isEmpty())
        base = QStringLiteral("Gast");
    QString name = base;
    for (int n = 2; ; ++n) {
        bool taken = false;
        for (const QVariant& v : m_lobby)
            taken = taken || v.toMap().value(QStringLiteral("name")).toString() == name;
        if (!taken)
            return name;
        name = QStringLiteral("%1 %2").arg(base).arg(n);
    }
}

bool GameController::startHostedMatch()
{
    if (m_mode != QLatin1String("host") || m_lobby.size() < 2)
        return false;
    m_lan.setAcceptingGuests(false);
    m_match = Match();
    m_match.level = m_level;
    m_match.passes = m_passes;
    for (const QVariant& v : m_lobby) {
        const QVariantMap lp = v.toMap();
        MatchPlayer p;
        p.id = lp.value(QStringLiteral("id")).toInt();
        p.name = lp.value(QStringLiteral("name")).toString();
        m_match.players.append(p);
    }
    m_match.begin(*m_bank, freshSeed(), toSet(m_settings.value(QStringLiteral("recent")).toStringList()));
    m_resultRecorded = false;
    ++m_generation;
    setMode(QStringLiteral("host"), QStringLiteral("match"));
    hostChanged();
    return true;
}

void GameController::rematch()
{
    if (m_mode == QLatin1String("solo")) {
        startSolo(m_match.level);
        return;
    }
    if (m_mode != QLatin1String("host"))
        return;
    // Same table, everyone who is still connected.
    QVariantList still;
    for (const QVariant& v : m_lobby) {
        const int id = v.toMap().value(QStringLiteral("id")).toInt();
        const MatchPlayer* p = m_match.player(id);
        if (id == 0 || (p && p->connected))
            still.append(v);
    }
    m_lobby = still;
    if (m_lobby.size() < 2) {
        m_lan.setAcceptingGuests(true);
        setMode(QStringLiteral("host"), QStringLiteral("lobby"));
        m_snapshot.clear();
        emit matchChanged();
        broadcastLobby();
        return;
    }
    startHostedMatch();
}

void GameController::hostChanged()
{
    // Rounds follow each other without a pause: as soon as everybody has
    // answered, the next chooser gets the categories.
    while (m_match.advance(*m_bank)) {
    }
    publish();
    scheduleComputers();
    if (m_match.over) {
        rememberQuestions();
        recordResult();
    }
}

void GameController::publish()
{
    m_snapshot = m_match.toVariant();
    if (m_mode == QLatin1String("host")) {
        QVariantMap state = msg(QStringLiteral("state"));
        state.insert(QStringLiteral("match"), m_snapshot);
        m_lan.send(state);
    }
    emit matchChanged();
}

void GameController::scheduleComputers()
{
    if (m_match.over || m_match.rounds.isEmpty())
        return;
    const int generation = m_generation;
    const int roundIndex = m_match.current();
    const MatchRound& round = m_match.rounds.last();
    for (const MatchPlayer& p : m_match.players) {
        if (!p.computer)
            continue;
        if (round.cat.isEmpty() && round.chooser == p.id) {
            const PendingChoice pending = { generation, p.id, roundIndex };
            m_pendingChoices.append(pending);
            QTimer::singleShot(1400, this, SLOT(computerChooses()));
        } else if (!round.cat.isEmpty() && !round.picks.contains(p.id)) {
            // The computer "plays" its round at once; its answers only show
            // up next to the player's own once the player has answered too.
            std::mt19937 rng(freshSeed());
            const double chance = p.skill == 1 ? 0.45 : p.skill == 3 ? 0.88 : 0.68;
            QVector<int> picks;
            QVector<int> times;
            for (int i = 0; i < round.qids.size(); ++i) {
                const bool right = std::uniform_real_distribution<double>(0, 1)(rng) < chance;
                picks.append(right ? 0 : 1 + static_cast<int>(rng() % 3));
                times.append(2500 + static_cast<int>(rng() % 11000));
            }
            m_match.answer(p.id, roundIndex, picks, times);
            QMetaObject::invokeMethod(this, "refreshIfCurrent", Qt::QueuedConnection, Q_ARG(int, generation));
        }
    }
}

// --- joining -------------------------------------------------------------------

void GameController::join(const QString& address)
{
    reset();
    setMode(QStringLiteral("guest"), QStringLiteral("joining"));
    m_lan.joinHost(address);
}

void GameController::joinBluetooth(const QString& address)
{
    reset();
    setMode(QStringLiteral("guest"), QStringLiteral("joining"));
    m_lan.joinBluetooth(address);
}

// --- actions of the local player -----------------------------------------------

void GameController::choose(const QString& cat)
{
    if (m_mode == QLatin1String("guest")) {
        QVariantMap pick = msg(QStringLiteral("pick"));
        pick.insert(QStringLiteral("round"), m_snapshot.value(QStringLiteral("rounds")).toList().size() - 1);
        pick.insert(QStringLiteral("cat"), cat);
        m_lan.send(pick);
        return;
    }
    if (m_match.choose(*m_bank, m_myId, cat))
        hostChanged();
}

void GameController::submit(int round, const QVariantList& picks, const QVariantList& times)
{
    if (m_mode == QLatin1String("guest")) {
        QVariantMap answers = msg(QStringLiteral("answers"));
        answers.insert(QStringLiteral("round"), round);
        answers.insert(QStringLiteral("picks"), picks);
        answers.insert(QStringLiteral("ms"), times);
        m_lan.send(answers);
        return;
    }
    QVector<int> p;
    QVector<int> ms;
    for (const QVariant& v : picks)
        p.append(v.toInt());
    for (const QVariant& v : times)
        ms.append(v.toInt());
    if (m_match.answer(m_myId, round, p, ms))
        hostChanged();
}

// --- network -------------------------------------------------------------------

void GameController::onMessage(int peer, const QVariantMap& message)
{
    if (m_mode == QLatin1String("host"))
        hostMessage(peer, message);
    else if (m_mode == QLatin1String("guest"))
        guestMessage(message);
}

void GameController::hostMessage(int peer, const QVariantMap& message)
{
    const QString type = t(message);
    const int playerId = peer + 1;
    if (type == QLatin1String("hello")) {
        if (message.value(QStringLiteral("protocol")).toInt() != kProtocol
            || message.value(QStringLiteral("data")).toString() != m_bank->version()) {
            QVariantMap reject = msg(QStringLiteral("reject"));
            // A code, so every guest shows the reason in its own language.
            reject.insert(QStringLiteral("code"), QStringLiteral("version"));
            reject.insert(QStringLiteral("why"), QStringLiteral("Andere App-Version oder anderer Fragenkatalog – bitte beide Geräte aktualisieren.")); // for apps before 0.4
            m_lan.sendTo(peer, reject);
            m_rejectedPeers.append(peer);
            QTimer::singleShot(500, this, SLOT(dropRejectedPeer()));
            return;
        }
        if (m_phase != QLatin1String("lobby")) {
            QVariantMap reject = msg(QStringLiteral("reject"));
            reject.insert(QStringLiteral("code"), QStringLiteral("running"));
            reject.insert(QStringLiteral("why"), QStringLiteral("Das Spiel läuft schon."));
            m_lan.sendTo(peer, reject);
            m_rejectedPeers.append(peer);
            QTimer::singleShot(500, this, SLOT(dropRejectedPeer()));
            return;
        }
        QVariantMap player;
        player.insert(QStringLiteral("id"), playerId);
        player.insert(QStringLiteral("name"), uniqueName(message.value(QStringLiteral("name")).toString()));
        m_lobby.append(player);
        QVariantMap welcome = msg(QStringLiteral("welcome"));
        welcome.insert(QStringLiteral("you"), playerId);
        m_lan.sendTo(peer, welcome);
        broadcastLobby();
        return;
    }
    if (m_phase != QLatin1String("match"))
        return;
    if (type == QLatin1String("pick")) {
        if (message.value(QStringLiteral("round")).toInt() == m_match.current()
            && m_match.choose(*m_bank, playerId, message.value(QStringLiteral("cat")).toString()))
            hostChanged();
    } else if (type == QLatin1String("answers")) {
        QVector<int> picks;
        QVector<int> ms;
        for (const QVariant& v : message.value(QStringLiteral("picks")).toList())
            picks.append(v.toInt());
        for (const QVariant& v : message.value(QStringLiteral("ms")).toList())
            ms.append(v.toInt());
        if (m_match.answer(playerId, message.value(QStringLiteral("round")).toInt(), picks, ms))
            hostChanged();
    } else if (type == QLatin1String("bye")) {
        onPeerLost(peer);
    }
}

void GameController::onPeerLost(int peer)
{
    if (m_mode == QLatin1String("guest")) {
        if (m_phase == QLatin1String("match") && m_snapshot.value(QStringLiteral("over")).toBool()) {
            reset();
            return;
        }
        emit notice(txt("Die Verbindung zum Gastgeber ist abgebrochen.", "The connection to the host was lost."));
        reset();
        return;
    }
    if (m_mode != QLatin1String("host"))
        return;
    const int playerId = peer + 1;
    QString name;
    for (int i = 0; i < m_lobby.size(); ++i) {
        if (m_lobby.at(i).toMap().value(QStringLiteral("id")).toInt() == playerId) {
            name = m_lobby.at(i).toMap().value(QStringLiteral("name")).toString();
            if (m_phase == QLatin1String("lobby"))
                m_lobby.removeAt(i);
            break;
        }
    }
    if (m_phase == QLatin1String("lobby")) {
        broadcastLobby();
        return;
    }
    if (!name.isEmpty())
        emit notice(txt("%1 hat das Spiel verlassen.", "%1 has left the game.").arg(name));
    m_match.dropPlayer(playerId);
    hostChanged();
}

void GameController::guestMessage(const QVariantMap& message)
{
    const QString type = t(message);
    if (type == QLatin1String("welcome")) {
        m_myId = message.value(QStringLiteral("you")).toInt();
        setMode(QStringLiteral("guest"), QStringLiteral("lobby"));
    } else if (type == QLatin1String("reject")) {
        const QString code = message.value(QStringLiteral("code")).toString();
        if (code == QLatin1String("version"))
            emit notice(txt("Andere App-Version oder anderer Fragenkatalog – bitte beide Geräte aktualisieren.",
                            "Different app version or question catalogue – please update both devices."));
        else if (code == QLatin1String("running"))
            emit notice(txt("Das Spiel läuft schon.", "The game has already started."));
        else
            emit notice(message.value(QStringLiteral("why")).toString());
        reset();
    } else if (type == QLatin1String("lobby")) {
        m_lobby = message.value(QStringLiteral("players")).toList();
        m_level = message.value(QStringLiteral("level")).toString();
        m_passes = message.value(QStringLiteral("passes")).toInt();
        m_hostName = message.value(QStringLiteral("host")).toString();
        if (m_phase == QLatin1String("match")) {
            // The host went back to the lobby (not enough players for a rematch).
            m_snapshot.clear();
            setMode(QStringLiteral("guest"), QStringLiteral("lobby"));
            emit matchChanged();
        }
        emit lobbyChanged();
    } else if (type == QLatin1String("state")) {
        const bool wasOver = m_snapshot.value(QStringLiteral("over")).toBool();
        m_snapshot = message.value(QStringLiteral("match")).toMap();
        if (m_phase != QLatin1String("match")) {
            m_resultRecorded = false;
            setMode(QStringLiteral("guest"), QStringLiteral("match"));
        }
        if (wasOver && !m_snapshot.value(QStringLiteral("over")).toBool())
            m_resultRecorded = false; // rematch
        emit matchChanged();
        if (m_snapshot.value(QStringLiteral("over")).toBool()) {
            m_match = Match::fromVariant(m_snapshot);
            rememberQuestions();
            recordResult();
        }
    } else if (type == QLatin1String("closed")) {
        emit notice(txt("Der Gastgeber hat das Spiel beendet.", "The host has ended the game."));
        reset();
    }
}

// --- bookkeeping ---------------------------------------------------------------

void GameController::rememberQuestions()
{
    QStringList recent = m_settings.value(QStringLiteral("recent")).toStringList();
    for (const QString& id : m_match.usedQuestions()) {
        recent.removeAll(id);
        recent.append(id);
    }
    while (recent.size() > kRecentLimit)
        recent.removeFirst();
    m_settings.setValue(QStringLiteral("recent"), recent);
}

void GameController::recordResult()
{
    if (m_resultRecorded || m_match.aborted)
        return;
    m_resultRecorded = true;
    const QMap<int, int> scores = m_match.scores();
    int best = 0;
    for (int s : scores)
        best = qMax(best, s);
    const bool won = scores.value(m_myId) == best && best > 0;
    m_settings.setValue(QStringLiteral("gamesPlayed"), gamesPlayed() + 1);
    if (won)
        m_settings.setValue(QStringLiteral("gamesWon"), gamesWon() + 1);
    emit settingsChanged();
    emit matchFinished(won);
}
