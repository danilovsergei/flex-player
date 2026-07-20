#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QSurfaceFormat>
#include "PlexModel.h"
#include "PlexAuth.h"
#include "ScreenSaverInhibitor.h"
#include "MpvItem.h"

int main(int argc, char *argv[])
{
    // The Holy Grail: Set the OpenGL Core Profile so MPV can use zero-copy VAAPI on Wayland!
    QSurfaceFormat format;
    format.setVersion(4, 6);
    format.setProfile(QSurfaceFormat::CoreProfile);
    QSurfaceFormat::setDefaultFormat(format);

    QGuiApplication app(argc, argv);
    app.setDesktopFileName("io.github.danilovsergei.flex-player");
    app.setWindowIcon(QIcon(":/qt/qml/flex_player/assets/flex_icon.svg"));

    // libmpv requires LC_NUMERIC to be "C". 
    // Must be called AFTER QGuiApplication, as Qt resets it.
    std::setlocale(LC_NUMERIC, "C");
    
    // Register our custom MPV QML Type
    qmlRegisterType<MpvObject>("flex.mpv", 1, 0, "MpvObject");
    qmlRegisterType<PlexModel>("flex.plex", 1, 0, "PlexModel");
    qmlRegisterType<PlexAuth>("flex.plex", 1, 0, "PlexAuth");
    qmlRegisterType<ScreenSaverInhibitor>("flex.plex", 1, 0, "ScreenSaverInhibitor");

    QQmlApplicationEngine engine;

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
        
    engine.loadFromModule("flex_player", "Main");

    return app.exec();
}

