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

void PlexModel::checkPermissions() {
    emit permissionStatusChanged();
}

bool PlexModel::hasFlatpakSpawnPermission() const {
    if (!isFlatpak()) return true;
    QDBusInterface iface("org.freedesktop.Flatpak", "/org/freedesktop/Flatpak", "org.freedesktop.Flatpak", QDBusConnection::sessionBus());
    return iface.isValid();
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
    else if (role == GrandparentTitleRole)
        return movie.grandparentTitle;
    else if (role == ParentIndexRole)
        return QVariant::fromValue(movie.parentIndex);
    else if (role == IndexRole)
        return QVariant::fromValue(movie.index);
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
    roles[GrandparentTitleRole] = "grandparentTitle";
    roles[ParentIndexRole] = "parentIndex";
    roles[IndexRole] = "index";
    roles[ChildCountRole] = "childCount";
    roles[LeafCountRole] = "leafCount";
    roles[ViewedLeafCountRole] = "viewedLeafCount";
    return roles;
}

void PlexModel::fetchEndpoint(const QString &serverUrl, const QString &token, const QString &endpoint) {
    qDebug() << "[PlexModel] Fetching:" << endpoint;
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
        
        movie.parentTitle = movieObj["parentTitle"].toVariant().toString();
        movie.grandparentTitle = movieObj["grandparentTitle"].toVariant().toString();
        movie.parentIndex = movieObj.contains("parentIndex") ? movieObj["parentIndex"].toVariant().toInt() : 0;
        movie.index = movieObj.contains("index") ? movieObj["index"].toVariant().toInt() : 0;
        movie.childCount = movieObj.contains("childCount") ? movieObj["childCount"].toVariant().toInt() : 0;
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


void PlexModel::executeSystemCommand(const QString &command) {
    if (command.isEmpty()) return;
    
    QString actualCommand = command;
    if (qEnvironmentVariableIsSet("FLATPAK_ID")) {
        if (!actualCommand.startsWith("flatpak-spawn")) {
            actualCommand = "flatpak-spawn --host " + command;
        }
    }
    
    QProcess process;
    QStringList args = actualCommand.split(" ", Qt::SkipEmptyParts);
    QString prog = args.takeFirst();
    process.start(prog, args);
    process.waitForFinished();
    
    QString output = process.readAllStandardOutput();
    QString error = process.readAllStandardError();
    
    qDebug() << "[SystemCommand] Executed:" << actualCommand;
    if (!output.isEmpty()) qDebug() << "[SystemCommand] Output:" << output.trimmed();
    if (!error.isEmpty()) qDebug() << "[SystemCommand] Error:" << error.trimmed();
}

void PlexModel::deployHdrScript(bool enable, const QString &enableCmd, const QString &disableCmd) {
    qDebug() << "[DeployHdrScript] Called with enable:" << enable << "enableCmd:" << enableCmd << "disableCmd:" << disableCmd;
    QString configDir;
    if (qEnvironmentVariableIsSet("FLATPAK_ID")) {
        configDir = QStandardPaths::writableLocation(QStandardPaths::HomeLocation) + "/.var/app/" + qEnvironmentVariable("FLATPAK_ID") + "/config/flex-player/mpv/scripts";
    } else {
        configDir = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation) + "/flex-player/mpv/scripts";
    }
    
    QDir dir(configDir);
    if (!dir.exists()) {
        dir.mkpath(".");
    }
    
    QString scriptPath = configDir + "/flex_hdr.lua";
    
    // Hard cleanup of ALL possible script names (legacy and current)
    QStringList legacyFiles;
    legacyFiles << "flex_hdr.lua" << "flex_hdr.lua" << "hdr-toggle.lua" << "kde_hdr_toggle.lua";
    for (const QString &f : legacyFiles) {
        if (QFile::exists(configDir + "/" + f)) {
            QFile::remove(configDir + "/" + f);
            qDebug() << "[DeployHdrScript] Removed legacy/conflicting script:" << f;
        }
    }

    if (!enable) return;
    
    QString luaContent = R"(
-- Auto-generated HDR toggle script
local mp = require 'mp'

local hdr_was_enabled = false
local current_file_is_hdr = false

local function split_by_space(str)
    local result = {}
    for word in string.gmatch(str, "%S+") do
        table.insert(result, word)
    end
    return result
end

local function execute_command(cmd)
    local actual_cmd = cmd
    local is_flatpak = os.getenv("FLATPAK_ID")
    if is_flatpak and not string.match(actual_cmd, "^flatpak%-spawn") then
        actual_cmd = "flatpak-spawn --host " .. cmd
    end
    print("[HDR-TOGGLE] Executing: " .. actual_cmd)
    
    local args_table = split_by_space(actual_cmd)
    
    mp.command_native({
        name = "subprocess",
        playback_only = false,
        args = args_table
    })
end

local function check_hdr(name, value)
    local v_out = mp.get_property_native("video-out-params")
    local v_params = mp.get_property_native("video-params")
    
    local primaries = ""
    local gamma = ""

    if v_out then
        primaries = v_out["primaries"] or ""
        gamma = v_out["gamma"] or ""
    end

    if primaries == "" and v_params then
        primaries = v_params["primaries"] or ""
    end
    if gamma == "" and v_params then
        gamma = v_params["gamma"] or ""
    end

    local is_stopped = false
    local is_hdr = false
    if primaries == "bt.2020" or gamma == "pq" or gamma == "hlg" then
        is_hdr = true
    end
    
    if is_hdr and not current_file_is_hdr then
        print("[HDR-TOGGLE] >>> HDR video detected! Enabling System HDR... <<<")
        execute_command("%1")
        hdr_was_enabled = true
        current_file_is_hdr = true
    elseif not is_hdr and current_file_is_hdr then
        print("[HDR-TOGGLE] >>> SDR video detected. Disabling System HDR... <<<")
        execute_command("%2")
        current_file_is_hdr = false
    end
end


mp.register_script_message("stop-hdr-check", function()
    print("[HDR-TOGGLE] >>> STOP REQUEST RECEIVED. DISABLING AND CLEANING UP. <<<")
    is_stopped = true
    mp.unobserve_property(check_hdr)
    if hdr_was_enabled then
        execute_command("%2")
        hdr_was_enabled = false
    end
end)

mp.observe_property("video-params", "native", check_hdr)
mp.observe_property("video-out-params", "native", check_hdr)

mp.register_event("shutdown", function()
    if hdr_was_enabled then
        print("[HDR-TOGGLE] >>> Disabling System HDR on exit... <<<")
        execute_command("%2")
    end
end)
)";
    
    luaContent = luaContent.arg(enableCmd, disableCmd);
    
    QFile file(scriptPath);
    if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream out(&file);
        out << luaContent;
        file.close();
        qDebug() << "[DeployHdrScript] Successfully wrote script to:" << scriptPath;
    } else {
        qDebug() << "[DeployHdrScript] Failed to write script to:" << scriptPath;
    }
}
