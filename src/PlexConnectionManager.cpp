#include <QSslError>
#include "PlexConnectionManager.h"
#include <QNetworkRequest>
#include <QUrl>
#include <QDebug>
#include <QVariantMap>

PlexConnectionManager::PlexConnectionManager(QObject *parent) : QObject(parent) {
    m_heartbeatTimer.setInterval(30000);
    connect(&m_heartbeatTimer, &QTimer::timeout, this, &PlexConnectionManager::onHeartbeat);
    
    m_remoteGraceTimer.setInterval(500); 
    m_remoteGraceTimer.setSingleShot(true);
    connect(&m_remoteGraceTimer, &QTimer::timeout, this, &PlexConnectionManager::onRemoteGraceTimeout);
}

void PlexConnectionManager::setToken(const QString &token) {
    if (m_token != token) {
        m_token = token;
        emit tokenChanged();
    }
}

void PlexConnectionManager::setActiveUrl(const QString &url) {
    if (m_activeUrl != url) {
        qDebug() << "[ConnManager] Setting activeUrl to:" << url;
        m_activeUrl = url;
        emit activeUrlChanged();
        updateHeartbeatTimer();
    }
}

void PlexConnectionManager::startExhaustiveProbe(const QVariantList &connections) {
    if (m_isResolving) return;
    
    m_lastConnections = connections;
    m_isResolving = true;
    m_pendingReplies = 0;
    m_pendingRemoteWinner = "";
    m_remoteGraceTimer.stop();
    emit isResolvingChanged();
    
    qDebug() << "[ConnManager] Starting exhaustive probe for" << connections.size() << "candidates. TestMode:" << m_isTestMode;

    if (m_isTestMode) {
        QString localCandidate;
        QString remoteCandidate;
        for (const QVariant &v : connections) {
            QVariantMap conn = v.toMap();
            // Use https for mock matching to match real logic
            QString url = QString("https://%1:%2").arg(conn["address"].toString()).arg(conn["port"].toInt());
            bool success = m_mockResponses.value(url, false);
            qDebug() << "[ConnManager] Mock probing:" << url << "Success:" << success << "Local:" << conn["local"].toBool();
            if (success) {
                if (conn["local"].toBool()) { localCandidate = url; break; }
                else if (remoteCandidate.isEmpty()) remoteCandidate = url;
            }
        }
        
        QString winner = !localCandidate.isEmpty() ? localCandidate : remoteCandidate;
        if (!winner.isEmpty()) {
            qDebug() << "[ConnManager] Mock Winner:" << winner;
            finalizeResolution(winner);
        } else {
            qDebug() << "[ConnManager] Mock: No candidate succeeded.";
            m_isResolving = false;
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
        m_pendingReplies++;
        checkUrl(c.url, c.local);
    }
    
    if (m_pendingReplies == 0) {
        m_isResolving = false;
        emit isResolvingChanged();
        emit resolutionFinished(false);
    }
}

void PlexConnectionManager::finalizeResolution(const QString &winner) {
    if (!m_isResolving && !m_activeUrl.isEmpty()) return; 

    setActiveUrl(winner);
    m_isResolving = false;
    m_pendingRemoteWinner = "";
    m_remoteGraceTimer.stop();
    emit isResolvingChanged();
    emit resolutionFinished(true);
}

void PlexConnectionManager::reportFailure(const QString &url) {
    if (!url.isEmpty() && url == m_activeUrl) {
        qDebug() << "[ConnManager] ACTIVE URL failed:" << url << ". Triggering re-probe.";
        setActiveUrl("");
        startExhaustiveProbe(m_lastConnections);
    }
}

void PlexConnectionManager::checkUrl(const QString &url, bool isLocal) {
    QUrl qurl(url + "/identity");
    QNetworkRequest request(qurl);
    request.setRawHeader("X-Plex-Token", m_token.toUtf8());
    request.setTransferTimeout(3000);

    QNetworkReply *reply = m_manager.get(request);
    connect(reply, &QNetworkReply::sslErrors, reply, [reply](const QList<QSslError>&) { reply->ignoreSslErrors(); });
    reply->setProperty("targetUrl", url);
    reply->setProperty("isLocal", isLocal);
    
    connect(reply, &QNetworkReply::finished, this, &PlexConnectionManager::onReplyFinished);
}

void PlexConnectionManager::onReplyFinished() {
    QNetworkReply *reply = qobject_cast<QNetworkReply *>(sender());
    if (!reply) return;
    reply->deleteLater();

    m_pendingReplies--;
    QString url = reply->property("targetUrl").toString();
    bool isLocal = reply->property("isLocal").toBool();
    
    if (!m_isResolving && !m_activeUrl.isEmpty()) {
        return;
    }

    if (reply->error() == QNetworkReply::NoError) {
        qDebug() << "[ConnManager] SUCCESS reached:" << url << "(Local:" << isLocal << ")";
        
        if (isLocal) {
            finalizeResolution(url);
        } else {
            if (m_activeUrl.isEmpty() && m_pendingRemoteWinner.isEmpty()) {
                m_pendingRemoteWinner = url;
                m_remoteGraceTimer.start();
            }
        }
    } else {
        qDebug() << "[ConnManager] Candidate failed:" << url << "Error:" << reply->errorString();
    }
    
    if (m_pendingReplies <= 0) {
        if (m_activeUrl.isEmpty()) {
            if (!m_pendingRemoteWinner.isEmpty()) {
                finalizeResolution(m_pendingRemoteWinner);
            } else {
                m_isResolving = false;
                emit isResolvingChanged();
                emit resolutionFinished(false);
            }
        }
    }
}

void PlexConnectionManager::onRemoteGraceTimeout() {
    if (m_activeUrl.isEmpty() && !m_pendingRemoteWinner.isEmpty()) {
        finalizeResolution(m_pendingRemoteWinner);
    }
}

void PlexConnectionManager::onHeartbeat() {
    if (m_activeUrl.isEmpty() || !m_activeUrl.contains("192.168.")) {
        startExhaustiveProbe(m_lastConnections);
    }
}

void PlexConnectionManager::updateHeartbeatTimer() {
    if (!m_isTestMode && (m_activeUrl.isEmpty() || !m_activeUrl.contains("192.168."))) {
        if (!m_heartbeatTimer.isActive()) m_heartbeatTimer.start();
    } else {
        m_heartbeatTimer.stop();
    }
}

