#include "PlexModel.h"
#include <QUrlQuery>
#include <QNetworkRequest>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QUrl>
#include <QDebug>
#include <QProcess>

PlexModel::PlexModel(QObject *parent)
    : QAbstractListModel(parent), m_networkManager(new QNetworkAccessManager(this)) {
}

int PlexModel::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) return 0;
    return m_movies.count();
}

QVariant PlexModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= m_movies.count())
        return QVariant();

    const Movie &movie = m_movies[index.row()];
    if (role == TitleRole)
        return movie.title;
    else if (role == ThumbRole)
        return movie.thumbUrl;
    else if (role == MediaUrlRole)
        return movie.mediaUrl;
    else if (role == RatingKeyRole)
        return movie.ratingKey;
    else if (role == TypeRole)
        return movie.type;
    else if (role == ViewOffsetRole)
        return QVariant::fromValue(movie.viewOffset);
    else if (role == DurationRole)
        return QVariant::fromValue(movie.duration);
    else if (role == IsWatchedRole)
        return QVariant::fromValue(movie.isWatched);
    else if (role == ParentTitleRole)
        return movie.parentTitle;
    else if (role == ChildCountRole)
        return QVariant::fromValue(movie.childCount);
    else if (role == LeafCountRole)
        return QVariant::fromValue(movie.leafCount);
    else if (role == ViewedLeafCountRole)
        return QVariant::fromValue(movie.viewedLeafCount);

    return QVariant();
}

QHash<int, QByteArray> PlexModel::roleNames() const {
    QHash<int, QByteArray> roles;
    roles[TitleRole] = "title";
    roles[ThumbRole] = "thumbUrl";
    roles[MediaUrlRole] = "mediaUrl";
    roles[RatingKeyRole] = "ratingKey";
    roles[TypeRole] = "type";
    roles[ViewOffsetRole] = "viewOffset";
    roles[DurationRole] = "duration";
    roles[IsWatchedRole] = "isWatched";
    roles[ParentTitleRole] = "parentTitle";
    roles[ChildCountRole] = "childCount";
    roles[LeafCountRole] = "leafCount";
    roles[ViewedLeafCountRole] = "viewedLeafCount";
    return roles;
}

void PlexModel::fetchEndpoint(const QString &serverUrl, const QString &token, const QString &endpoint) {
    m_serverUrl = serverUrl;
    m_token = token;
    
    QUrl url(m_serverUrl + endpoint);
    QNetworkRequest request(url);
    request.setRawHeader("X-Plex-Token", m_token.toUtf8());
    request.setRawHeader("Accept", "application/json");

    QNetworkReply *reply = m_networkManager->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        onReplyFinished(reply);
    });
}

void PlexModel::playVideo(const QString &mediaUrl) {
    if (mediaUrl.isEmpty()) return;
    
    qDebug() << "Playing video:" << mediaUrl;
    
    QStringList args;
    args << "--fs" 
         << "--target-colorspace-hint=yes" 
         << "--hwdec=auto" 
         << mediaUrl;
         
    QProcess::startDetached("mpv", args);
}

