#include "ScreenSaverInhibitor.h"
#include <QDBusInterface>
#include <QDBusReply>
#include <QDBusConnection>
#include <QDebug>

ScreenSaverInhibitor::ScreenSaverInhibitor(QObject *parent) : QObject(parent) {}

ScreenSaverInhibitor::~ScreenSaverInhibitor() {
    if (m_active) {
        setInhibitionOff();
    }
}

bool ScreenSaverInhibitor::isActive() const {
    return m_active;
}

void ScreenSaverInhibitor::setActive(bool active) {
    if (m_active == active) return;
    
    m_active = active;
    if (m_active) {
        setInhibitionOn();
    } else {
        setInhibitionOff();
    }
    emit activeChanged();
}

void ScreenSaverInhibitor::setInhibitionOn() {
    QDBusInterface iface("org.freedesktop.ScreenSaver", "/org/freedesktop/ScreenSaver", "org.freedesktop.ScreenSaver", QDBusConnection::sessionBus());
    if (iface.isValid()) {
        QDBusReply<uint> reply = iface.call("Inhibit", "Flex Player", "Playing media file");
        if (reply.isValid()) {
            m_cookie = reply.value();
            qDebug() << "ScreenSaver inhibited, cookie:" << m_cookie;
        } else {
            qWarning() << "Failed to inhibit ScreenSaver:" << reply.error().message();
        }
    } else {
        qWarning() << "ScreenSaver DBus interface not available";
    }
}

void ScreenSaverInhibitor::setInhibitionOff() {
    if (m_cookie == 0) return;
    
    QDBusInterface iface("org.freedesktop.ScreenSaver", "/org/freedesktop/ScreenSaver", "org.freedesktop.ScreenSaver", QDBusConnection::sessionBus());
    if (iface.isValid()) {
        iface.call("UnInhibit", m_cookie);
        qDebug() << "ScreenSaver uninhibited, cookie:" << m_cookie;
    }
    m_cookie = 0;
}

