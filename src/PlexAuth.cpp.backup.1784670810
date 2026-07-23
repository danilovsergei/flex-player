#include "PlexAuth.h"
#include <QNetworkRequest>
#include <QUrlQuery>
#include <QJsonDocument>
#include <QJsonObject>
#include <QDebug>

PlexAuth::PlexAuth(QObject *parent) : QObject(parent), m_isPolling(false) {
    m_clientId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    connect(&m_pollTimer, &QTimer::timeout, this, &PlexAuth::pollPlex);
}

QString PlexAuth::pinCode() const { return m_pinCode; }
bool PlexAuth::isPolling() const { return m_isPolling; }

void PlexAuth::setPinCode(const QString &code) {
    if (m_pinCode != code) {
        m_pinCode = code;
        emit pinCodeChanged();
    }
}

void PlexAuth::setIsPolling(bool polling) {
    if (m_isPolling != polling) {
        m_isPolling = polling;
        emit isPollingChanged();
    }
}

void PlexAuth::requestPin() {
    QUrl url("https://plex.tv/api/v2/pins");
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/x-www-form-urlencoded");
    request.setRawHeader("X-Plex-Product", "Flex Player");
    request.setRawHeader("X-Plex-Client-Identifier", m_clientId.toUtf8());
    request.setRawHeader("Accept", "application/json");

    QUrlQuery query;
    query.addQueryItem("strong", "true");

    QNetworkReply *reply = m_manager.post(request, query.toString(QUrl::FullyEncoded).toUtf8());
    connect(reply, &QNetworkReply::finished, this, &PlexAuth::onPinRequested);
}

void PlexAuth::onPinRequested() {
    QNetworkReply *reply = qobject_cast<QNetworkReply *>(sender());
    if (!reply) return;
    reply->deleteLater();

    if (reply->error() != QNetworkReply::NoError) {
        emit authError("Failed to request PIN: " + reply->errorString());
        return;
    }

    QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
    QJsonObject obj = doc.object();
    
    if (obj.contains("id") && obj.contains("code")) {
        m_pinId = QString::number(obj["id"].toInt());
        setPinCode(obj["code"].toString());
        
        setIsPolling(true);
        m_pollTimer.start(3000); // Poll every 3 seconds
    } else {
        emit authError("Invalid response from Plex API");
    }
}

void PlexAuth::pollPlex() {
    if (m_pinId.isEmpty()) return;

    QUrl url("https://plex.tv/api/v2/pins/" + m_pinId);
    QNetworkRequest request(url);
    request.setRawHeader("X-Plex-Product", "Flex Player");
    request.setRawHeader("X-Plex-Client-Identifier", m_clientId.toUtf8());
    request.setRawHeader("Accept", "application/json");

    QNetworkReply *reply = m_manager.get(request);
    connect(reply, &QNetworkReply::finished, this, &PlexAuth::onPollFinished);
}

void PlexAuth::onPollFinished() {
    QNetworkReply *reply = qobject_cast<QNetworkReply *>(sender());
    if (!reply) return;
    reply->deleteLater();

    if (reply->error() != QNetworkReply::NoError) {
        return; // Ignore network errors during polling, could be transient
    }

    QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
    QJsonObject obj = doc.object();
    
    if (obj.contains("authToken") && !obj["authToken"].isNull() && !obj["authToken"].toString().isEmpty()) {
        cancelLogin();
        emit tokenReceived(obj["authToken"].toString());
    }
}

void PlexAuth::cancelLogin() {
    m_pollTimer.stop();
    setIsPolling(false);
    setPinCode("");
    m_pinId = "";
}
