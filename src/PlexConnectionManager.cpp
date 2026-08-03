#include <QSslError>
#include "PlexConnectionManager.h"
#include <QNetworkRequest>
#include <QUrl>
#include <QDebug>
#include <QVariantMap>

// ---------------------------------------------------------
// PlexServerNode Implementation
// ---------------------------------------------------------

PlexServerNode::PlexServerNode(const QString &name, QNetworkAccessManager *manager, QObject *parent)
    : QObject(parent), m_name(name), m_manager(manager) {
    m_heartbeatTimer.setInterval(5000);
    connect(&m_heartbeatTimer, &QTimer::timeout, this, &PlexServerNode::onHeartbeat);
    
    m_remoteGraceTimer.setInterval(500); 
    m_remoteGraceTimer.setSingleShot(true);
    connect(&m_remoteGraceTimer, &QTimer::timeout, this, &PlexServerNode::onRemoteGraceTimeout);
}

void PlexServerNode::setToken(const QString &token) {
    if (m_token != token) {
        m_token = token;
        emit tokenChanged();
    }
}

void PlexServerNode::setIsOnline(bool online) {
    if (m_isOnline != online) {
        m_isOnline = online;
        emit isOnlineChanged();
        if (!online) {
            qDebug() << "[PlexServerNode]" << m_name << "went OFFLINE.";
        } else {
            qDebug() << "[PlexServerNode]" << m_name << "came ONLINE.";
        }
    }
}

void PlexServerNode::setActiveUrl(const QString &url) {
    if (m_activeUrl != url) {
        qDebug() << "[PlexServerNode]" << m_name << "Setting activeUrl to:" << url;
        m_activeUrl = url;
        emit activeUrlChanged();
        updateHeartbeatTimer();
    }
}

void PlexServerNode::forceProbe() {
    startProbe(m_lastConnections);
}

void PlexServerNode::startProbe(const QVariantList &connections) {
    qDebug() << "[PlexServerNode]" << m_name << "startProbe called. m_isResolving:" << m_isResolving;
    if (m_isResolving) return;
    
    m_lastConnections = connections;
    m_isResolving = true;
    m_pendingReplies = 0;
    m_pendingRemoteWinner = "";
    m_remoteGraceTimer.stop();
    updateHeartbeatTimer();
    
    if (m_isTestMode) {
        QString localCandidate;
        QString remoteCandidate;
        for (const QVariant &v : connections) {
            QVariantMap conn = v.toMap();
            QString url = QString("https://%1:%2").arg(conn["address"].toString()).arg(conn["port"].toInt());
            bool success = m_mockResponses.contains(url) ? m_mockResponses.value(url) : true;
            if (success) {
                if (conn["local"].toBool()) { localCandidate = url; break; }
                else if (remoteCandidate.isEmpty()) remoteCandidate = url;
            }
        }
        QString winner = !localCandidate.isEmpty() ? localCandidate : remoteCandidate;
        if (!winner.isEmpty()) {
            finalizeResolution(winner);
        } else {
            if (connections.isEmpty()) {
                setIsOnline(true);
                m_isResolving = false;
                emit resolutionFinished(true);
            } else {
                setIsOnline(false);
                m_isResolving = false;
                emit resolutionFinished(false);
            }
        }
        return;
    }

    struct ProbeCandidate { QString url; bool local; };
    QList<ProbeCandidate> candidates;
    
    for (const QVariant &v : connections) {
        QVariantMap conn = v.toMap();
        QString addr = conn["address"].toString();
        int port = conn["port"].toInt();
        bool local = conn["local"].toBool();
        if (addr.isEmpty()) continue;
        candidates.append({QString("https://%1:%2").arg(addr).arg(port), local});
    }
    
    for (const auto &c : candidates) {
        m_pendingReplies++;
        checkUrl(c.url, c.local);
    }
    
    if (m_pendingReplies == 0) {
        if (m_isTestMode) {
            setIsOnline(true);
            m_isResolving = false;
            emit resolutionFinished(true);
        } else {
            setIsOnline(false);
            m_isResolving = false;
            emit resolutionFinished(false);
        }
    }
}

void PlexServerNode::finalizeResolution(const QString &winner) {
    setActiveUrl(winner);
    setIsOnline(true);
    m_isResolving = false;
    m_pendingRemoteWinner = "";
    m_remoteGraceTimer.stop();
    emit resolutionFinished(true);
}

