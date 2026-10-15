#include "Match.h"

#include "QuestionBank.h"

#include <algorithm>

namespace {

QVariantList intList(const QVector<int>& values)
{
    QVariantList list;
    for (int v : values)
        list.append(v);
    return list;
}

QVector<int> toInts(const QVariant& value)
{
    QVector<int> result;
    const QVariantList list = value.toList();
    for (const QVariant& v : list)
        result.append(v.toInt());
    return result;
}

QVariantMap intMap(const QMap<int, QVector<int>>& map)
{
    QVariantMap result;
    for (auto it = map.constBegin(); it != map.constEnd(); ++it)
        result.insert(QString::number(it.key()), intList(it.value()));
    return result;
}

QMap<int, QVector<int>> toIntMap(const QVariant& value)
{
    QMap<int, QVector<int>> result;
    const QVariantMap map = value.toMap();
    for (auto it = map.constBegin(); it != map.constEnd(); ++it)
        result.insert(it.key().toInt(), toInts(it.value()));
    return result;
}

} // namespace

void Match::begin(const QuestionBank& bank, quint32 matchSeed, const QSet<QString>& avoid)
{
    seed = matchSeed;
    m_rng.seed(seed);
    m_pool = bank.pool(level);
    m_used.clear();
    m_playedCats.clear();
    m_avoid.clear();
    for (const QString& id : avoid) {
        const int index = bank.indexOf(id);
        if (index >= 0)
            m_avoid.insert(index);
    }
    rounds.clear();
    over = false;
    aborted = false;
    const int n = players.size();
    totalRounds = n <= 2 ? 6 : n * qMax(1, passes);
    openRound(bank);
}

int Match::chooserFor(int round) const
{
    if (players.isEmpty())
        return -1;
    // Skip players who left: they cannot choose.
    for (int step = 0; step < players.size(); ++step) {
        const MatchPlayer& p = players.at((round + step) % players.size());
        if (p.connected)
            return p.id;
    }
    return players.first().id;
}

void Match::openRound(const QuestionBank& bank)
{
    if (rounds.size() >= totalRounds) {
        over = true;
        return;
    }
    // Recently seen questions count as used as long as enough fresh ones are left.
    QSet<int> blocked = m_used;
    blocked.unite(m_avoid);
    QStringList available = bank.categoriesWith(m_pool, blocked, QuestionsPerRound);
    if (available.size() < 3) {
        m_avoid.clear();
        available = bank.categoriesWith(m_pool, m_used, QuestionsPerRound);
    }
    if (available.isEmpty()) {
        over = true; // the level has run out of questions
        return;
    }
    // Prefer categories that have not been played in this match yet.
    QStringList fresh;
    for (const QString& cat : available) {
        if (!m_playedCats.contains(cat))
            fresh.append(cat);
    }
    QStringList candidates = fresh.size() >= 3 ? fresh : available;
    std::shuffle(candidates.begin(), candidates.end(), m_rng);
    MatchRound round;
    round.chooser = chooserFor(rounds.size());
    round.options = candidates.mid(0, 3);
    rounds.append(round);
}

