#include <iostream>
#include <va/va.h>
#include <va/va_wayland.h>
#include <wayland-client.h>

int main(int argc, char *argv[]) {
    wl_display *display = wl_display_connect(NULL);
    if (!display) {
        std::cout << "wl_display_connect failed" << std::endl;
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
