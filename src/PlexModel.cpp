#include <QSslError>
#include "PlexModel.h"
#include <QUrlQuery>
#include <QNetworkRequest>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QUrl>
#include <QDebug>
#include <QProcess>
#include <QFile>
#include <QDir>
#include <QStandardPaths>
#include <QTextStream>
#include <QtDBus/QDBusInterface>
#include <QtDBus/QDBusConnection>

PlexModel::PlexModel(QObject *parent)
    : QAbstractListModel(parent), m_networkManager(new QNetworkAccessManager(this)) {
}

bool PlexModel::isFlatpak() const {
    return qEnvironmentVariableIsSet("FLATPAK_ID");
}

bool PlexModel::hasFlatpakSpawnPermission() const {
    if (!isFlatpak()) return true;
    QDBusInterface iface("org.freedesktop.Flatpak", "/org/freedesktop/Flatpak", "org.freedesktop.Flatpak", QDBusConnection::sessionBus());
    bool valid = iface.isValid();
    qDebug() << "[PermissionCheck] org.freedesktop.Flatpak valid:" << valid;
    return valid;
}

void PlexModel::checkPermissions() {
    emit permissionStatusChanged();
}

int PlexModel::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) return 0;
    return m_movies.count();
}

QVariant PlexModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= m_movies.count())
        return QVariant();

    const Movie &movie = m_movies[index.row()];
    if (role == TitleRole) return movie.title;
    else if (role == ThumbRole) return movie.thumbUrl;
    else if (role == MediaUrlRole) return movie.mediaUrl;
    else if (role == RatingKeyRole) return movie.ratingKey;
    else if (role == TypeRole) return movie.type;
    else if (role == ViewOffsetRole) return QVariant::fromValue(movie.viewOffset);
    else if (role == DurationRole) return QVariant::fromValue(movie.duration);
    else if (role == IsWatchedRole) return QVariant::fromValue(movie.isWatched);
    else if (role == ParentTitleRole) return movie.parentTitle;
    else if (role == GrandparentTitleRole) return movie.grandparentTitle;
    else if (role == ParentIndexRole) return QVariant::fromValue(movie.parentIndex);
    else if (role == IndexRole) return QVariant::fromValue(movie.index);
    else if (role == ChildCountRole) return QVariant::fromValue(movie.childCount);
    else if (role == LeafCountRole) return QVariant::fromValue(movie.leafCount);
    else if (role == ViewedLeafCountRole) return QVariant::fromValue(movie.viewedLeafCount);
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
    roles[GrandparentTitleRole] = "grandparentTitle";
    roles[ParentIndexRole] = "parentIndex";
    roles[IndexRole] = "index";
    roles[ChildCountRole] = "childCount";
    roles[LeafCountRole] = "leafCount";
    roles[ViewedLeafCountRole] = "viewedLeafCount";
    return roles;
}

void PlexModel::fetchEndpoint(const QString &serverUrl, const QString &token, const QString &endpoint) {
    m_serverUrl = serverUrl;
    m_token = token;
    QString effectiveUrl = resolveUrl(serverUrl);
    QUrl url(effectiveUrl + endpoint);
    QNetworkRequest request(url);
    request.setRawHeader("X-Plex-Token", m_token.toUtf8());
    request.setRawHeader("Accept", "application/json");
    QNetworkReply *reply = m_networkManager->get(request);
    connect(reply, &QNetworkReply::sslErrors, reply, [reply](const QList<QSslError>&) { reply->ignoreSslErrors(); });
    connect(reply, &QNetworkReply::finished, this, [this, reply]() { onReplyFinished(reply); });
}

void PlexModel::playVideo(const QString &mediaUrl) {
    if (mediaUrl.isEmpty()) return;
    QStringList args;
    args << "--fs" << "--target-colorspace-hint=yes" << "--hwdec=auto" << mediaUrl;
    QProcess::startDetached("mpv", args);
}


void PlexModel::setConnectionManager(PlexConnectionManager *cm) {
    if (m_connectionManager != cm) {
        m_connectionManager = cm;
        if (m_connectionManager) {
            connect(m_connectionManager, &PlexConnectionManager::activeUrlChanged, this, &PlexModel::currentServerUrlChanged);
        }
        emit connectionManagerChanged();
        emit currentServerUrlChanged();
    }
}

QString PlexModel::currentServerUrl() const {
    if (m_connectionManager && !m_connectionManager->activeUrl().isEmpty()) {
        return m_connectionManager->activeUrl();
    }
    return m_serverUrl;
}

QString PlexModel::resolveUrl(const QString &requestedUrl) const {
    if (!requestedUrl.isEmpty()) return requestedUrl;
    return currentServerUrl();
}