void PlexModel::onReplyFinished(QNetworkReply *reply) {
    if (reply->error() != QNetworkReply::NoError) {
        qWarning() << "Network Error:" << reply->errorString();
        reply->deleteLater();
        return;
    }

    QByteArray response = reply->readAll();
    QJsonDocument jsonDoc = QJsonDocument::fromJson(response);
    if (!jsonDoc.isObject()) {
        reply->deleteLater();
        return;
    }

    QJsonObject rootObj = jsonDoc.object();
    QJsonObject mediaContainer = rootObj["MediaContainer"].toObject();
    QJsonArray metadataArray = mediaContainer["Metadata"].toArray();
    if (metadataArray.isEmpty()) {
        metadataArray = mediaContainer["Directory"].toArray();
    }

    beginResetModel();
    m_movies.clear();

    for (const QJsonValue &value : metadataArray) {
        QJsonObject movieObj = value.toObject();
        Movie movie;
        movie.title = movieObj["title"].toString();
        movie.ratingKey = movieObj.contains("ratingKey") ? movieObj["ratingKey"].toString() : movieObj["key"].toString();
        movie.type = movieObj["type"].toString();
        
        movie.viewOffset = movieObj.contains("viewOffset") ? movieObj["viewOffset"].toVariant().toLongLong() : 0;
        movie.duration = movieObj.contains("duration") ? movieObj["duration"].toVariant().toLongLong() : 0;
        
        movie.parentTitle = movieObj["parentTitle"].toString();
        movie.childCount = movieObj.contains("childCount") ? movieObj["childCount"].toInt() : 0;
        movie.leafCount = movieObj.contains("leafCount") ? movieObj["leafCount"].toInt() : 0;
        movie.viewedLeafCount = movieObj.contains("viewedLeafCount") ? movieObj["viewedLeafCount"].toInt() : 0;
        
        if (movie.type == "show" || movie.type == "season") {
            movie.isWatched = (movie.leafCount > 0 && movie.viewedLeafCount >= movie.leafCount);
        } else {
            movie.isWatched = movieObj.contains("viewCount") && movieObj["viewCount"].toInt() > 0;
        }
        
        qDebug() << "Parsed item:" << movie.title << "type:" << movie.type << "leafCount:" << movie.leafCount << "watched:" << movie.isWatched;

        // Construct full URL for the thumbnail
        QString thumbPath = movieObj["thumb"].toString();
        if (!thumbPath.isEmpty()) {
            if (thumbPath.contains("?")) {
                movie.thumbUrl = m_serverUrl + thumbPath + "&X-Plex-Token=" + m_token;
            } else {
                movie.thumbUrl = m_serverUrl + thumbPath + "?X-Plex-Token=" + m_token;
            }
        }
        
        // Extract Media URL
        QJsonArray mediaArray = movieObj["Media"].toArray();
        if (!mediaArray.isEmpty()) {
            QJsonArray partArray = mediaArray[0].toObject()["Part"].toArray();
            if (!partArray.isEmpty()) {
                QString partKey = partArray[0].toObject()["key"].toString();
                if (!partKey.isEmpty()) {
                    if (partKey.contains("?")) {
                        movie.mediaUrl = m_serverUrl + partKey + "&X-Plex-Token=" + m_token;
                    } else {
                        movie.mediaUrl = m_serverUrl + partKey + "?X-Plex-Token=" + m_token;
                    }
                }
            }
        }
        
        m_movies.append(movie);
    }

    endResetModel();
    
    if (!m_movies.isEmpty()) {
        emit moviesLoaded(m_movies.first().mediaUrl, m_movies.first().title);
    }
    
    reply->deleteLater();
}

void PlexModel::loadMockData(const QStringList &mockPaths, const QString &type, qint64 mockViewOffset, qint64 mockDuration, bool mockIsWatched) {
    beginResetModel();
    m_movies.clear();

    int i = 1;
    for (const QString &path : mockPaths) {
        Movie movie;
        movie.title = QString("Mock %1 %2").arg(type).arg(i);
        movie.thumbUrl = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII="; // 1x1 black pixel
        movie.mediaUrl = path;
        movie.ratingKey = QString::number(i);
        movie.type = type;
        movie.viewOffset = mockViewOffset;
        movie.duration = mockDuration;
        movie.isWatched = mockIsWatched;
        m_movies.append(movie);
        i++;
    }

    endResetModel();

    if (!m_movies.isEmpty()) {
        emit moviesLoaded(m_movies.first().mediaUrl, m_movies.first().title);
    }
}



