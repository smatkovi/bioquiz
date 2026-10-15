#pragma once

#include <QHash>
#include <QObject>
#include <QSet>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>

// All questions, categories and school levels, read once from bioquiz.json
// (built by tools/build_data.py). Read-only after load(); the game code
// draws from it by index, the network and QML refer to questions by id.
class QuestionBank : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool loaded READ loaded NOTIFY loadedChanged)
    Q_PROPERTY(QString version READ version NOTIFY loadedChanged)
    Q_PROPERTY(int questionCount READ questionCount NOTIFY loadedChanged)
    Q_PROPERTY(int bookCount READ bookCount NOTIFY loadedChanged)
    Q_PROPERTY(QVariantList categories READ categories NOTIFY loadedChanged)
    Q_PROPERTY(QVariantList levels READ levels NOTIFY loadedChanged)
    Q_PROPERTY(QString error READ error NOTIFY loadedChanged)

public:
    struct Question {
        QString id;
        QString book;
        QString level;
        QString cat;
        QString text;
        QStringList answers; // answers[0] is the right one
        QString image;       // relative to the data folder, empty without picture
        int page = 0;
    };

    explicit QuestionBank(QObject* parent = nullptr);

    // `dataDir` holds bioquiz.json and the figs/ folder.
    bool load(const QString& dataDir);

    bool loaded() const { return !m_questions.isEmpty(); }
    QString version() const { return m_version; }
    int questionCount() const { return m_questions.size(); }
    int bookCount() const;
    QVariantList categories() const { return m_categoryList; }
    QVariantList levels() const;
    QString error() const { return m_error; }

    int count() const { return m_questions.size(); }
    const Question& at(int index) const { return m_questions.at(index); }
    int indexOf(const QString& id) const { return m_byId.value(id, -1); }

    // Indices of all questions of a level ("all" for every level).
    QVector<int> pool(const QString& level) const;
    // Category keys that still have at least `minCount` questions in `pool`
    // whose index is not in `used`.
    QStringList categoriesWith(const QVector<int>& pool, const QSet<int>& used, int minCount) const;

    Q_INVOKABLE QVariantMap question(const QString& id) const;
    Q_INVOKABLE QVariantMap category(const QString& key) const;
    Q_INVOKABLE QString levelName(const QString& key) const;
    Q_INVOKABLE int poolSize(const QString& level) const { return pool(level).size(); }

signals:
    void loadedChanged();

private:
    QString imageUrl(const QString& relative) const;

    QString m_dataDir;
    QString m_version;
    QString m_error;
    QVector<Question> m_questions;
    QHash<QString, int> m_byId;
    QVariantList m_categoryList;
    QHash<QString, QVariantMap> m_categories;
    QVariantList m_levelList;
    QHash<QString, QString> m_bookTitles;
};