void PlexModel::onReplyFinished(QNetworkReply *reply) {
    if (reply->error() != QNetworkReply::NoError) {
        QNetworkReply::NetworkError err = reply->error();
        bool isConnectivityError = (err == QNetworkReply::TimeoutError || 
                                   err == QNetworkReply::ConnectionRefusedError ||
                                   err == QNetworkReply::HostNotFoundError ||
                                   err == QNetworkReply::RemoteHostClosedError);
                                   
        if (isConnectivityError && m_connectionManager) {
            qDebug() << "[PlexModel] Connectivity error detected:" << err;
            m_connectionManager->reportFailure(currentServerUrl());
        } else {
            qDebug() << "[PlexModel] Request failed (likely 404/401/SSL):" << err << "String:" << reply->errorString();
        }
        
        reply->deleteLater();
        return;
    }

    QByteArray rawData = reply->readAll();
    qDebug() << "[PlexModel] Received response for:" << reply->url().toString() << "Size:" << rawData.size();
    
    QJsonDocument jsonDoc = QJsonDocument::fromJson(rawData);
    if (!jsonDoc.isObject()) {
        qDebug() << "[PlexModel] Error: Response is not a JSON object";
        reply->deleteLater();
        return;
    }

    QJsonObject rootObj = jsonDoc.object();
    QJsonObject mediaContainer = rootObj["MediaContainer"].toObject();
    QJsonArray directory = mediaContainer["Metadata"].toArray();
    if (directory.isEmpty()) {
        directory = mediaContainer["Directory"].toArray(); // /library/sections uses Directory
    }

    qDebug() << "[PlexModel] Found" << directory.size() << "items in MediaContainer";

    beginResetModel();
    m_movies.clear();
    for (const QJsonValue &value : directory) {
        QJsonObject obj = value.toObject();
        Movie m;
        m.title = obj["title"].toString();
        m.ratingKey = obj["ratingKey"].toString();
        if (m.ratingKey.isEmpty()) m.ratingKey = obj["key"].toString();
        m.type = obj["type"].toString();
        
        m.viewOffset = obj["viewOffset"].toVariant().toLongLong();
        m.duration = obj["duration"].toVariant().toLongLong();
        m.isWatched = obj.contains("viewCount") && obj["viewCount"].toInt() > 0;
        m.parentTitle = obj["parentTitle"].toString();
        m.grandparentTitle = obj["grandparentTitle"].toString();
        m.parentIndex = obj["parentIndex"].toInt();
        m.index = obj["index"].toInt();
        m.childCount = obj["childCount"].toInt();
        m.leafCount = obj["leafCount"].toInt();
        m.viewedLeafCount = obj["viewedLeafCount"].toInt();
        
        // Build absolute thumb URL if needed
        QString thumb = obj["thumb"].toString();
        if (!thumb.isEmpty() && !thumb.startsWith("http")) {
             m.thumbUrl = currentServerUrl() + thumb;
        } else {
             m.thumbUrl = thumb;
        }

        // Append token for QML Image auth
        if (!m.thumbUrl.isEmpty() && !m.thumbUrl.contains("X-Plex-Token=")) {
            m.thumbUrl += (m.thumbUrl.contains("?") ? "&" : "?") + QString("X-Plex-Token=%1").arg(m_token);
        }
        
        // Parse Media URL
        if (obj.contains("Media")) {
            QJsonArray media = obj["Media"].toArray();
            if (!media.isEmpty()) {
                QJsonObject mediaObj = media.first().toObject();
                if (mediaObj.contains("Part")) {
                    QJsonArray parts = mediaObj["Part"].toArray();
                    if (!parts.isEmpty()) {
                        QJsonObject partObj = parts.first().toObject();
                        if (partObj.contains("key")) {
                            m.mediaUrl = resolveUrl(partObj["key"].toString());
                        } else if (partObj.contains("file")) {
                            m.mediaUrl = partObj["file"].toString();
                        }
                    }
                }
            }
        }

        m_movies.append(m);
    }
    endResetModel();
    qDebug() << "[PlexModel] Model updated. New row count:" << m_movies.size();

    reply->deleteLater();
}