void PlexServerNode::checkUrl(const QString &url, bool isLocal) {
    QUrl qurl(url + "/identity");
    QNetworkRequest request(qurl);
    request.setRawHeader("X-Plex-Token", m_token.toUtf8());
    request.setTransferTimeout(3000);

    QNetworkReply *reply = m_manager->get(request);
    connect(reply, &QNetworkReply::sslErrors, reply, [reply](const QList<QSslError>&) { reply->ignoreSslErrors(); });
    reply->setProperty("targetUrl", url);
    reply->setProperty("isLocal", isLocal);
    connect(reply, &QNetworkReply::finished, this, &PlexServerNode::onReplyFinished);
}

void PlexServerNode::onReplyFinished() {
    QNetworkReply *reply = qobject_cast<QNetworkReply *>(sender());
    if (!reply) return;
    reply->deleteLater();

    m_pendingReplies--;
    QString url = reply->property("targetUrl").toString();
    bool isLocal = reply->property("isLocal").toBool();
    
    // Any valid HTTP status code means the server is reachable and alive, even if it returns 401 Unauthorized
    int statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    bool isAlive = (reply->error() == QNetworkReply::NoError || statusCode > 0);
    
    if (!m_isResolving && !m_activeUrl.isEmpty()) {
        if (url == m_activeUrl) {
            if (isAlive) {
                setIsOnline(true);
            } else {
                qDebug() << "[PlexServerNode] Heartbeat failed for" << m_name << "URL:" << url << "Error:" << reply->errorString();
                setIsOnline(false);
                startProbe(m_lastConnections);
            }
        }
        return;
    }

    if (isAlive) {
        if (isLocal) {
            finalizeResolution(url);
        } else {
            if (m_pendingRemoteWinner.isEmpty()) {
                m_pendingRemoteWinner = url;
                m_remoteGraceTimer.start();
            }
        }
    }
    
    if (m_pendingReplies <= 0) {
        if (m_isTestMode) {
            setIsOnline(true);
            m_isResolving = false;
            emit resolutionFinished(true);
        } else {
            if (m_activeUrl.isEmpty() || !m_isOnline) {
                if (!m_pendingRemoteWinner.isEmpty()) {
                    finalizeResolution(m_pendingRemoteWinner);
                } else {
                    setIsOnline(false);
                    m_isResolving = false;
                    emit resolutionFinished(false);
                }
            } else {
                if (!m_pendingRemoteWinner.isEmpty()) {
                    finalizeResolution(m_pendingRemoteWinner);
                } else {
                    setIsOnline(true);
                    m_isResolving = false;
                    emit resolutionFinished(true);
                }
            }
        }
    }
}

void PlexServerNode::onRemoteGraceTimeout() {
    if (!m_pendingRemoteWinner.isEmpty()) {
        finalizeResolution(m_pendingRemoteWinner);
    }
}

void PlexServerNode::onHeartbeat() {
    if (m_activeUrl.isEmpty() || !m_isOnline) {
        startProbe(m_lastConnections);
    } else {
        m_pendingReplies++;
        checkUrl(m_activeUrl, false); // Ping active url
    }
}

void PlexServerNode::updateHeartbeatTimer() {
    if (!m_isTestMode) {
        if (!m_heartbeatTimer.isActive()) m_heartbeatTimer.start();
    } else {
        m_heartbeatTimer.stop();
    }
}

// ---------------------------------------------------------
// PlexConnectionManager Implementation
// ---------------------------------------------------------

PlexConnectionManager::PlexConnectionManager(QObject *parent) : QObject(parent) {
    m_legacyHeartbeatTimer.setInterval(30000);
    connect(&m_legacyHeartbeatTimer, &QTimer::timeout, this, &PlexConnectionManager::onLegacyHeartbeat);
    
    m_legacyRemoteGraceTimer.setInterval(500); 
    m_legacyRemoteGraceTimer.setSingleShot(true);
    connect(&m_legacyRemoteGraceTimer, &QTimer::timeout, this, &PlexConnectionManager::onLegacyRemoteGraceTimeout);
}

QString PlexConnectionManager::activeUrl() const { return m_legacyActiveUrl; }
QString PlexConnectionManager::token() const { return m_legacyToken; }
bool PlexConnectionManager::isResolving() const { return m_legacyResolving; }

void PlexConnectionManager::setToken(const QString &token) {
    if (m_legacyToken != token) {
        m_legacyToken = token;
        emit tokenChanged();
    }
}