void PlexModel::checkConnection(const QString &serverUrl, const QString &token, bool isTestMode) {
    if (isTestMode) {
        if (serverUrl == "http://test.url:32400" && token == "test_token") {
            emit connectionChecked(true, "");
        } else {
            emit connectionChecked(false, "Test mode: Connection failed");
        }
        return;
    }

    // Step 1: Validate Token against plex.tv global API first
    QUrl tokenUrl("https://plex.tv/api/v2/user");
    QNetworkRequest tokenReq(tokenUrl);
    tokenReq.setRawHeader("Accept", "application/json");
    tokenReq.setRawHeader("X-Plex-Token", token.toUtf8());

    QNetworkReply *tokenReply = m_networkManager->get(tokenReq);
    connect(tokenReply, &QNetworkReply::finished, this, [this, tokenReply, serverUrl, token, tokenUrl]() {
        tokenReply->deleteLater();
        int tokenStatus = tokenReply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        
        if (tokenStatus == 401) {
            emit connectionChecked(false, "API Key is invalid or expired. Cannot make test connection to " + tokenUrl.toString());
            return;
        } else if (tokenReply->error() != QNetworkReply::NoError && tokenStatus != 200) {
            emit connectionChecked(false, "Failed to reach Plex.tv for token validation: " + tokenReply->errorString());
            return;
        }

        // Step 2: Token is valid. Now check if the local server is reachable
        QUrl serverCheckUrl(serverUrl + "/");
        QNetworkRequest serverReq(serverCheckUrl);
        serverReq.setRawHeader("Accept", "application/json");
        serverReq.setRawHeader("X-Plex-Token", token.toUtf8());

        QNetworkReply *serverReply = m_networkManager->get(serverReq);
        connect(serverReply, &QNetworkReply::finished, this, [this, serverReply]() {
            serverReply->deleteLater();
            if (serverReply->error() != QNetworkReply::NoError) {
                QString err = serverReply->errorString();
                int statusCode = serverReply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
                if (statusCode > 0) {
                    err += " (HTTP " + QString::number(statusCode) + ")";
                } else {
                    err += " (Check your Server URL and Port)";
                }
                emit connectionChecked(false, err);
            } else {
                int statusCode = serverReply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
                if (statusCode == 200) {
                    emit connectionChecked(true, "");
                } else {
                    emit connectionChecked(false, "HTTP Error: " + QString::number(statusCode));
                }
            }
        });
    });
}

void PlexModel::updateTimeline(const QString &serverUrl, const QString &token, const QString &ratingKey, const QString &state, qint64 timeMs, qint64 durationMs) {
    if (serverUrl.isEmpty() || token.isEmpty() || ratingKey.isEmpty()) return;
    
    QString clientId = "flex-player-desktop";
    QUrl url(serverUrl + "/:/timeline");
    QUrlQuery query;
    query.addQueryItem("ratingKey", ratingKey);
    query.addQueryItem("key", "/library/metadata/" + ratingKey);
    query.addQueryItem("state", state);
    query.addQueryItem("time", QString::number(timeMs));
    query.addQueryItem("duration", QString::number(durationMs));
    query.addQueryItem("X-Plex-Client-Identifier", clientId);
    url.setQuery(query);

    QNetworkRequest request(url);
    request.setRawHeader("Accept", "application/json");
    request.setRawHeader("X-Plex-Token", token.toUtf8());

    QNetworkReply *reply = m_networkManager->get(request);
    connect(reply, &QNetworkReply::finished, reply, &QNetworkReply::deleteLater);
}

void PlexModel::fetchItemDetails(const QString &serverUrl, const QString &token, const QString &ratingKey) {
    qDebug() << "fetchItemDetails called with ratingKey:" << ratingKey << "serverUrl:" << serverUrl;
    if (serverUrl.isEmpty() || token.isEmpty() || ratingKey.isEmpty()) {
        qWarning() << "fetchItemDetails missing arguments!";
        return;
    }
    
    QUrl url(serverUrl + "/library/metadata/" + ratingKey);
    QNetworkRequest request(url);
    request.setRawHeader("Accept", "application/json");
    request.setRawHeader("X-Plex-Token", token.toUtf8());

    QNetworkReply *reply = m_networkManager->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        if (reply->error() == QNetworkReply::NoError) {
            QString json = QString::fromUtf8(reply->readAll());
            emit itemDetailsLoaded(json);
        } else {
            qWarning() << "Failed to fetch details:" << reply->errorString();
            emit itemDetailsLoaded("{}");
        }
    });
}
