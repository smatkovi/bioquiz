#include "QuestionBank.h"

#include <QFile>
#include <QSet>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QUrl>

QuestionBank::QuestionBank(QObject* parent)
    : QObject(parent)
{
}

bool QuestionBank::load(const QString& dataDir)
{
    m_dataDir = dataDir;
    QFile file(dataDir + QStringLiteral("/bioquiz.json"));
    if (!file.open(QIODevice::ReadOnly)) {
        m_error = QStringLiteral("Fragenkatalog fehlt: %1").arg(file.fileName());
        m_errorEn = QStringLiteral("Question catalogue missing: %1").arg(file.fileName());
        emit loadedChanged();
        return false;
    }
    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(file.readAll(), &parseError);
    if (!doc.isObject()) {
        m_error = QStringLiteral("Fragenkatalog beschädigt: %1").arg(parseError.errorString());
        m_errorEn = QStringLiteral("Question catalogue damaged: %1").arg(parseError.errorString());
        emit loadedChanged();
        return false;
    }
    const QJsonObject root = doc.object();
    m_version = root.value(QStringLiteral("version")).toString();

    m_categoryList.clear();
    m_categories.clear();
    const QJsonArray cats = root.value(QStringLiteral("categories")).toArray();
    for (const QJsonValue& value : cats) {
        QVariantMap cat = value.toObject().toVariantMap();
        const QString key = cat.value(QStringLiteral("key")).toString();
        cat.insert(QStringLiteral("tile"), QStringLiteral("qrc:/cat/%1.png").arg(key));
        m_categories.insert(key, cat);
        m_categoryList.append(cat);
    }

    m_bookTitles.clear();
    m_bookTitlesEn.clear();
    QHash<QString, QString> bookLevel;
    const QJsonArray books = root.value(QStringLiteral("books")).toArray();
    for (const QJsonValue& value : books) {
        const QJsonObject book = value.toObject();
        const QString id = book.value(QStringLiteral("id")).toString();
        m_bookTitles.insert(id, book.value(QStringLiteral("title")).toString());
        if (book.contains(QStringLiteral("title_en")))
            m_bookTitlesEn.insert(id, book.value(QStringLiteral("title_en")).toString());
        bookLevel.insert(id, book.value(QStringLiteral("level")).toString());
    }

    m_levelList = root.value(QStringLiteral("levels")).toArray().toVariantList();

    m_questions.clear();
    m_byId.clear();
    const QJsonArray questions = root.value(QStringLiteral("questions")).toArray();
    m_questions.reserve(questions.size());
    for (const QJsonValue& value : questions) {
        const QJsonObject o = value.toObject();
        Question q;
        q.id = o.value(QStringLiteral("id")).toString();
        q.book = o.value(QStringLiteral("b")).toString();
        q.level = bookLevel.value(q.book);
        q.cat = o.value(QStringLiteral("c")).toString();
        q.text = o.value(QStringLiteral("q")).toString();
        const QJsonArray answers = o.value(QStringLiteral("a")).toArray();
        for (const QJsonValue& a : answers)
            q.answers.append(a.toString());
        q.textEn = o.value(QStringLiteral("qe")).toString();
        const QJsonArray answersEn = o.value(QStringLiteral("ae")).toArray();
        for (const QJsonValue& a : answersEn)
            q.answersEn.append(a.toString());
        if (q.answersEn.size() != 4)
            q.textEn.clear();
        q.image = o.value(QStringLiteral("i")).toString();
        q.page = o.value(QStringLiteral("p")).toInt();
        if (q.answers.size() != 4 || q.id.isEmpty() || !m_categories.contains(q.cat))
            continue;
        m_byId.insert(q.id, m_questions.size());
        m_questions.append(q);
    }
    m_error.clear();
    m_errorEn.clear();
    emit loadedChanged();
    return !m_questions.isEmpty();
}

void QuestionBank::setLanguage(const QString& language)
{
    const QString lang = language == QLatin1String("en") ? QStringLiteral("en") : QStringLiteral("de");
    if (lang == m_language)
        return;
    m_language = lang;
    emit loadedChanged();
}