void PlexModel::loadMockData(const QStringList &mockPaths, const QString &type, qint64 mockViewOffset, qint64 mockDuration, bool mockIsWatched) {
    beginResetModel();
    m_movies.clear();
    int i = 1;
    for (const QString &path : mockPaths) {
        Movie movie;
        movie.title = QString("Mock %1 %2").arg(type).arg(i);
        movie.thumbUrl = "";
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
    if (!m_movies.isEmpty()) emit moviesLoaded(m_movies.first().mediaUrl, m_movies.first().title);
}

void PlexModel::checkConnection(const QString &serverUrl, const QString &token, bool isTestMode) {
    if (isTestMode) {
        if (serverUrl == "http://test.url:32400" && token == "test_token") emit connectionChecked(true, "");
        else emit connectionChecked(false, "Test mode: Connection failed");
        return;
    }
    QUrl tokenUrl("https://plex.tv/api/v2/user");
    QNetworkRequest tokenReq(tokenUrl);
    tokenReq.setRawHeader("Accept", "application/json");
    tokenReq.setRawHeader("X-Plex-Token", token.toUtf8());
    QNetworkReply *tokenReply = m_networkManager->get(tokenReq);
    connect(tokenReply, &QNetworkReply::sslErrors, tokenReply, [tokenReply](const QList<QSslError>&) { tokenReply->ignoreSslErrors(); });
    connect(tokenReply, &QNetworkReply::finished, this, [this, tokenReply, serverUrl, token]() {
        tokenReply->deleteLater();
        if (tokenReply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt() == 401) {
            emit connectionChecked(false, "API Key is invalid or expired.");
            return;
        }
        QUrl serverCheckUrl(serverUrl + "/");
        QNetworkRequest serverReq(serverCheckUrl);
        serverReq.setRawHeader("Accept", "application/json");
        serverReq.setRawHeader("X-Plex-Token", token.toUtf8());
        QNetworkReply *serverReply = m_networkManager->get(serverReq);
        connect(serverReply, &QNetworkReply::sslErrors, serverReply, [serverReply](const QList<QSslError>&) { serverReply->ignoreSslErrors(); });
        connect(serverReply, &QNetworkReply::finished, this, [this, serverReply]() {
            serverReply->deleteLater();
            if (serverReply->error() != QNetworkReply::NoError) {
                emit connectionChecked(false, serverReply->errorString());
            } else {
                emit connectionChecked(true, "");
            }
        });
    });
}

void PlexModel::updateTimeline(const QString &serverUrl, const QString &token, const QString &ratingKey, const QString &state, qint64 timeMs, qint64 durationMs) {
    if (serverUrl.isEmpty() || token.isEmpty() || ratingKey.isEmpty()) return;
    QString effectiveUrl = resolveUrl(serverUrl);
    QUrl url(effectiveUrl + "/:/timeline");
    QUrlQuery query;
    query.addQueryItem("ratingKey", ratingKey);
    query.addQueryItem("key", "/library/metadata/" + ratingKey);
    query.addQueryItem("state", state);
    query.addQueryItem("time", QString::number(timeMs));
    query.addQueryItem("duration", QString::number(durationMs));
    query.addQueryItem("X-Plex-Client-Identifier", "flex-player-desktop");
    url.setQuery(query);
    QNetworkRequest request(url);
    request.setRawHeader("Accept", "application/json");
    request.setRawHeader("X-Plex-Token", token.toUtf8());
    QNetworkReply *reply = m_networkManager->get(request);
    connect(reply, &QNetworkReply::sslErrors, reply, [reply](const QList<QSslError>&) { reply->ignoreSslErrors(); });
    connect(reply, &QNetworkReply::finished, reply, &QNetworkReply::deleteLater);
}

void PlexModel::fetchItemDetails(const QString &serverUrl, const QString &token, const QString &ratingKey) {
    if (serverUrl.isEmpty() || token.isEmpty() || ratingKey.isEmpty()) return;
    QString effectiveUrl = resolveUrl(serverUrl);
    QUrl url(effectiveUrl + "/library/metadata/" + ratingKey);
    QNetworkRequest request(url);
    request.setRawHeader("Accept", "application/json");
    request.setRawHeader("X-Plex-Token", token.toUtf8());
    QNetworkReply *reply = m_networkManager->get(request);
    connect(reply, &QNetworkReply::sslErrors, reply, [reply](const QList<QSslError>&) { reply->ignoreSslErrors(); });
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        if (reply->error() == QNetworkReply::NoError) emit itemDetailsLoaded(QString::fromUtf8(reply->readAll()));
        else emit itemDetailsLoaded("{}");
    });
}

void PlexModel::executeSystemCommand(const QString &command) {
    if (command.isEmpty()) return;
    QString actualCommand = command;
    if (qEnvironmentVariableIsSet("FLATPAK_ID") && !actualCommand.startsWith("flatpak-spawn")) {
        actualCommand = "flatpak-spawn --host " + command;
    }
    QStringList args = actualCommand.split(" ", Qt::SkipEmptyParts);
    if (args.isEmpty()) return;
    QString prog = args.takeFirst();
    QProcess::startDetached(prog, args);
}


