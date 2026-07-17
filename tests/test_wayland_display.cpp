#include <QGuiApplication>
#include <QWindow>
#include <QNativeInterface/QWaylandApplication>
#include <iostream>

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    auto *waylandApp = app.nativeInterface<QNativeInterface::QWaylandApplication>();
    if (waylandApp) {
        std::cout << "display: " << waylandApp->display() << std::endl;
    } else {
        std::cout << "Not wayland" << std::endl;
    }
    return 0;
}