QVariantList QuestionBank::categories() const
{
    QVariantList result;
    for (const QVariant& value : m_categoryList)
        result.append(category(value.toMap().value(QStringLiteral("key")).toString()));
    return result;
}

QVariantList QuestionBank::levels() const
{
    // With the number of questions, so the menu can grey out empty levels.
    QHash<QString, int> counts;
    for (const Question& q : m_questions)
        counts[q.level] += 1;
    QVariantList result;
    for (const QVariant& value : m_levelList) {
        QVariantMap level = value.toMap();
        level.insert(QStringLiteral("count"), counts.value(level.value(QStringLiteral("key")).toString()));
        if (english()) {
            if (level.contains(QStringLiteral("name_en")))
                level.insert(QStringLiteral("name"), level.value(QStringLiteral("name_en")));
            if (level.contains(QStringLiteral("sub_en")))
                level.insert(QStringLiteral("sub"), level.value(QStringLiteral("sub_en")));
        }
        result.append(level);
    }
    return result;
}

int QuestionBank::bookCount() const
{
    QSet<QString> books;
    for (const Question& q : m_questions)
        books.insert(q.book);
    return books.size();
}

QVector<int> QuestionBank::pool(const QString& level) const
{
    QVector<int> result;
    const bool all = level.isEmpty() || level == QLatin1String("all");
    for (int i = 0; i < m_questions.size(); ++i) {
        if (all || m_questions.at(i).level == level)
            result.append(i);
    }
    return result;
}

QStringList QuestionBank::categoriesWith(const QVector<int>& pool, const QSet<int>& used, int minCount) const
{
    QHash<QString, int> counts;
    for (int index : pool) {
        if (!used.contains(index))
            counts[m_questions.at(index).cat] += 1;
    }
    QStringList result;
    // In the order of categories.json, so the result is deterministic.
    for (const QVariant& value : m_categoryList) {
        const QString key = value.toMap().value(QStringLiteral("key")).toString();
        if (counts.value(key) >= minCount)
            result.append(key);
    }
    return result;
}

QString QuestionBank::imageUrl(const QString& relative) const
{
    if (relative.isEmpty())
        return QString();
    const QString path = m_dataDir + QLatin1Char('/') + relative;
    if (path.startsWith(QLatin1String("assets:")) || path.startsWith(QLatin1String(":/")))
        return path.startsWith(QLatin1String(":/")) ? QStringLiteral("qrc") + path : path;
    return QUrl::fromLocalFile(path).toString();
}

QVariantMap QuestionBank::question(const QString& id) const
{
    QVariantMap result;
    const int index = indexOf(id);
    if (index < 0)
        return result;
    const Question& q = m_questions.at(index);
    result.insert(QStringLiteral("id"), q.id);
    const bool en = english() && !q.textEn.isEmpty();
    result.insert(QStringLiteral("text"), en ? q.textEn : q.text);
    result.insert(QStringLiteral("answers"), en ? q.answersEn : q.answers);
    result.insert(QStringLiteral("cat"), q.cat);
    result.insert(QStringLiteral("image"), imageUrl(q.image));
    const QString title = english() ? m_bookTitlesEn.value(q.book, m_bookTitles.value(q.book)) : m_bookTitles.value(q.book);
    result.insert(QStringLiteral("source"),
                  q.page > 0 ? (english() ? QStringLiteral("%1, p. %2") : QStringLiteral("%1, S. %2")).arg(title).arg(q.page)
                             : title);
    return result;
}

QVariantMap QuestionBank::category(const QString& key) const
{
    QVariantMap cat = m_categories.value(key);
    if (english() && cat.contains(QStringLiteral("name_en")))
        cat.insert(QStringLiteral("name"), cat.value(QStringLiteral("name_en")));
    return cat;
}

QString QuestionBank::levelName(const QString& key) const
{
    if (key.isEmpty() || key == QLatin1String("all"))
        return english() ? QStringLiteral("All levels") : QStringLiteral("Alle Schulstufen");
    for (const QVariant& value : m_levelList) {
        const QVariantMap level = value.toMap();
        if (level.value(QStringLiteral("key")).toString() == key)
            return level.value(english() && level.contains(QStringLiteral("name_en")) ? QStringLiteral("name_en") : QStringLiteral("name")).toString();
    }
    return key;
}
