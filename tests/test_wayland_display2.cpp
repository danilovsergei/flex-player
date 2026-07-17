#include <QGuiApplication>
#include <QtGui/qpa/qplatformnativeinterface.h>
#include <iostream>

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    QPlatformNativeInterface *native = QGuiApplication::platformNativeInterface();
    void *display1 = native ? native->nativeResourceForIntegration("display") : nullptr;
    std::cout << "display1: " << display1 << std::endl;
    return 0;
}