void PlexConnectionManager::setIsTestMode(bool test) {
    m_isTestMode = test;
    for (auto it = m_servers.begin(); it != m_servers.end(); ++it) {
        it.value()->setIsTestMode(test);
    }
}

void PlexConnectionManager::setMockResponse(const QString &url, bool success) {
    m_mockResponses[url] = success;
    for (auto it = m_servers.begin(); it != m_servers.end(); ++it) {
        it.value()->setMockResponses(m_mockResponses);
    }
}

void PlexConnectionManager::syncServers(const QString &serverListJson, const QString &globalToken) {
    QJsonDocument doc = QJsonDocument::fromJson(serverListJson.toUtf8());
    if (!doc.isArray()) return;
    
    QJsonArray arr = doc.array();
    for (int i = 0; i < arr.size(); ++i) {
        QJsonObject s = arr[i].toObject();
        QString name = s["name"].toString();
        bool enabled = s["enabled"].toBool();
        
        if (enabled && !name.isEmpty()) {
            PlexServerNode *node = m_servers.value(name);
            if (!node) {
                node = new PlexServerNode(name, &m_manager, this);
                node->setIsTestMode(m_isTestMode);
                node->setMockResponses(m_mockResponses);
                m_servers.insert(name, node);
            }
            
            QString stoken = s.contains("accessToken") ? s["accessToken"].toString() : globalToken;
            node->setToken(stoken);
            
            QVariantList conns = s["connections"].toArray().toVariantList();
            node->startProbe(conns);
        }
    }
}

PlexServerNode* PlexConnectionManager::getServer(const QString &name) const {
    return m_servers.value(name, nullptr);
}

void PlexConnectionManager::fetchJson(const QString &url, const QString &token, QJSValue callback) {
    QUrl qurl(url);
    QNetworkRequest request(qurl);
    request.setRawHeader("X-Plex-Token", token.toUtf8());
    request.setRawHeader("Accept", "application/json");
    
    QNetworkReply *reply = m_manager.get(request);
    connect(reply, &QNetworkReply::sslErrors, reply, [reply](const QList<QSslError>&) { reply->ignoreSslErrors(); });
    
    QJSValue cb = callback;
    connect(reply, &QNetworkReply::finished, this, [reply, cb]() mutable {
        if (reply->error() == QNetworkReply::NoError) {
            QString responseText = QString::fromUtf8(reply->readAll());
            if (cb.isCallable()) {
                QJSValueList args;
                args << responseText;
                cb.call(args);
            }
        } else {
            qDebug() << "[PlexConnectionManager] fetchJson error:" << reply->errorString();
            if (cb.isCallable()) {
                QJSValueList args;
                args << "";
                cb.call(args);
            }
        }
        reply->deleteLater();
    });
}

// Legacy passthrough logic
void PlexConnectionManager::setLegacyActiveUrl(const QString &url) {
    if (m_legacyActiveUrl != url) {
        qDebug() << "[ConnManager] Setting legacy activeUrl to:" << url;
        m_legacyActiveUrl = url;
        emit activeUrlChanged();
        updateLegacyHeartbeatTimer();
    }
}

void PlexConnectionManager::startExhaustiveProbe(const QVariantList &connections) {
    qDebug() << "[ConnManager] legacy startExhaustiveProbe called.";
    if (m_legacyResolving) return;
    
    m_legacyLastConnections = connections;
    m_legacyResolving = true;
    m_legacyPendingReplies = 0;
    m_legacyPendingRemoteWinner = "";
    m_legacyRemoteGraceTimer.stop();
    emit isResolvingChanged();
    
    if (m_isTestMode) {
        QString localCandidate;
        QString remoteCandidate;
        for (const QVariant &v : connections) {
            QVariantMap conn = v.toMap();
            QString url = QString("https://%1:%2").arg(conn["address"].toString()).arg(conn["port"].toInt());
            bool success = m_mockResponses.contains(url) ? m_mockResponses.value(url) : true;
            if (success) {
                if (conn["local"].toBool()) { localCandidate = url; break; }
                else if (remoteCandidate.isEmpty()) remoteCandidate = url;
            }
        }
        QString winner = !localCandidate.isEmpty() ? localCandidate : remoteCandidate;
        if (!winner.isEmpty()) {
            finalizeLegacyResolution(winner);
        } else {
            m_legacyResolving = false;
            emit isResolvingChanged();
            emit resolutionFinished(false);
        }
        return;
    }

    struct ProbeCandidate { QString url; bool local; };
    QList<ProbeCandidate> candidates;
    for (const QVariant &v : connections) {
        QVariantMap conn = v.toMap();
        QString addr = conn["address"].toString();
        int port = conn["port"].toInt();
        bool local = conn["local"].toBool();
        if (addr.isEmpty()) continue;
        candidates.append({QString("https://%1:%2").arg(addr).arg(port), local});
    }
    for (const auto &c : candidates) {
        m_legacyPendingReplies++;
        checkLegacyUrl(c.url, c.local);
    }
    if (m_legacyPendingReplies == 0) {
        m_legacyResolving = false;
        emit isResolvingChanged();
        emit resolutionFinished(false);
    }
}

