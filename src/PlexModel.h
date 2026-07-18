#pragma once

#include <QAbstractListModel>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QList>
#include <QString>
#include <QStringList>

struct Movie {
    QString title;
    QString thumbUrl;
    QString mediaUrl;
    QString ratingKey;
    QString type;
    qint64 viewOffset = 0; // in milliseconds
    qint64 duration = 0;   // in milliseconds
    bool isWatched = false;
    QString parentTitle;
    int childCount = 0;
    int leafCount = 0;
    int viewedLeafCount = 0;
};

class PlexModel : public QAbstractListModel {
    Q_OBJECT
public:
    enum MovieRoles {
        TitleRole = Qt::UserRole + 1,
        ThumbRole,
        MediaUrlRole,
        RatingKeyRole,
        TypeRole,
        ViewOffsetRole,
        DurationRole,
        IsWatchedRole,
        ParentTitleRole,
        ChildCountRole,
        LeafCountRole,
        ViewedLeafCountRole
    };

    explicit PlexModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void fetchEndpoint(const QString &serverUrl, const QString &token, const QString &endpoint);
    Q_INVOKABLE void checkConnection(const QString &serverUrl, const QString &token, bool isTestMode = false);
    Q_INVOKABLE void loadMockData(const QStringList &mockPaths, const QString &type = "movie", qint64 mockViewOffset = 0, qint64 mockDuration = 0, bool mockIsWatched = false);
    Q_INVOKABLE void playVideo(const QString &mediaUrl);
    Q_INVOKABLE void fetchItemDetails(const QString &serverUrl, const QString &token, const QString &ratingKey);
    Q_INVOKABLE void updateTimeline(const QString &serverUrl, const QString &token, const QString &ratingKey, const QString &state, qint64 timeMs, qint64 durationMs);

signals:
    void moviesLoaded(const QString &firstMediaUrl, const QString &firstTitle);
    void connectionChecked(bool success, const QString &errorMessage);
    void itemDetailsLoaded(const QString &jsonString);

private slots:
    void onReplyFinished(QNetworkReply *reply);

private:
    QList<Movie> m_movies;
    QNetworkAccessManager *m_networkManager;
    QString m_serverUrl;
    QString m_token;
};
