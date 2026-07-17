#ifndef MPVITEM_H_
#define MPVITEM_H_

#include <MpvAbstractItem>
#include <QtQuick/QQuickItem>
#include <QtQuick/QQuickFramebufferObject>
#include <QDir>
#include <QStandardPaths>

class MpvObject : public MpvAbstractItem
{
    Q_OBJECT
    QML_ELEMENT
    
    Q_PROPERTY(double duration READ duration NOTIFY durationChanged)
    Q_PROPERTY(double position READ position WRITE setPosition NOTIFY positionChanged)
    Q_PROPERTY(bool paused READ paused WRITE setPaused NOTIFY pausedChanged)

public:
    explicit MpvObject(QQuickItem *parent = nullptr) : MpvAbstractItem(parent)
    {
        // Internal configuration
        setProperty("terminal", "yes");
        setProperty("msg-level", "all=v");
        setProperty("vo", "libmpv");
        
        // Wayland HDR metadata
        setProperty("target-colorspace-hint", "yes");
        
        // Hardware decoding
        setProperty("hwdec", "auto-safe");

        QString configDir = QDir::homePath() + "/.config/flex-player/mpv";
        QDir().mkpath(configDir);
        setProperty("config", "yes");
        setProperty("config-dir", configDir);

        connect(this, &MpvAbstractItem::ready, this, [this, configDir]() {
            QDir scriptsDir(configDir + "/scripts");
            if (scriptsDir.exists()) {
                QStringList scripts = scriptsDir.entryList(QStringList() << "*.lua" << "*.js", QDir::Files);
                for (const QString &script : scripts) {
                    QString scriptPath = scriptsDir.absoluteFilePath(script);
                    MpvAbstractItem::commandBlocking(QStringList() << "load-script" << scriptPath);
                }
            }
        });

        observeProperty("duration", MPV_FORMAT_DOUBLE);
        observeProperty("time-pos", MPV_FORMAT_DOUBLE);
        observeProperty("pause", MPV_FORMAT_FLAG);
        
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
            }
        });
    }

    ~MpvObject() = default;

    double duration() const { return m_duration; }
    double position() const { return m_position; }
    void setPosition(double value) { setProperty("time-pos", value); }

    bool paused() const { return m_paused; }
    void setPaused(bool value) { setProperty("pause", value); }

    Q_INVOKABLE void command(const QVariantList &params)
    {
        QStringList strParams;
        for (const auto &p : params) {
            strParams << p.toString();
        }
        MpvAbstractItem::commandBlocking(strParams);
    }

    Q_INVOKABLE void setProperty(const QString& name, const QVariant& value)
    {
        MpvAbstractItem::setProperty(name, value);
    }

signals:
    void durationChanged();
    void positionChanged();
    void pausedChanged();

private:
    double m_duration = 0.0;
    double m_position = 0.0;
    bool m_paused = false;
};

#endif
