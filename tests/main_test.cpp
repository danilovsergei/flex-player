#include <QtQuickTest/quicktest.h>
#include <QGuiApplication>
#include <QQmlEngine>
#include <QQmlContext>
#include <QSurfaceFormat>
#include <clocale>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QQmlNetworkAccessManagerFactory>

#include "../src/PlexModel.h"
#include "../src/PlexAuth.h"
#include "../src/ScreenSaverInhibitor.h"
#include "../src/MpvItem.h"
#include "../src/PlexConnectionManager.h"


class MyNetworkAccessManagerFactory : public QQmlNetworkAccessManagerFactory
{
public:
    QNetworkAccessManager *create(QObject *parent) override
    {
        QNetworkAccessManager *nam = new QNetworkAccessManager(parent);
        QObject::connect(nam, &QNetworkAccessManager::sslErrors,
                         nam, [](QNetworkReply *reply, const QList<QSslError> &errors) {
            reply->ignoreSslErrors();
        });
        return nam;
    }
};

class Setup : public QObject
{
    Q_OBJECT

public:
    Setup() {}

public slots:
    void applicationAvailable()
    {
        QSurfaceFormat format;
        format.setVersion(4, 6);
        format.setProfile(QSurfaceFormat::CoreProfile);
        QSurfaceFormat::setDefaultFormat(format);
        std::setlocale(LC_NUMERIC, "C");
    }

    void qmlEngineAvailable(QQmlEngine *engine)
    {
        engine->setNetworkAccessManagerFactory(new MyNetworkAccessManagerFactory);

        qmlRegisterType<MpvObject>("flex.mpv", 1, 0, "MpvObject");
        qmlRegisterType<PlexConnectionManager>("flex.plex", 1, 0, "PlexConnectionManager");
        qmlRegisterType<PlexModel>("flex.plex", 1, 0, "PlexModel");
        qmlRegisterType<PlexAuth>("flex.plex", 1, 0, "PlexAuth");
        qmlRegisterType<ScreenSaverInhibitor>("flex.plex", 1, 0, "ScreenSaverInhibitor");
    }
};

QUICK_TEST_MAIN_WITH_SETUP(FlexPlayerTest, Setup)

#include "main_test.moc"
