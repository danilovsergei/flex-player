#pragma once

#include <QObject>
#include <QtQml/qqml.h>

class ScreenSaverInhibitor : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool active READ isActive WRITE setActive NOTIFY activeChanged)

public:
    explicit ScreenSaverInhibitor(QObject *parent = nullptr);
    ~ScreenSaverInhibitor();

    bool isActive() const;
    void setActive(bool active);

signals:
    void activeChanged();

private:
    bool m_active = false;
    unsigned int m_cookie = 0;
    
    void setInhibitionOn();
    void setInhibitionOff();
};

