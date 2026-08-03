#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QTimer>
#include <QtQml/qqml.h>
#include <QMap>
#include <QHash>
#include <QVariantList>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QJSValue>

class PlexServerNode : public QObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString name READ name NOTIFY nameChanged)
    Q_PROPERTY(QString activeUrl READ activeUrl NOTIFY activeUrlChanged)
    Q_PROPERTY(QString token READ token NOTIFY tokenChanged)
    Q_PROPERTY(bool isOnline READ isOnline NOTIFY isOnlineChanged)

public:
    explicit PlexServerNode(const QString &name, QNetworkAccessManager *manager, QObject *parent = nullptr);

    QString name() const { return m_name; }
    QString activeUrl() const { return m_activeUrl; }
    QString token() const { return m_token; }
    bool isOnline() const { return m_isOnline; }

    void setToken(const QString &token);
    void startProbe(const QVariantList &connections);
    Q_INVOKABLE void forceProbe();

    void setIsTestMode(bool test) { m_isTestMode = test; }
    void setMockResponses(const QMap<QString, bool> &mocks) { m_mockResponses = mocks; }

signals:
    void nameChanged();
    void activeUrlChanged();
    void tokenChanged();
    void isOnlineChanged();
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
    void setIsOnline(bool online);

    QString m_name;
    QNetworkAccessManager *m_manager;
    QString m_activeUrl;
    QString m_token;
    bool m_isResolving = false;
    bool m_isOnline = true; // Assume online until probe fails

    QTimer m_heartbeatTimer;
    QTimer m_remoteGraceTimer;
    int m_pendingReplies = 0;
    
    QString m_pendingRemoteWinner;
    QVariantList m_lastConnections;
    
    bool m_isTestMode = false;
    QMap<QString, bool> m_mockResponses;
};

class PlexConnectionManager : public QObject {
    Q_OBJECT
    QML_ELEMENT
    
    Q_PROPERTY(QString activeUrl READ activeUrl NOTIFY activeUrlChanged)
    Q_PROPERTY(QString token READ token WRITE setToken NOTIFY tokenChanged)
    Q_PROPERTY(bool isResolving READ isResolving NOTIFY isResolvingChanged)

public:
    explicit PlexConnectionManager(QObject *parent = nullptr);

    QString activeUrl() const;
    QString token() const;
    void setToken(const QString &token);
    bool isResolving() const;

    Q_INVOKABLE void startExhaustiveProbe(const QVariantList &connections);
    Q_INVOKABLE void reportFailure(const QString &url);
    
    Q_INVOKABLE void setIsTestMode(bool test);
    Q_INVOKABLE void setMockResponse(const QString &url, bool success);
    
    Q_INVOKABLE void fetchJson(const QString &url, const QString &token, QJSValue callback);

    Q_INVOKABLE void syncServers(const QString &serverListJson, const QString &globalToken);
    Q_INVOKABLE PlexServerNode* getServer(const QString &name) const;

signals:
    void activeUrlChanged();
    void tokenChanged();
    void isResolvingChanged();
    void resolutionFinished(bool success);

private slots:
    void onLegacyReplyFinished();
    void onLegacyHeartbeat();
    void onLegacyRemoteGraceTimeout();

private:
    void checkLegacyUrl(const QString &url, bool isLocal);
    void setLegacyActiveUrl(const QString &url);
    void updateLegacyHeartbeatTimer();
    void finalizeLegacyResolution(const QString &winner);

    QNetworkAccessManager m_manager;
    QHash<QString, PlexServerNode*> m_servers;
    
    // Legacy support for primary server
    QString m_legacyActiveUrl;
    QString m_legacyToken;
    bool m_legacyResolving = false;
    QTimer m_legacyHeartbeatTimer;
    QTimer m_legacyRemoteGraceTimer;
    int m_legacyPendingReplies = 0;
    QString m_legacyPendingRemoteWinner;
    QVariantList m_legacyLastConnections;
    
    bool m_isTestMode = false;
    QMap<QString, bool> m_mockResponses;
};