bool Match::choose(const QuestionBank& bank, int playerId, const QString& cat)
{
    if (over || rounds.isEmpty())
        return false;
    MatchRound& round = rounds.last();
    if (!round.cat.isEmpty() || round.chooser != playerId || !round.options.contains(cat))
        return false;

    QVector<int> fresh;
    QVector<int> seen;
    for (int index : m_pool) {
        if (bank.at(index).cat != cat || m_used.contains(index))
            continue;
        (m_avoid.contains(index) ? seen : fresh).append(index);
    }
    std::shuffle(fresh.begin(), fresh.end(), m_rng);
    std::shuffle(seen.begin(), seen.end(), m_rng);
    fresh += seen;
    if (fresh.size() < QuestionsPerRound)
        return false;

    round.cat = cat;
    m_playedCats.insert(cat);
    // Picture questions are the highlight of a round, but three in a row
    // crowd out the text questions: at most two per round.
    int pictures = 0;
    for (int index : fresh) {
        if (round.qids.size() >= QuestionsPerRound)
            break;
        const bool picture = !bank.at(index).image.isEmpty();
        if (picture && pictures >= 2)
            continue;
        pictures += picture ? 1 : 0;
        round.qids.append(bank.at(index).id);
        m_used.insert(index);
        QVector<int> order;
        order << 0 << 1 << 2 << 3;
        std::shuffle(order.begin(), order.end(), m_rng);
        round.orders.append(order);
    }
    for (int index : fresh) { // fill up if the picture limit left a gap
        if (round.qids.size() >= QuestionsPerRound)
            break;
        if (round.qids.contains(bank.at(index).id))
            continue;
        round.qids.append(bank.at(index).id);
        m_used.insert(index);
        QVector<int> order;
        order << 0 << 1 << 2 << 3;
        std::shuffle(order.begin(), order.end(), m_rng);
        round.orders.append(order);
    }
    return true;
}

bool Match::answer(int playerId, int roundIndex, const QVector<int>& picks, const QVector<int>& times)
{
    if (roundIndex < 0 || roundIndex >= rounds.size() || !player(playerId))
        return false;
    MatchRound& round = rounds[roundIndex];
    if (round.cat.isEmpty() || round.picks.contains(playerId) || picks.size() != round.qids.size())
        return false;
    QVector<int> clean;
    for (int p : picks)
        clean.append(p >= 0 && p <= 3 ? p : -1);
    round.picks.insert(playerId, clean);
    QVector<int> ms = times;
    ms.resize(clean.size());
    round.times.insert(playerId, ms);
    return true;
}

void Match::dropPlayer(int playerId)
{
    for (MatchPlayer& p : players) {
        if (p.id == playerId)
            p.connected = false;
    }
    if (rounds.isEmpty())
        return;
    MatchRound& round = rounds.last();
    if (!round.cat.isEmpty() && !round.picks.contains(playerId)) {
        QVector<int> timeouts(round.qids.size(), -1);
        round.picks.insert(playerId, timeouts);
        round.times.insert(playerId, QVector<int>(round.qids.size(), SecondsPerQuestion * 1000));
    }
    // A chooser who left is replaced right away.
    if (round.cat.isEmpty() && round.chooser == playerId)
        round.chooser = chooserFor(rounds.size() - 1);
    int connected = 0;
    for (const MatchPlayer& p : players)
        connected += p.connected && !p.computer ? 1 : 0;
    if (connected == 0)
        aborted = over = true;
}

bool Match::advance(const QuestionBank& bank)
{
    if (over || rounds.isEmpty() || !roundComplete(current()))
        return false;
    openRound(bank);
    return true;
}

const MatchPlayer* Match::player(int id) const
{
    for (const MatchPlayer& p : players) {
        if (p.id == id)
            return &p;
    }
    return nullptr;
}

bool Match::hasAnswered(int playerId, int round) const
{
    return round >= 0 && round < rounds.size() && rounds.at(round).picks.contains(playerId);
}

bool Match::roundComplete(int roundIndex) const
{
    if (roundIndex < 0 || roundIndex >= rounds.size())
        return false;
    const MatchRound& round = rounds.at(roundIndex);
    if (round.cat.isEmpty())
        return false;
    for (const MatchPlayer& p : players) {
        if (!round.picks.contains(p.id))
            return false;
    }
    return true;
}

QMap<int, int> Match::scores() const
{
    QMap<int, int> result;
    for (const MatchPlayer& p : players)
        result.insert(p.id, 0);
    for (const MatchRound& round : rounds) {
        for (auto it = round.picks.constBegin(); it != round.picks.constEnd(); ++it) {
            for (int pick : it.value())
                result[it.key()] += pick == 0 ? 1 : 0;
        }
    }
    return result;
}

