#ifndef MPVITEM_H_
#define MPVITEM_H_

#include <MpvAbstractItem>
#include <MpvController>
#include <QtQuick/QQuickItem>
#include <QtQuick/QQuickFramebufferObject>
#include <QDir>
#include <QStandardPaths>
#include <QDebug>

class MpvObject : public MpvAbstractItem
{
    Q_OBJECT
    QML_ELEMENT
    
    Q_PROPERTY(double duration READ duration NOTIFY durationChanged)
    Q_PROPERTY(double position READ position WRITE setPosition NOTIFY positionChanged)
    Q_PROPERTY(bool paused READ paused WRITE setPaused NOTIFY pausedChanged)
    Q_PROPERTY(QString aid READ aid WRITE setAid NOTIFY aidChanged)
    Q_PROPERTY(QString sid READ sid WRITE setSid NOTIFY sidChanged)
    Q_PROPERTY(double volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(bool videoIsHdr READ videoIsHdr WRITE setVideoIsHdr NOTIFY videoIsHdrChanged)
    Q_PROPERTY(bool buffering READ buffering WRITE setBuffering NOTIFY bufferingChanged)

public:
    explicit MpvObject(QQuickItem *parent = nullptr) : MpvAbstractItem(parent)
    {
        setProperty("terminal", "yes");
        setProperty("msg-level", "all=v");
        setProperty("vo", "libmpv");
        setProperty("target-colorspace-hint", "yes");
        setProperty("hwdec", "auto-safe");

        QString configDir = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation) + "/flex-player/mpv";
        QDir().mkpath(configDir);
        setProperty("config", "yes");
        setProperty("config-dir", configDir);

        observeProperty("duration", MPV_FORMAT_DOUBLE);
        observeProperty("time-pos", MPV_FORMAT_DOUBLE);
        observeProperty("pause", MPV_FORMAT_FLAG);
        observeProperty("aid", MPV_FORMAT_STRING);
        observeProperty("sid", MPV_FORMAT_STRING);
        observeProperty("volume", MPV_FORMAT_DOUBLE);
        observeProperty("video-out-params", MPV_FORMAT_NODE);
        observeProperty("core-idle", MPV_FORMAT_FLAG);
        
        connect(mpvController(), &MpvController::propertyChanged, this, [this](const QString &prop, const QVariant &val) {
            if (prop == "duration") {
                m_duration = val.toDouble();
                emit durationChanged();
            } else if (prop == "time-pos") {
                m_position = val.toDouble();
                emit positionChanged();
            } else if (prop == "pause") {
                m_paused = val.toBool();
                emit pausedChanged();
                updateBuffering();
            } else if (prop == "aid") {
                m_aid = val.toString();
                emit aidChanged();
            } else if (prop == "sid") {
                m_sid = val.toString();
                emit sidChanged();
            } else if (prop == "volume") {
                m_volume = val.toDouble();
                emit volumeChanged();
            } else if (prop == "video-out-params") {
                checkHdr(val.toMap());
            } else if (prop == "core-idle") {
                m_coreIdle = val.toBool();
                updateBuffering();
            }
        });
    }

    ~MpvObject() = default;

    double duration() const { return m_duration; }
    double position() const { return m_position; }
    void setPosition(double value) { setProperty("time-pos", value); }

    bool paused() const { return m_paused; }
    void setPaused(bool value) { setProperty("pause", value); }

    QString aid() const { return m_aid; }
    void setAid(const QString& value) { setProperty("aid", value); }

    QString sid() const { return m_sid; }
    void setSid(const QString& value) { setProperty("sid", value); }

    bool videoIsHdr() const { return m_videoIsHdr; }
    void setVideoIsHdr(bool value) {
        if (m_videoIsHdr == value) return;
        m_videoIsHdr = value;
        emit videoIsHdrChanged();
    }

    bool buffering() const { return m_buffering; }
    void setBuffering(bool value) {
        if (m_buffering == value) return;
        m_buffering = value;
        emit bufferingChanged();
    }

    Q_INVOKABLE void loadScripts() {}
    Q_INVOKABLE void stopHdr() {}

    double volume() const { return m_volume; }
    void setVolume(double value) { if(m_volume == value) return; m_volume = value; emit volumeChanged(); setProperty("volume", value); }

    Q_INVOKABLE void command(const QVariantList &params)
    {
        QStringList strParams;
        for (const auto &p : params) {
            strParams << p.toString();
        }
        mpvController()->command(strParams);
    }

    Q_INVOKABLE void setProperty(const QString& name, const QVariant& value)
    {
        MpvAbstractItem::setProperty(name, value);
    }

signals:
    void durationChanged();
    void positionChanged();
    void pausedChanged();
    void aidChanged();
    void sidChanged();
    void volumeChanged();
    void videoIsHdrChanged();
    void bufferingChanged();

private:
    void updateBuffering() {
        bool isBuffering = m_coreIdle && !m_paused;
        setBuffering(isBuffering);
    }

    void checkHdr(const QVariantMap &params) {
        QString primaries = params.value("primaries").toString();
        QString gamma = params.value("gamma").toString();
        bool isHdr = (primaries == "bt.2020" || gamma == "pq" || gamma == "hlg");
        setVideoIsHdr(isHdr);
    }

    double m_duration = 0.0;
    double m_position = 0.0;
    bool m_paused = false;
    QString m_aid = "auto";
    QString m_sid = "no";
    double m_volume = 100.0;
    bool m_videoIsHdr = false;
    bool m_coreIdle = false;
    bool m_buffering = false;
};

#endif

