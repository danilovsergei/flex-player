#include <QGuiApplication>
#include <QtGui/qpa/qplatformnativeinterface.h>
#include <iostream>
#include <va/va.h>
#include <va/va_wayland.h>

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    QPlatformNativeInterface *native = QGuiApplication::platformNativeInterface();
    wl_display *display = (wl_display *) (native ? native->nativeResourceForIntegration("display") : nullptr);
    if (!display) {
        std::cout << "No wl_display" << std::endl;
        return 1;
    }
    VADisplay dpy = vaGetDisplayWl(display);
    if (!dpy) {
        std::cout << "vaGetDisplayWl failed" << std::endl;
        return 1;
    }
    int major, minor;
    VAStatus status = vaInitialize(dpy, &major, &minor);
    std::cout << "vaInitialize status: " << status << " (VA_STATUS_SUCCESS is 0)" << std::endl;
    return 0;
}