QStringList Match::usedQuestions() const
{
    QStringList result;
    for (const MatchRound& round : rounds)
        result += round.qids;
    return result;
}

QVariantMap Match::toVariant() const
{
    QVariantMap map;
    map.insert(QStringLiteral("level"), level);
    map.insert(QStringLiteral("passes"), passes);
    map.insert(QStringLiteral("seed"), seed);
    map.insert(QStringLiteral("totalRounds"), totalRounds);
    map.insert(QStringLiteral("over"), over);
    map.insert(QStringLiteral("aborted"), aborted);
    QVariantList playerList;
    const QMap<int, int> score = scores();
    for (const MatchPlayer& p : players) {
        QVariantMap pm;
        pm.insert(QStringLiteral("id"), p.id);
        pm.insert(QStringLiteral("name"), p.name);
        pm.insert(QStringLiteral("computer"), p.computer);
        pm.insert(QStringLiteral("skill"), p.skill);
        pm.insert(QStringLiteral("connected"), p.connected);
        pm.insert(QStringLiteral("score"), score.value(p.id));
        playerList.append(pm);
    }
    map.insert(QStringLiteral("players"), playerList);
    QVariantList roundList;
    for (const MatchRound& r : rounds) {
        QVariantMap rm;
        rm.insert(QStringLiteral("chooser"), r.chooser);
        rm.insert(QStringLiteral("options"), r.options);
        rm.insert(QStringLiteral("cat"), r.cat);
        rm.insert(QStringLiteral("qids"), r.qids);
        QVariantList orders;
        for (const QVector<int>& o : r.orders)
            orders.append(QVariant(intList(o)));
        rm.insert(QStringLiteral("orders"), orders);
        rm.insert(QStringLiteral("picks"), intMap(r.picks));
        rm.insert(QStringLiteral("times"), intMap(r.times));
        roundList.append(rm);
    }
    map.insert(QStringLiteral("rounds"), roundList);
    return map;
}

Match Match::fromVariant(const QVariantMap& map)
{
    Match m;
    m.level = map.value(QStringLiteral("level")).toString();
    m.passes = map.value(QStringLiteral("passes")).toInt();
    m.seed = map.value(QStringLiteral("seed")).toUInt();
    m.totalRounds = map.value(QStringLiteral("totalRounds")).toInt();
    m.over = map.value(QStringLiteral("over")).toBool();
    m.aborted = map.value(QStringLiteral("aborted")).toBool();
    const QVariantList playerList = map.value(QStringLiteral("players")).toList();
    for (const QVariant& v : playerList) {
        const QVariantMap pm = v.toMap();
        MatchPlayer p;
        p.id = pm.value(QStringLiteral("id")).toInt();
        p.name = pm.value(QStringLiteral("name")).toString();
        p.computer = pm.value(QStringLiteral("computer")).toBool();
        p.skill = pm.value(QStringLiteral("skill")).toInt();
        p.connected = pm.value(QStringLiteral("connected")).toBool();
        m.players.append(p);
    }
    const QVariantList roundList = map.value(QStringLiteral("rounds")).toList();
    for (const QVariant& v : roundList) {
        const QVariantMap rm = v.toMap();
        MatchRound r;
        r.chooser = rm.value(QStringLiteral("chooser")).toInt();
        r.options = rm.value(QStringLiteral("options")).toStringList();
        r.cat = rm.value(QStringLiteral("cat")).toString();
        r.qids = rm.value(QStringLiteral("qids")).toStringList();
        const QVariantList orders = rm.value(QStringLiteral("orders")).toList();
        for (const QVariant& o : orders)
            r.orders.append(toInts(o));
        r.picks = toIntMap(rm.value(QStringLiteral("picks")));
        r.times = toIntMap(rm.value(QStringLiteral("times")));
        m.rounds.append(r);
    }
    return m;
}