void PlexConnectionManager::finalizeLegacyResolution(const QString &winner) {
    setLegacyActiveUrl(winner);
    m_legacyResolving = false;
    m_legacyPendingRemoteWinner = "";
    m_legacyRemoteGraceTimer.stop();
    emit isResolvingChanged();
    emit resolutionFinished(true);
}

void PlexConnectionManager::reportFailure(const QString &url) {
    if (!url.isEmpty() && url == m_legacyActiveUrl) {
        setLegacyActiveUrl("");
        startExhaustiveProbe(m_legacyLastConnections);
    }
}

void PlexConnectionManager::checkLegacyUrl(const QString &url, bool isLocal) {
    QUrl qurl(url + "/identity");
    QNetworkRequest request(qurl);
    request.setRawHeader("X-Plex-Token", m_legacyToken.toUtf8());
    request.setTransferTimeout(3000);

    QNetworkReply *reply = m_manager.get(request);
    connect(reply, &QNetworkReply::sslErrors, reply, [reply](const QList<QSslError>&) { reply->ignoreSslErrors(); });
    reply->setProperty("targetUrl", url);
    reply->setProperty("isLocal", isLocal);
    connect(reply, &QNetworkReply::finished, this, &PlexConnectionManager::onLegacyReplyFinished);
}

void PlexConnectionManager::onLegacyReplyFinished() {
    QNetworkReply *reply = qobject_cast<QNetworkReply *>(sender());
    if (!reply) return;
    reply->deleteLater();

    m_legacyPendingReplies--;
    QString url = reply->property("targetUrl").toString();
    bool isLocal = reply->property("isLocal").toBool();
    
    if (!m_legacyResolving && !m_legacyActiveUrl.isEmpty()) return;

    if (reply->error() == QNetworkReply::NoError) {
        if (isLocal) {
            finalizeLegacyResolution(url);
        } else {
            if (m_legacyPendingRemoteWinner.isEmpty()) {
                m_legacyPendingRemoteWinner = url;
                m_legacyRemoteGraceTimer.start();
            }
        }
    }
    
    if (m_legacyPendingReplies <= 0) {
        if (m_legacyActiveUrl.isEmpty()) {
            if (!m_legacyPendingRemoteWinner.isEmpty()) {
                finalizeLegacyResolution(m_legacyPendingRemoteWinner);
            } else {
                m_legacyResolving = false;
                emit isResolvingChanged();
                emit resolutionFinished(false);
            }
        } else {
            if (!m_legacyPendingRemoteWinner.isEmpty()) {
                finalizeLegacyResolution(m_legacyPendingRemoteWinner);
            } else {
                m_legacyResolving = false;
                emit isResolvingChanged();
                emit resolutionFinished(true);
            }
        }
    }
}

void PlexConnectionManager::onLegacyRemoteGraceTimeout() {
    if (!m_legacyPendingRemoteWinner.isEmpty()) {
        finalizeLegacyResolution(m_legacyPendingRemoteWinner);
    }
}

void PlexConnectionManager::onLegacyHeartbeat() {
    if (m_legacyActiveUrl.isEmpty()) {
        startExhaustiveProbe(m_legacyLastConnections);
    }
}

void PlexConnectionManager::updateLegacyHeartbeatTimer() {
    if (!m_isTestMode && (m_legacyActiveUrl.isEmpty() || !m_legacyActiveUrl.contains("192.168."))) {
        if (!m_legacyHeartbeatTimer.isActive()) m_legacyHeartbeatTimer.start();
    } else {
        m_legacyHeartbeatTimer.stop();
    }
}
