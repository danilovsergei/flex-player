#pragma once
#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QTimer>
#include <QtQml/qqml.h>
#include <QUuid>

class PlexAuth : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString pinCode READ pinCode NOTIFY pinCodeChanged)
    Q_PROPERTY(bool isPolling READ isPolling NOTIFY isPollingChanged)
    Q_PROPERTY(QString clientId READ clientId CONSTANT)

public:
    explicit PlexAuth(QObject *parent = nullptr);

    QString pinCode() const;
    bool isPolling() const;
    QString clientId() const { return m_clientId; }

    Q_INVOKABLE void requestPin();
    Q_INVOKABLE void cancelLogin();
    Q_INVOKABLE void setPinCode(const QString &code);
    Q_INVOKABLE void setIsPolling(bool polling);
    

signals:
    void pinCodeChanged();
    void isPollingChanged();
    void tokenReceived(const QString &token);
    void authError(const QString &errorMsg);

private slots:
    void onPinRequested();
    void pollPlex();
    void onPollFinished();

private:
    QNetworkAccessManager m_manager;
    QTimer m_pollTimer;
    QString m_pinId;
    QString m_pinCode;
    QString m_clientId;
    bool m_isPolling;
    
    
};
