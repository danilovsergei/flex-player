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

QVariantMap PlexModel::get(int index) const {
    QVariantMap map;
    if (index >= 0 && index < m_movies.size()) {
        const Movie &m = m_movies[index];
        map["title"] = m.title;
        map["mediaUrl"] = m.mediaUrl;
        map["thumbUrl"] = m.thumbUrl;
        map["ratingKey"] = m.ratingKey;
        map["type"] = m.type;
        map["viewOffset"] = m.viewOffset;
        map["duration"] = m.duration;
        map["isWatched"] = m.isWatched;
        map["parentTitle"] = m.parentTitle;
        map["grandparentTitle"] = m.grandparentTitle;
        map["parentIndex"] = m.parentIndex;
        map["index"] = m.index;
        map["childCount"] = m.childCount;
        map["leafCount"] = m.leafCount;
        map["viewedLeafCount"] = m.viewedLeafCount;
        map["serverUrl"] = m.serverUrl;
        map["serverToken"] = m.serverToken;
    }
    return map;
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
    else if (role == IsSmartRole) return QVariant::fromValue(movie.isSmart);
    else if (role == LeafCountRole) return QVariant::fromValue(movie.leafCount);
    else if (role == ViewedLeafCountRole) return QVariant::fromValue(movie.viewedLeafCount);
    else if (role == ServerUrlRole) return movie.serverUrl;
    else if (role == ServerTokenRole) return movie.serverToken;
    else if (role == ContentRole) return movie.content;
    else if (role == YearRole) return QVariant::fromValue(movie.year);
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
    roles[IsSmartRole] = "smart";
    roles[LeafCountRole] = "leafCount";
    roles[ViewedLeafCountRole] = "viewedLeafCount";
    roles[ServerUrlRole] = "serverUrl";
    roles[ServerTokenRole] = "serverToken";
    roles[ContentRole] = "content";
    roles[YearRole] = "year";
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


void PlexModel::putEndpoint(const QString &serverUrl, const QString &token, const QString &endpoint) {
    m_serverUrl = serverUrl;
    m_token = token;
    QString effectiveUrl = resolveUrl(serverUrl);
    QUrl url(effectiveUrl + endpoint);
    QNetworkRequest request(url);
    request.setRawHeader("X-Plex-Token", m_token.toUtf8());
    request.setRawHeader("Accept", "application/json");
    
    QNetworkReply *reply = m_networkManager->put(request, QByteArray());
    connect(reply, &QNetworkReply::sslErrors, reply, [reply](const QList<QSslError>&) { reply->ignoreSslErrors(); });
    connect(reply, &QNetworkReply::finished, this, [reply]() { 
        if (reply->error() != QNetworkReply::NoError) {
            qDebug() << "[PlexModel] PUT Request failed:" << reply->errorString();
        } else {
            qDebug() << "[PlexModel] PUT Request succeeded.";
        }
        reply->deleteLater(); 
    });
}

void PlexModel::postEndpoint(const QString &serverUrl, const QString &token, const QString &endpoint) {
    m_serverUrl = serverUrl;
    m_token = token;
    QString effectiveUrl = resolveUrl(serverUrl);
    QUrl url(effectiveUrl + endpoint);
    QNetworkRequest request(url);
    request.setRawHeader("X-Plex-Token", m_token.toUtf8());
    request.setRawHeader("Accept", "application/json");
    request.setRawHeader("Content-Type", "application/x-www-form-urlencoded");
    
    QNetworkReply *reply = m_networkManager->post(request, QByteArray());
    connect(reply, &QNetworkReply::sslErrors, reply, [reply](const QList<QSslError>&) { reply->ignoreSslErrors(); });
    connect(reply, &QNetworkReply::finished, this, [reply]() { 
        if (reply->error() != QNetworkReply::NoError) {
            qDebug() << "[PlexModel] POST Request failed:" << reply->errorString();
        } else {
            qDebug() << "[PlexModel] POST Request succeeded.";
        }
        reply->deleteLater(); 
    });
}

void PlexModel::deleteEndpoint(const QString &serverUrl, const QString &token, const QString &endpoint) {
    m_serverUrl = serverUrl;
    m_token = token;
    QString effectiveUrl = resolveUrl(serverUrl);
    QUrl url(effectiveUrl + endpoint);
    QNetworkRequest request(url);
    request.setRawHeader("X-Plex-Token", m_token.toUtf8());
    request.setRawHeader("Accept", "application/json");
    
    QNetworkReply *reply = m_networkManager->deleteResource(request);
    connect(reply, &QNetworkReply::sslErrors, reply, [reply](const QList<QSslError>&) { reply->ignoreSslErrors(); });
    connect(reply, &QNetworkReply::finished, this, [reply]() { 
        if (reply->error() != QNetworkReply::NoError) {
            qDebug() << "[PlexModel] DELETE Request failed:" << reply->errorString();
        } else {
            qDebug() << "[PlexModel] DELETE Request succeeded.";
        }
        reply->deleteLater(); 
    });
}

void PlexModel::addToCollection(const QString &serverUrl, const QString &token, const QString &collectionId, const QString &ids) {
    m_serverUrl = serverUrl;
    m_token = token;
    QString effectiveUrl = resolveUrl(serverUrl);
    
    // Step 1: Fetch machineIdentifier from root
    QUrl rootUrl(effectiveUrl + "/");
    QNetworkRequest rootReq(rootUrl);
    rootReq.setRawHeader("X-Plex-Token", m_token.toUtf8());
    rootReq.setRawHeader("Accept", "application/json");
    
    QNetworkReply *rootReply = m_networkManager->get(rootReq);
    connect(rootReply, &QNetworkReply::sslErrors, rootReply, [rootReply](const QList<QSslError>&) { rootReply->ignoreSslErrors(); });
    connect(rootReply, &QNetworkReply::finished, this, [this, rootReply, effectiveUrl, collectionId, ids]() {
        if (rootReply->error() == QNetworkReply::NoError) {
            QByteArray data = rootReply->readAll();
            QJsonDocument doc = QJsonDocument::fromJson(data);
            QJsonObject mc = doc.object()["MediaContainer"].toObject();
            QString machineId = mc["machineIdentifier"].toString();
            
            if (!machineId.isEmpty()) {
                // Step 2: PUT to add items
                QString uriStr = "server://" + machineId + "/com.plexapp.plugins.library/library/metadata/" + ids;
                QString encodedUri = QUrl::toPercentEncoding(uriStr, "");
                
                QUrl putUrl(effectiveUrl + "/library/collections/" + collectionId + "/items?uri=" + encodedUri);
                QNetworkRequest putReq(putUrl);
                putReq.setRawHeader("X-Plex-Token", m_token.toUtf8());
                putReq.setRawHeader("Accept", "application/json");
                
                QNetworkReply *putReply = m_networkManager->put(putReq, QByteArray());
                connect(putReply, &QNetworkReply::sslErrors, putReply, [putReply](const QList<QSslError>&) { putReply->ignoreSslErrors(); });
                connect(putReply, &QNetworkReply::finished, this, [putReply]() {
                    if (putReply->error() != QNetworkReply::NoError) {
                        qDebug() << "[PlexModel] AddToCollection PUT failed:" << putReply->errorString();
                    } else {
                        qDebug() << "[PlexModel] AddToCollection PUT succeeded.";
                    }
                    putReply->deleteLater();
                });
            } else {
                qDebug() << "[PlexModel] AddToCollection: Could not find machineIdentifier";
            }
        } else {
            qDebug() << "[PlexModel] AddToCollection Root GET failed:" << rootReply->errorString();
        }
        rootReply->deleteLater();
    });
}

void PlexModel::createSmartCollection(const QString &serverUrl, const QString &token, const QString &title, const QString &typeStr, const QString &sectionId, const QString &queryString) {
    m_serverUrl = serverUrl;
    m_token = token;
    QString effectiveUrl = resolveUrl(serverUrl);
    
    // Step 1: Fetch machineIdentifier from root
    QUrl rootUrl(effectiveUrl + "/");
    QNetworkRequest rootReq(rootUrl);
    rootReq.setRawHeader("X-Plex-Token", m_token.toUtf8());
    rootReq.setRawHeader("Accept", "application/json");
    
    QNetworkReply *rootReply = m_networkManager->get(rootReq);
    connect(rootReply, &QNetworkReply::sslErrors, rootReply, [rootReply](const QList<QSslError>&) { rootReply->ignoreSslErrors(); });
    connect(rootReply, &QNetworkReply::finished, this, [this, rootReply, effectiveUrl, title, typeStr, sectionId, queryString]() {
        if (rootReply->error() == QNetworkReply::NoError) {
            QByteArray data = rootReply->readAll();
            QJsonDocument doc = QJsonDocument::fromJson(data);
            QJsonObject mc = doc.object()["MediaContainer"].toObject();
            QString machineId = mc["machineIdentifier"].toString();
            
            if (!machineId.isEmpty()) {
                // Step 2: POST to create smart collection
                QString contentUri = "server://" + machineId + "/com.plexapp.plugins.library/library/sections/" + sectionId + "/all?" + queryString;
                QString encodedUri = QUrl::toPercentEncoding(contentUri, "");
                QString encodedTitle = QUrl::toPercentEncoding(title, "");
                
                QUrl postUrl(effectiveUrl + "/library/collections?type=" + typeStr + "&title=" + encodedTitle + "&smart=1&sectionId=" + sectionId + "&uri=" + encodedUri);
                QNetworkRequest postReq(postUrl);
                postReq.setRawHeader("X-Plex-Token", m_token.toUtf8());
                postReq.setRawHeader("Accept", "application/json");
                postReq.setRawHeader("Content-Type", "application/x-www-form-urlencoded");
                
                QNetworkReply *postReply = m_networkManager->post(postReq, QByteArray());
                connect(postReply, &QNetworkReply::sslErrors, postReply, [postReply](const QList<QSslError>&) { postReply->ignoreSslErrors(); });
                connect(postReply, &QNetworkReply::finished, this, [this, postReply]() {
                    if (postReply->error() != QNetworkReply::NoError) {
                        qDebug() << "[PlexModel] createSmartCollection POST failed:" << postReply->errorString();
                    } else {
                        qDebug() << "[PlexModel] createSmartCollection POST succeeded.";
                        emit smartCollectionCreated();
                    }
                    postReply->deleteLater();
                });
            } else {
                qDebug() << "[PlexModel] createSmartCollection: Could not find machineIdentifier";
            }
        } else {
            qDebug() << "[PlexModel] createSmartCollection Root GET failed:" << rootReply->errorString();
        }
        rootReply->deleteLater();
    });
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
    if (!m_serverUrl.isEmpty()) {
        return m_serverUrl;
    }
    if (m_connectionManager && !m_connectionManager->activeUrl().isEmpty()) {
        return m_connectionManager->activeUrl();
    }
    return "";
}

QString PlexModel::resolveUrl(const QString &requestedUrl) const {
    if (!requestedUrl.isEmpty()) return requestedUrl;
    return currentServerUrl();
}

void PlexModel::clear() {
    beginResetModel();
    m_movies.clear();
    endResetModel();
}

void PlexModel::onReplyFinished(QNetworkReply *reply) {
    if (reply->error() != QNetworkReply::NoError) {
        QNetworkReply::NetworkError err = reply->error();
        bool isConnectivityError = (err == QNetworkReply::TimeoutError || 
                                   err == QNetworkReply::ConnectionRefusedError ||
                                   err == QNetworkReply::HostNotFoundError ||
                                   err == QNetworkReply::RemoteHostClosedError);
                                   
        if (isConnectivityError && m_connectionManager) {
            qDebug() << "[PlexModel] Connectivity error detected:" << err << "for URL:" << reply->request().url().toString() << "Current Server URL:" << currentServerUrl();
            m_connectionManager->reportFailure(currentServerUrl());
        } else {
            qDebug() << "[PlexModel] Request failed (likely 404/401/SSL):" << err << "String:" << reply->errorString();
        }
        
        reply->deleteLater();
        return;
    }

    QByteArray rawData = reply->readAll();
    qDebug() << "[PlexModel] Received response for:" << reply->url().toString() << "Size:" << rawData.size();
    
    QString sanitizedStr = QString::fromUtf8(rawData);
    rawData = sanitizedStr.toUtf8();
    
    QJsonParseError parseError;
    QJsonDocument jsonDoc = QJsonDocument::fromJson(rawData, &parseError);
    if (!jsonDoc.isObject()) {
        qDebug() << "[PlexModel] Error: Response is not a JSON object. Parse Error:" << parseError.errorString() << "at offset:" << parseError.offset;
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
        if (m.title.isEmpty()) m.title = obj["tag"].toString(); // Fallback for filters
        
        m.ratingKey = obj["ratingKey"].toString();
        if (m.ratingKey.isEmpty()) m.ratingKey = obj["key"].toString();
        if (m.ratingKey.isEmpty()) m.ratingKey = obj["fastKey"].toString(); // Fallback for filters
        
        m.type = obj["type"].toString();
        
        m.viewOffset = obj["viewOffset"].toVariant().toLongLong();
        m.duration = obj["duration"].toVariant().toLongLong();
        
        m.leafCount = obj["leafCount"].toInt();
        m.viewedLeafCount = obj["viewedLeafCount"].toInt();
        m.serverUrl = currentServerUrl();
        m.serverToken = m_token;
        
        if (m.type == "show" || m.type == "season") {
            m.isWatched = (m.leafCount > 0 && m.viewedLeafCount == m.leafCount);
        } else {
            m.isWatched = obj.contains("viewCount") && obj["viewCount"].toInt() > 0;
        }
        
        m.parentTitle = obj["parentTitle"].toString();
        m.grandparentTitle = obj["grandparentTitle"].toString();
        m.parentIndex = obj["parentIndex"].toInt();
        m.index = obj["index"].toInt();
        m.childCount = obj["childCount"].toInt();
        m.isSmart = obj["smart"].toString() == "1" || obj["smart"].toBool() == true;
        m.content = obj["content"].toString();
        m.year = obj["year"].toInt();
        
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
                            QString keyStr = partObj["key"].toString();
                            if (!keyStr.isEmpty() && !keyStr.startsWith("http")) {
                                m.mediaUrl = currentServerUrl() + keyStr;
                            } else {
                                m.mediaUrl = keyStr;
                            }
                            if (!m.mediaUrl.isEmpty() && !m.mediaUrl.contains("X-Plex-Token=")) {
                                m.mediaUrl += (m.mediaUrl.contains("?") ? "&" : "?") + QString("X-Plex-Token=%1").arg(m_token);
                            }
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
        movie.serverUrl = "http://127.0.0.1:32400";
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


void PlexModel::updateSmartCollection(const QString &serverUrl, const QString &token, const QString &collectionId, const QString &sectionId, const QString &queryString) {
    m_serverUrl = serverUrl;
    m_token = token;
    QString effectiveUrl = resolveUrl(serverUrl);
    
    // Step 1: Need machineIdentifier from root
    QUrl rootUrl(effectiveUrl + "/");
    QNetworkRequest rootReq(rootUrl);
    rootReq.setRawHeader("X-Plex-Token", m_token.toUtf8());
    rootReq.setRawHeader("Accept", "application/json");
    
    QNetworkReply *rootReply = m_networkManager->get(rootReq);
    connect(rootReply, &QNetworkReply::sslErrors, rootReply, [rootReply](const QList<QSslError>&) { rootReply->ignoreSslErrors(); });
    connect(rootReply, &QNetworkReply::finished, this, [this, rootReply, effectiveUrl, collectionId, sectionId, queryString]() {
        if (rootReply->error() == QNetworkReply::NoError) {
            QByteArray data = rootReply->readAll();
            QJsonDocument doc = QJsonDocument::fromJson(data);
            QJsonObject mc = doc.object()["MediaContainer"].toObject();
            QString machineId = mc["machineIdentifier"].toString();
            
            if (!machineId.isEmpty()) {
                // Step 2: PUT to update smart collection
                QString contentUri = "server://" + machineId + "/com.plexapp.plugins.library/library/sections/" + sectionId + "/all?" + queryString;
                QString encodedUri = QUrl::toPercentEncoding(contentUri, "");
                
                QUrl putUrl(effectiveUrl + "/library/collections/" + collectionId + "?uri=" + encodedUri);
                QNetworkRequest putReq(putUrl);
                putReq.setRawHeader("X-Plex-Token", m_token.toUtf8());
                putReq.setRawHeader("Accept", "application/json");
                
                QNetworkReply *putReply = m_networkManager->put(putReq, QByteArray());
                connect(putReply, &QNetworkReply::sslErrors, putReply, [putReply](const QList<QSslError>&) { putReply->ignoreSslErrors(); });
                connect(putReply, &QNetworkReply::finished, this, [putReply]() {
                    if (putReply->error() != QNetworkReply::NoError) {
                        qDebug() << "[PlexModel] updateSmartCollection PUT failed:" << putReply->errorString();
                    } else {
                        qDebug() << "[PlexModel] updateSmartCollection PUT succeeded.";
                    }
                    putReply->deleteLater();
                });
            } else {
                qDebug() << "[PlexModel] updateSmartCollection: Could not find machineIdentifier";
            }
        } else {
            qDebug() << "[PlexModel] updateSmartCollection Root GET failed:" << rootReply->errorString();
        }
        rootReply->deleteLater();
    });
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
    m_serverUrl = serverUrl;
    m_token = token;
    emit currentServerUrlChanged();
    QString effectiveUrl = resolveUrl(serverUrl);
    QUrl url(effectiveUrl + "/library/metadata/" + ratingKey);
    QNetworkRequest request(url);
    request.setRawHeader("Accept", "application/json");
    request.setRawHeader("X-Plex-Token", token.toUtf8());
    QNetworkReply *reply = m_networkManager->get(request);
    connect(reply, &QNetworkReply::sslErrors, reply, [reply](const QList<QSslError>&) { reply->ignoreSslErrors(); });
    connect(reply, &QNetworkReply::finished, this, [this, reply, url, token]() {
        if (reply->error() == QNetworkReply::NoError) {
            emit itemDetailsLoaded(QString::fromUtf8(reply->readAll()));
        } else {
            qDebug() << "[PlexModel] fetchItemDetails failed for URL:" << url << "Token:" << token << "Error:" << reply->errorString();
            emit itemDetailsLoaded("{}");
        }
        reply->deleteLater();
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


