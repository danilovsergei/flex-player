#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QTimer>
#include <QtQml/qqml.h>
#include <QMap>
#include <QVariantList>

class PlexConnectionManager : public QObject {
    Q_OBJECT
    QML_ELEMENT
    
    Q_PROPERTY(QString activeUrl READ activeUrl NOTIFY activeUrlChanged)
    Q_PROPERTY(QString token READ token WRITE setToken NOTIFY tokenChanged)
    Q_PROPERTY(bool isResolving READ isResolving NOTIFY isResolvingChanged)

public:
    explicit PlexConnectionManager(QObject *parent = nullptr);

    QString activeUrl() const { return m_activeUrl; }
    
    QString token() const { return m_token; }
    void setToken(const QString &token);

    bool isResolving() const { return m_isResolving; }

    Q_INVOKABLE void startExhaustiveProbe(const QVariantList &connections);
    Q_INVOKABLE void reportFailure(const QString &url);
    
    Q_INVOKABLE void setIsTestMode(bool test) { m_isTestMode = test; }
    Q_INVOKABLE void setMockResponse(const QString &url, bool success) { m_mockResponses[url] = success; }

signals:
    void activeUrlChanged();
    void tokenChanged();
    void isResolvingChanged();
    void resolutionFinished(bool success);

private slots:
    void onReplyFinished();
    void onHeartbeat();
    void onRemoteGraceTimeout();

private:
    void checkUrl(const QString &url, bool isLocal);
    void setActiveUrl(const QString &url);
    void updateHeartbeatTimer();
    void finalizeResolution(const QString &winner);

    QNetworkAccessManager m_manager;
    QString m_activeUrl;
    QString m_token;
    bool m_isResolving = false;
    
    QTimer m_heartbeatTimer;
    QTimer m_remoteGraceTimer; // Timer to wait for local if remote succeeds first
    int m_pendingReplies = 0;
    
    QString m_pendingRemoteWinner;
    QVariantList m_lastConnections;
    
    bool m_isTestMode = false;
    QMap<QString, bool> m_mockResponses;
};

