#pragma once

#include <QList>
#include <QMap>
#include <QSet>
#include <QString>
#include <QStringList>
#include <QVariantMap>
#include <QVector>

#include <random>

class QuestionBank;

// The rules of one match, without any I/O. The host (or the solo game) owns
// the authoritative Match and changes it; guests only receive snapshots of it
// via toVariant()/fromVariant() and render those.
//
// Flow, like Quizduell: every round one player chooses a category out of
// three offered, then everybody answers the same three questions. With two
// players they take turns choosing over six rounds; with more players each
// one chooses once per pass (one pass unless the host asks for more).
struct MatchPlayer {
    int id = -1;
    QString name;
    bool computer = false;
    int skill = 2;          // computer only: 1 easy, 2 medium, 3 hard
    bool connected = true;
};

struct MatchRound {
    int chooser = -1;                 // player id
    QStringList options;              // category keys offered
    QString cat;                      // chosen category, empty while choosing
    QStringList qids;                 // question ids
    QVector<QVector<int>> orders;     // display order of the answers per question
    QMap<int, QVector<int>> picks;    // player id -> chosen original answer index, -1 = time out
    QMap<int, QVector<int>> times;    // player id -> milliseconds per question
};

class Match
{
public:
    static const int QuestionsPerRound = 3;
    static const int SecondsPerQuestion = 20;

    QString level = QStringLiteral("all");
    int passes = 1;
    quint32 seed = 0;
    QList<MatchPlayer> players;
    QList<MatchRound> rounds;
    int totalRounds = 6;
    bool over = false;
    bool aborted = false;

    // Host side --------------------------------------------------------------
    // Sets up round one. `avoid` are question ids recently seen on this
    // device; they are only used once nothing else is left.
    void begin(const QuestionBank& bank, quint32 seed, const QSet<QString>& avoid);
    bool choose(const QuestionBank& bank, int playerId, const QString& cat);
    bool answer(int playerId, int round, const QVector<int>& picks, const QVector<int>& times);
    // Gives a disconnected player time-outs for everything still open, so the
    // others are not kept waiting.
    void dropPlayer(int playerId);
    // Starts the next round once everybody has answered. Returns true when
    // something changed.
    bool advance(const QuestionBank& bank);

    // Shared -----------------------------------------------------------------
    int current() const { return rounds.size() - 1; }
    const MatchPlayer* player(int id) const;
    bool hasAnswered(int playerId, int round) const;
    bool roundComplete(int round) const;
    QMap<int, int> scores() const;
    QStringList usedQuestions() const;

    QVariantMap toVariant() const;
    static Match fromVariant(const QVariantMap& map);

private:
    void openRound(const QuestionBank& bank);
    int chooserFor(int round) const;

    std::mt19937 m_rng;
    QVector<int> m_pool;
    QSet<int> m_used;
    QSet<int> m_avoid;
    QSet<QString> m_playedCats;
};
